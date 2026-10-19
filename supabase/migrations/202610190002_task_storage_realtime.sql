-- Task reads and concurrency versions live in business tables. Compatibility
-- records remain in the same transaction for documents, sync and notifications.
begin;
alter table business.tasks add column payload jsonb;
alter table business.task_comments add column payload jsonb;
alter table business.task_activity add column payload jsonb;
update business.tasks t set payload=r.payload from public.business_records r
 where r.company_id=t.company_id and r.section='Tasks' and r.record_id=t.record_id;
update business.task_comments t set payload=r.payload from public.business_records r
 where r.company_id=t.company_id and r.section='TaskComments' and r.record_id=t.record_id;
update business.task_activity t set payload=r.payload from public.business_records r
 where r.company_id=t.company_id and r.section='TaskActivity' and r.record_id=t.record_id;
alter table business.tasks alter column payload set not null;
alter table business.task_comments alter column payload set not null;
alter table business.task_activity alter column payload set not null;

create function private.task_payload() returns trigger language plpgsql security definer set search_path='' as $$
begin
 select r.payload into new.payload from public.business_records r
 where r.company_id=new.company_id and r.section=new.source_section and r.record_id=new.record_id;
 if new.payload is null then raise exception 'TASK_COMPATIBILITY_RECORD_MISSING'; end if;
 return new;
end $$;
create trigger task_payload before insert or update on business.tasks for each row execute function private.task_payload();
create trigger task_payload before insert or update on business.task_comments for each row execute function private.task_payload();
create trigger task_payload before insert or update on business.task_activity for each row execute function private.task_payload();

create index tasks_due_page on business.tasks(company_id,due_date,end_time,record_id) where not deleted;
create index tasks_assigned_due_page on business.tasks(company_id,employee_id,due_date,end_time,record_id) where not deleted;
create index tasks_updated_page on business.tasks(company_id,updated_at desc,record_id) where not deleted;

-- Only service_role can call these: the API supplies its authenticated actor.
create function private.task_access(p_company text,p_actor uuid)
returns table(employee_id text,all_tasks boolean) language sql stable security definer set search_path='' as $$
 select m.employee_id,m.role='ADMIN' or (g.can_write and g.scope='COMPANY' and m.role<>'Staff')
 from public.company_memberships m join public.companies c on c.id=m.company_id and c.deleted_at is null
 left join public.section_permissions g on g.company_id=m.company_id and g.user_id=m.user_id and g.section='Tasks'
 where m.company_id=p_company and m.user_id=p_actor and m.status='ACTIVE' and (m.role='ADMIN' or g.section is not null)
$$;

create function public.task_records_page(p_company text,p_section text,p_after bigint default 0,p_limit integer default 1000,
 p_actor uuid default null,p_task text default null)
returns table(ordinal bigint,payload jsonb) language plpgsql stable security definer set search_path='' as $$
begin
 if p_limit not between 1 and 1000 or p_after<0 then raise exception 'INVALID_QUERY'; end if;
 if p_section='Tasks' then
  return query select t.ordinal,t.payload from business.tasks t
   where t.company_id=p_company and t.ordinal>p_after and (p_task is null or t.record_id=p_task)
    and (p_actor is null or exists(select 1 from private.task_access(p_company,p_actor) a where not t.deleted and (a.all_tasks or a.employee_id=t.employee_id)))
   order by t.ordinal limit p_limit;
 elsif p_section in ('TaskComments','TaskActivity') then
  return query select r.ordinal,r.payload from (
   select t.ordinal,t.payload,t.deleted,t.task_id from business.task_comments t where p_section='TaskComments' and t.company_id=p_company and t.ordinal>p_after and (p_task is null or t.task_id=p_task)
   union all
   select t.ordinal,t.payload,t.deleted,t.task_id from business.task_activity t where p_section='TaskActivity' and t.company_id=p_company and t.ordinal>p_after and (p_task is null or t.task_id=p_task)
  ) r where p_actor is null or (not r.deleted and exists(select 1 from business.tasks t cross join private.task_access(p_company,p_actor) a
   where t.company_id=p_company and t.record_id=r.task_id and not t.deleted and (a.all_tasks or a.employee_id=t.employee_id)))
   order by r.ordinal limit p_limit;
 else raise exception 'TABLE_FORBIDDEN'; end if;
end $$;
revoke all on function public.task_records_page(text,text,bigint,integer,uuid,text) from public,anon,authenticated;
grant execute on function public.task_records_page(text,text,bigint,integer,uuid,text) to service_role;

