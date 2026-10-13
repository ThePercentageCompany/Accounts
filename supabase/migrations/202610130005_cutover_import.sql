-- Operator-only atomic import. Existing workspaces cannot be overwritten.
create table private.cutover_imports (
  company_id text primary key references public.companies(id),
  source_digest text not null,
  record_count integer not null,
  imported_at timestamptz not null default now()
);
create or replace function public.import_workspace_snapshot(p_snapshot jsonb,p_owners jsonb,p_digest text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id text:=p_snapshot->'company'->>'id'; v_record jsonb; v_owner jsonb; v_existing text; v_count integer:=0;
begin
  if auth.role()<>'service_role' then raise exception 'SERVICE_ONLY'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_id,0));
  select source_digest into v_existing from private.cutover_imports where company_id=v_id;
  if found then
    if v_existing<>p_digest then raise exception 'IMPORT_SOURCE_CHANGED'; end if;
    return jsonb_build_object('replayed',true);
  end if;
  if exists(select 1 from public.companies where id=v_id) then raise exception 'IMPORT_WORKSPACE_EXISTS'; end if;
  if jsonb_array_length(p_owners)=0 or length(p_digest)<>64 then raise exception 'INVALID_IMPORT'; end if;
  insert into public.companies(id,name,created_by,created_at,configuration)
    values(v_id,p_snapshot->'company'->>'name',(p_owners->0->>'userId')::uuid,
      to_timestamp((p_snapshot->'company'->>'createdAt')::double precision/1000),coalesce(p_snapshot->'configuration','{}'));
  for v_owner in select value from jsonb_array_elements(p_owners) loop
    if not exists(select 1 from auth.users where id=(v_owner->>'userId')::uuid and lower(email)=lower(v_owner->>'email')) then raise exception 'IMPORT_OWNER_MISMATCH'; end if;
    insert into public.company_memberships(company_id,user_id,role) values(v_id,(v_owner->>'userId')::uuid,'ADMIN');
  end loop;
  for v_record in select value from jsonb_array_elements(p_snapshot->'records') loop
    if v_record->'payload'->>'companyId'<>v_id then raise exception 'IMPORT_TENANT_MISMATCH'; end if;
    insert into public.business_records(company_id,section,record_id,ordinal,version,payload,deleted)
      values(v_id,v_record->>'section',v_record->'payload'->>'recordId',(v_record->>'ordinal')::bigint,
        (v_record->'payload'->>'recordVersion')::bigint,v_record->'payload',lower(v_record->'payload'->>'isDeleted')='true');
    v_count:=v_count+1;
  end loop;
  insert into private.cutover_imports(company_id,source_digest,record_count) values(v_id,p_digest,v_count);
  return jsonb_build_object('replayed',false,'recordCount',v_count);
end $$;
revoke all on function public.import_workspace_snapshot(jsonb,jsonb,text) from public,anon,authenticated;
grant execute on function public.import_workspace_snapshot(jsonb,jsonb,text) to service_role;
