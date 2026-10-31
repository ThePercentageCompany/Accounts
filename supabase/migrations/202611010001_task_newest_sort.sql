-- Sort before pagination so the newest tasks are first across every page.
begin;
create or replace function public.task_list(p_company text,p_actor uuid,p_query jsonb,p_today date)
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
    case when p_query->>'sort'='newest' then coalesce((payload->>'createdAt')::numeric,0) end desc,
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
commit;
