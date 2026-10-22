-- Transactional per-workspace cursor. Unlike a sequence/updated_at watermark,
-- this row lock prevents a later committed cursor overtaking an earlier write.
create table private.record_sync_heads (
  company_id text primary key references public.companies(id) on delete cascade,
  cursor bigint not null default 0,
  floor_cursor bigint not null default 0
);
create table private.record_changes (
  company_id text not null references public.companies(id) on delete cascade,
  cursor bigint not null,
  section text not null,
  record_id text not null,
  old_payload jsonb,
  new_payload jsonb,
  created_at timestamptz not null default clock_timestamp(),
  primary key(company_id,cursor)
);
create index record_changes_retention on private.record_changes(created_at);

create function private.capture_record_change() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_company text; v_cursor bigint;
begin
  v_company:=coalesce(new.company_id,old.company_id);
  -- Use the same lock order as commit_workspace, including non-business writes.
  perform 1 from public.companies where id=v_company for update;
  if not found then return coalesce(new,old); end if;
  insert into private.record_sync_heads(company_id) values(v_company) on conflict do nothing;
  update private.record_sync_heads set cursor=cursor+1 where company_id=v_company returning cursor into v_cursor;
  insert into private.record_changes(company_id,cursor,section,record_id,old_payload,new_payload)
    values(v_company,v_cursor,coalesce(new.section,old.section),coalesce(new.record_id,old.record_id),old.payload,new.payload);
  return coalesce(new,old);
end $$;
create trigger record_delta_change after insert or update or delete on public.business_records
  for each row execute function private.capture_record_change();

create function public.record_sync_head(p_company text,p_actor uuid) returns text
language plpgsql security definer set search_path='' as $$
begin
  if not private.is_member(p_company,p_actor) then raise exception 'WORKSPACE_CHANGED'; end if;
  return coalesce((select cursor::text from private.record_sync_heads where company_id=p_company),'0');
end $$;

create function public.record_delta_page(p_company text,p_actor uuid,p_after bigint,
  p_through bigint default null,p_limit integer default 500,p_sections text[] default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_head bigint; v_floor bigint; v_end bigint; v_rows jsonb; v_next bigint;
begin
  if not private.is_member(p_company,p_actor) then raise exception 'WORKSPACE_CHANGED'; end if;
  if p_after<0 or p_limit<1 or p_limit>500 then raise exception 'INVALID_PAGE'; end if;
  select cursor,floor_cursor into v_head,v_floor from private.record_sync_heads where company_id=p_company;
  v_head:=coalesce(v_head,0);v_floor:=coalesce(v_floor,0);v_end:=coalesce(p_through,v_head);
  if p_after<v_floor or p_after>v_head or v_end>v_head or v_end<p_after then
    return jsonb_build_object('reset',true,'head',v_head::text);
  end if;
  select coalesce(jsonb_agg(to_jsonb(r) order by r.cursor::bigint),'[]'::jsonb),max(r.cursor::bigint)
    into v_rows,v_next from (
      select cursor::text,section,record_id,old_payload,new_payload from private.record_changes
      where company_id=p_company and cursor>p_after and cursor<=v_end
        and (p_sections is null or section=any(p_sections)) order by cursor limit p_limit
    ) r;
  v_next:=coalesce(v_next,v_end);
  if jsonb_array_length(v_rows)<p_limit then v_next:=v_end; end if;
  return jsonb_build_object('reset',false,'head',v_end::text,'cursor',v_next::text,
    'hasMore',v_next<v_end,'changes',v_rows);
end $$;

-- Expired cursors explicitly bootstrap again; no client silently skips history.
create function private.prune_record_changes() returns void
language plpgsql security definer set search_path='' as $$
declare v_head record; v_floor bigint;
begin
  for v_head in select company_id from private.record_sync_heads order by company_id loop
    perform 1 from public.companies where id=v_head.company_id for update;
    perform 1 from private.record_sync_heads where company_id=v_head.company_id for update;
    select max(cursor) into v_floor from private.record_changes
      where company_id=v_head.company_id and created_at<clock_timestamp()-interval '7 days';
    if v_floor is not null then
      update private.record_sync_heads set floor_cursor=greatest(floor_cursor,v_floor) where company_id=v_head.company_id;
      delete from private.record_changes where company_id=v_head.company_id and cursor<=v_floor;
    end if;
  end loop;
end $$;
revoke all on private.record_sync_heads,private.record_changes from public,anon,authenticated;
revoke all on function private.capture_record_change(),private.prune_record_changes() from public,anon,authenticated;
revoke all on function public.record_sync_head(text,uuid),public.record_delta_page(text,uuid,bigint,bigint,integer,text[]) from public,anon,authenticated;
grant execute on function public.record_sync_head(text,uuid),public.record_delta_page(text,uuid,bigint,bigint,integer,text[]) to service_role;
select cron.schedule('record-delta-retention','17 3 * * *','select private.prune_record_changes()');