create function public.task_list(p_company text,p_actor uuid,p_query jsonb,p_today date)
returns jsonb language sql stable security definer set search_path='' as $$
 with accessible as not materialized (
  select t.* from business.tasks t cross join private.task_access(p_company,p_actor) a
  where t.company_id=p_company and not t.deleted and (a.all_tasks or a.employee_id=t.employee_id)
 ), filtered as not materialized (
  select * from accessible t where
   (coalesce(p_query->>'overdue','')<>'true' or t.status<>'COMPLETED')
   and (coalesce(p_query->>'search','')='' or strpos(lower(coalesce(t.title,'')||' '||coalesce(t.description,'')||' '||coalesce(t.project,'')||' '||coalesce(t.tags,'')),lower(p_query->>'search'))>0)
   and (coalesce(p_query->>'employeeId','')='' or t.employee_id=p_query->>'employeeId')
   and (coalesce(p_query->>'status','')='' or t.status=p_query->>'status')
   and (coalesce(p_query->>'priority','')='' or t.priority=p_query->>'priority')
   and (coalesce(p_query->>'project','')='' or t.project=p_query->>'project')
   and (coalesce(p_query->>'from','')='' or t.due_date>=nullif(p_query->>'from','')::date)
   and (coalesce(p_query->>'to','')='' or t.due_date<=nullif(p_query->>'to','')::date)
 ), page as (
  select payload-'idempotencyKey' as payload,row_number() over () as position from (
   select * from filtered order by
    case when p_query->>'sort'='priority' then array_position(array['LOW','MEDIUM','HIGH','URGENT'],priority) end desc,
    case when p_query->>'sort'='updated' then (payload->>'updatedAt')::numeric end desc,
    case when coalesce(p_query->>'sort','due')='due' then coalesce(due_date::text,'')||coalesce(end_time,'') end,
    record_id limit least(100,greatest(1,coalesce((p_query->>'limit')::integer,40))) offset greatest(0,coalesce((p_query->>'offset')::integer,0))
  ) ordered
 ), totals as (select count(*) n from filtered)
 select jsonb_build_object('records',coalesce((select jsonb_agg(payload order by position) from page),'[]'::jsonb),
  'total',totals.n,'nextOffset',case when coalesce((p_query->>'offset')::integer,0)+coalesce((p_query->>'limit')::integer,40)<totals.n then coalesce((p_query->>'offset')::integer,0)+coalesce((p_query->>'limit')::integer,40) else null end,
  'dateCounts',coalesce((select jsonb_object_agg(due_date,n) from (select due_date,count(*) n from filtered where due_date is not null group by due_date) d),'{}'::jsonb),
  'reminders','[]'::jsonb,'summary',jsonb_build_object(
   'todo',(select count(*) from accessible where status='TODO'),
   'inProgress',(select count(*) from accessible where status='IN_PROGRESS'),
   'today',(select count(*) from accessible where due_date=p_today and status<>'COMPLETED'),
   'overdue',(select count(*) from accessible where due_date<p_today and status<>'COMPLETED'),
   'upcoming',coalesce((select jsonb_agg(jsonb_build_object('date',due_date,'count',n) order by due_date) from
    (select due_date,count(*) n from accessible where due_date>p_today and status<>'COMPLETED' group by due_date order by due_date limit 7) d),'[]'::jsonb))) from totals
$$;
revoke all on function public.task_list(text,uuid,jsonb,date) from public,anon,authenticated;
grant execute on function public.task_list(text,uuid,jsonb,date) to service_role;

create function private.task_broadcast() returns trigger language plpgsql security definer set search_path='' as $$
declare v_company text; v_task text; v_old_employee text; v_employee text; v_user uuid; v_version bigint;
begin
 v_company:=coalesce(new.company_id,old.company_id);
 if tg_table_name='tasks' then
  v_task:=coalesce(new.record_id,old.record_id); v_employee:=new.employee_id; v_old_employee:=old.employee_id;
 else
  v_task:=coalesce(new.task_id,old.task_id);
  select employee_id into v_employee from business.tasks where company_id=v_company and record_id=v_task;
 end if;
 v_version:=coalesce(new.version,old.version);
 for v_user in select m.user_id from public.company_memberships m cross join lateral private.task_access(v_company,m.user_id) a
  where m.company_id=v_company and m.status='ACTIVE' and (a.all_tasks or a.employee_id in (v_employee,v_old_employee))
 loop
  perform realtime.send(jsonb_build_object('taskId',v_task,'version',v_version,'action',tg_op,'section',coalesce(new.source_section,old.source_section)),
   'task_changed','tasks:'||v_company||':'||v_user::text,true);
 end loop;
 return null;
end $$;
create trigger task_broadcast after insert or update or delete on business.tasks for each row execute function private.task_broadcast();
create trigger task_broadcast after insert or update or delete on business.task_comments for each row execute function private.task_broadcast();
create trigger task_broadcast after insert or update or delete on business.task_activity for each row execute function private.task_broadcast();
create policy task_broadcast_read on realtime.messages for select to authenticated using (
 extension='broadcast' and exists(select 1 from public.company_memberships m
  where m.user_id=(select auth.uid()) and m.status='ACTIVE' and realtime.topic()='tasks:'||m.company_id||':'||m.user_id::text
   and private.can_section(m.company_id,'Tasks')));
grant select on realtime.messages to authenticated;
revoke all on function private.task_payload(),private.task_broadcast(),private.task_access(text,uuid) from public,anon,authenticated;

-- Structured task versions govern writes; compatibility and typed rows commit atomically.
create or replace function public.commit_workspace(p_company text,p_actor uuid,p_revision bigint,
  p_changes jsonb,p_configuration jsonb,p_operations jsonb,p_audit jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_company public.companies; v_change jsonb; v_operation record; v_version bigint; v_section text; v_sections text[]:='{}';
begin
  select * into v_company from public.companies where id=p_company and deleted_at is null for update;
  if not found or not private.is_member(p_company,p_actor) then raise exception 'WORKSPACE_CHANGED'; end if;
  if v_company.revision<>p_revision then raise exception 'VERSION_CONFLICT'; end if;
  if jsonb_array_length(p_changes)>5000 then raise exception 'BATCH_TOO_LARGE'; end if;
  for v_change in select value from jsonb_array_elements(p_changes) loop
    v_section:=v_change->>'section';
    if (v_change->'payload'->>'companyId') is distinct from p_company or (v_change->'payload'->>'recordId') is distinct from (v_change->>'recordId') then raise exception 'RECORD_IDENTITY_MISMATCH'; end if;
    if v_section='Tasks' then
      select version into v_version from business.tasks where company_id=p_company and record_id=v_change->>'recordId';
    elsif v_section='TaskComments' then
      select version into v_version from business.task_comments where company_id=p_company and record_id=v_change->>'recordId';
    elsif v_section='TaskActivity' then
      select version into v_version from business.task_activity where company_id=p_company and record_id=v_change->>'recordId';
    else
      select version into v_version from public.business_records where company_id=p_company and section=v_section and record_id=v_change->>'recordId';
    end if;
    if coalesce(v_version,0) <> (v_change->>'expectedVersion')::bigint then raise exception 'VERSION_CONFLICT'; end if;
    if (v_change->>'version')::bigint<=coalesce(v_version,0) then raise exception 'INVALID_RECORD_VERSION'; end if;
    insert into public.business_records(company_id,section,record_id,ordinal,version,payload,deleted)
      values(p_company,v_section,v_change->>'recordId',(v_change->>'ordinal')::bigint,
        (v_change->>'version')::bigint,v_change->'payload',coalesce((v_change->'payload'->>'isDeleted')::boolean,false))
      on conflict(company_id,section,record_id) do update set version=excluded.version,payload=excluded.payload,
        deleted=excluded.deleted,updated_at=now();
    v_sections:=array_append(v_sections,v_section);
  end loop;
  for v_operation in select * from jsonb_each(p_operations) loop
    insert into private.operations values(p_company,v_operation.key,v_operation.value,now())
      on conflict(company_id,operation_key) do nothing;
  end loop;
  update public.companies set configuration=p_configuration,revision=revision+1,updated_at=now() where id=p_company;
  insert into private.audit_events(company_id,actor_id,changes) values(p_company,p_actor,p_audit);
  insert into public.company_changes(company_id,sections,revision)
    values(p_company,array(select distinct unnest(v_sections)),p_revision+1);
  return p_revision+1;
end $$;
revoke all on function public.commit_workspace(text,uuid,bigint,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.commit_workspace(text,uuid,bigint,jsonb,jsonb,jsonb,jsonb) to service_role;


commit;
