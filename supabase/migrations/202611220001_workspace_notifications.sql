-- Reuse the recipient-scoped notification inbox and push outbox for payroll.
alter table public.notifications alter column task_id drop not null;
alter table public.push_registrations add constraint push_registration_platform
  check (platform in ('web','android','ios'));
create index payroll_pending_notification on business.payroll(company_id,month)
  where not deleted and status='APPROVED';
create or replace function private.task_notice_visible(p_company text,p_user uuid,p_task text,p_type text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
   select 1 from public.company_memberships m
   join public.companies c on c.id=m.company_id and c.deleted_at is null
   where m.company_id=p_company and m.user_id=p_user and m.status='ACTIVE'
   and case
     when p_type='payroll-paid' then true
     when p_type='payroll-due' then m.role='Accountant' and exists(
       select 1 from public.section_permissions g
       where g.company_id=p_company and g.user_id=p_user and g.section='Payroll' and g.scope='COMPANY')
     else m.role='ADMIN' or exists(
       select 1 from private.task_access(p_company,p_user) a
       where p_type in ('task-unassigned','task-deleted') or exists(
         select 1 from business.tasks t where t.company_id=p_company and t.record_id=p_task
         and not t.deleted and (a.all_tasks or a.employee_id=t.employee_id)))
     or (p_type='task-assigned' and exists(
       select 1 from business.tasks t where t.company_id=p_company and t.record_id=p_task
       and not t.deleted and t.employee_id=m.employee_id))
   end)
$$;

create or replace function private.emit_task_notice(p_company text,p_task text,p_event text,p_type text,p_title text,p_body text,p_actor uuid,
 p_employee text,p_previous text default null,p_metadata jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare m record;v_type text;v_id text;v_body text;v_title text;
begin
 for m in select distinct x.user_id,x.employee_id,x.role from public.company_memberships x
 where x.company_id=p_company and x.status='ACTIVE' and (x.role='ADMIN' or x.employee_id=p_employee or x.employee_id=p_previous
   or (p_type='task-status' and exists(select 1 from private.task_access(p_company,x.user_id) a where a.all_tasks)))
 loop
  v_type:=case when m.role<>'ADMIN' and m.employee_id=p_previous and p_previous is distinct from p_employee then 'task-unassigned' else p_type end;
  if not private.task_notice_visible(p_company,m.user_id,p_task,v_type) then continue;end if;
  v_title:=case when v_type='task-unassigned' then 'Task unassigned' else p_title end;
  v_body:=case when v_type='task-unassigned' then 'A task has been removed from your assignments.'
    when v_type='task-deleted' and m.role<>'ADMIN' then 'An assigned task was deleted.' else p_body end;
  v_id:=translate(rtrim(encode(extensions.digest(p_company||p_event||m.user_id::text,'sha256'),'base64'),'='),'+/','-_');
  insert into public.notifications(id,company_id,employee_id,recipient_user_id,actor_user_id,task_id,event_id,type,title,body,metadata)
  values(v_id,p_company,coalesce(m.employee_id,''),m.user_id,p_actor,p_task,p_event,v_type,v_title,v_body,
    p_metadata||jsonb_build_object('canOpenTask',v_type not in ('task-unassigned','task-deleted')
      and exists(select 1 from private.task_access(p_company,m.user_id))))
  on conflict do nothing;
 end loop;
end $$;

create or replace function private.task_push_allowed(n public.notifications) returns boolean language sql stable security definer set search_path='' as $$
 select private.task_notice_visible(n.company_id,n.recipient_user_id,n.task_id,n.type)
 and coalesce(p.push_enabled,true)
 and case when n.type='payroll-due' then exists(
   select 1 from business.payroll r where r.company_id=n.company_id
   and r.month=n.metadata->>'month' and not r.deleted and r.status='APPROVED')
   when n.type='payroll-paid' then true
   when n.type='task-overdue' then coalesce(p.overdue_enabled,true)
   when n.type in ('task-due','task-deadline') then coalesce(p.deadline_enabled,true)
   when n.type in ('task-assigned','task-unassigned') then coalesce(p.assignment_enabled,true)
   else coalesce(p.updates_enabled,true) end
 and (not(n.metadata ? 'deadlineAt') or exists(select 1 from business.tasks t where t.company_id=n.company_id and t.record_id=n.task_id
   and not t.deleted and t.status not in ('COMPLETED','CANCELLED','ARCHIVED') and coalesce(t.reminder,'1_DAY')<>'NONE'
   and private.task_deadline(n.company_id,n.task_id)=(n.metadata->>'deadlineAt')::timestamptz
   and (n.type='task-overdue' or now()<private.task_deadline(n.company_id,n.task_id)+interval '5 minutes')))
 and n.created_at>now()-interval '24 hours'
 from (select 1) z left join public.notification_preferences p on p.company_id=n.company_id and p.user_id=n.recipient_user_id
$$;

create or replace function public.claim_notification_push(p_limit integer default 50) returns jsonb language plpgsql security definer set search_path='' as $$
declare j record;v_result jsonb:='[]';v_lease uuid;v_quiet timestamptz;v_now timestamp;
begin
 if p_limit not between 1 and 100 then raise exception 'INVALID_LIMIT';end if;
 for j in select q.*,n as notice,r.token,r.platform,r.active,c.time_zone,s.sound,s.volume,p.quiet_start,p.quiet_end
 from private.notification_push_jobs q join public.notifications n on n.id=q.notification_id
 join public.push_registrations r on r.id=q.registration_id join public.companies c on c.id=n.company_id
 left join public.company_notification_settings s on s.company_id=n.company_id
 left join public.notification_preferences p on p.company_id=n.company_id and p.user_id=n.recipient_user_id
 where ((q.status='PENDING' and q.available_at<=now()) or (q.status='SENDING' and q.lease_until<now())) and q.attempts<8
 order by q.available_at,q.id limit p_limit for update of q skip locked
 loop
  if not j.active or not private.task_push_allowed(j.notice) then
   update private.notification_push_jobs set status='CANCELLED' where id=j.id;continue;end if;
  v_now:=now() at time zone j.time_zone;v_quiet:=null;
  if j.quiet_start is not null and j.quiet_start<>j.quiet_end and
   ((j.quiet_start<j.quiet_end and v_now::time>=j.quiet_start and v_now::time<j.quiet_end)
    or (j.quiet_start>j.quiet_end and (v_now::time>=j.quiet_start or v_now::time<j.quiet_end))) then
   v_quiet:=((v_now::date+case when j.quiet_start>j.quiet_end and v_now::time>=j.quiet_start then 1 else 0 end)+j.quiet_end) at time zone j.time_zone;
   update private.notification_push_jobs set status='PENDING',available_at=v_quiet where id=j.id;continue;end if;
  v_lease:=gen_random_uuid();
  update private.notification_push_jobs set status='SENDING',lease_id=v_lease,lease_until=now()+interval '2 minutes',attempts=attempts+1 where id=j.id;
  v_result:=v_result||jsonb_build_array(jsonb_build_object('id',j.id,'lease',v_lease,'token',j.token,'notificationId',(j.notice).id,
   'companyId',(j.notice).company_id,'taskId',(j.notice).task_id,'platform',j.platform,
   'canOpenTask',coalesce(((j.notice).metadata->>'canOpenTask')::boolean,true),'eventId',(j.notice).event_id,'type',(j.notice).type,
   'sound',coalesce(j.sound,'chime'),'volume',coalesce(j.volume,0.65),'attempts',j.attempts+1));
 end loop;
 return v_result;
end $$;

create or replace function public.task_notification_api(p_company text,p_actor uuid,p_action text,p_input jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.company_memberships;result jsonb;v_notifications jsonb;v_unread bigint;v_cursor timestamptz;v_cursor_id text;v_filter text;v_id text;v_version bigint;v_limit integer;
begin
 select * into m from public.company_memberships where company_id=p_company and user_id=p_actor and status='ACTIVE';
 if not found or not exists(select 1 from public.companies where id=p_company and deleted_at is null) then raise exception 'NOTIFICATION_FORBIDDEN';end if;
 if p_action='list' then
  v_limit:=least(100,greatest(1,coalesce((p_input->>'limit')::integer,40)));v_filter:=coalesce(p_input->>'filter','all');
  if nullif(p_input->>'cursor','') is not null then
   v_cursor:=split_part(p_input->>'cursor','|',1)::timestamptz;v_cursor_id:=split_part(p_input->>'cursor','|',2);end if;
  select count(*) into v_unread from public.notifications n where n.company_id=p_company and n.recipient_user_id=p_actor
    and n.read_at is null and private.task_notice_visible(p_company,p_actor,n.task_id,n.type);
  select coalesce(jsonb_agg(page.item order by page.created_at desc,page.id desc),'[]') into v_notifications from (
   select n.id,n.created_at,jsonb_build_object('id',n.id,'companyId',n.company_id,'taskId',n.task_id,'eventId',n.event_id,
    'type',n.type,'title',n.title,'body',n.body,'metadata',n.metadata,'actorId',n.actor_user_id,'isOwnEvent',n.actor_user_id=p_actor,
    'createdAt',extract(epoch from n.created_at)*1000,'readAt',extract(epoch from n.read_at)*1000,
    'cursor',n.created_at::text||'|'||n.id) item
   from public.notifications n where n.company_id=p_company and n.recipient_user_id=p_actor
   and private.task_notice_visible(p_company,p_actor,n.task_id,n.type)
   and (v_cursor is null or (n.created_at,n.id)<(v_cursor,v_cursor_id))
   and (v_filter not in ('unread','task','payroll','deadline','overdue') or v_filter='unread' and n.read_at is null
     or v_filter='task' and n.type like 'task-%' or v_filter='payroll' and n.type like 'payroll-%'
     or v_filter='deadline' and n.type in ('task-due','task-deadline') or v_filter='overdue' and n.type='task-overdue')
   order by n.created_at desc,n.id desc limit v_limit+1) page;
  result:=jsonb_build_object('notifications',v_notifications,'unread',v_unread,'hasMore',jsonb_array_length(v_notifications)>v_limit);
  if jsonb_array_length(v_notifications)>v_limit then result:=jsonb_set(result,'{notifications}',v_notifications-v_limit);end if;
  result:=result||jsonb_build_object('nextCursor',case when jsonb_array_length(v_notifications)>v_limit then v_notifications->(v_limit-1)->>'cursor' end);
 elsif p_action='read' then
  update public.notifications n set read_at=case when coalesce((p_input->>'read')::boolean,true) then now() end
  where n.company_id=p_company and n.recipient_user_id=p_actor and (p_input->>'id'='all' or n.id=p_input->>'id')
    and private.task_notice_visible(p_company,p_actor,n.task_id,n.type);result:='{"updated":true}';
 elsif p_action='preferences' then
  insert into public.notification_preferences(company_id,user_id,assignment_enabled,updates_enabled,deadline_enabled,overdue_enabled,push_enabled,quiet_start,quiet_end)
  values(p_company,p_actor,(p_input->>'assignmentEnabled')::boolean,(p_input->>'updatesEnabled')::boolean,(p_input->>'deadlineEnabled')::boolean,
   (p_input->>'overdueEnabled')::boolean,(p_input->>'pushEnabled')::boolean,nullif(p_input->>'quietStart','')::time,nullif(p_input->>'quietEnd','')::time)
  on conflict(company_id,user_id) do update set assignment_enabled=excluded.assignment_enabled,updates_enabled=excluded.updates_enabled,
   deadline_enabled=excluded.deadline_enabled,overdue_enabled=excluded.overdue_enabled,push_enabled=excluded.push_enabled,quiet_start=excluded.quiet_start,quiet_end=excluded.quiet_end;
  result:='{"updated":true}';
 elsif p_action='settings' then
  if m.role<>'ADMIN' then raise exception 'ADMIN_REQUIRED';end if;
  perform 1 from public.companies where id=p_company for update;
  select version into v_version from public.company_notification_settings where company_id=p_company;
  if coalesce(v_version,0)<>(p_input->>'expectedVersion')::bigint then raise exception 'VERSION_CONFLICT';end if;
  insert into public.company_notification_settings(company_id,version,sound,volume,deadline_cutoff,daily_reminder_time)
  values(p_company,coalesce(v_version,0)+1,p_input->>'sound',(p_input->>'volume')::numeric,(p_input->>'deadlineCutoff')::time,(p_input->>'dailyReminderTime')::time)
  on conflict(company_id) do update set version=excluded.version,sound=excluded.sound,volume=excluded.volume,
   deadline_cutoff=excluded.deadline_cutoff,daily_reminder_time=excluded.daily_reminder_time,updated_at=now();result:='{"updated":true}';
 elsif p_action='register' then
  perform pg_advisory_xact_lock(hashtextextended(p_input->>'installationId',0));
  update public.push_registrations set active=false,updated_at=now() where user_id<>p_actor and (token=p_input->>'token' or installation_id=p_input->>'installationId');
  v_id:=translate(rtrim(encode(extensions.digest(p_company||p_actor::text||(p_input->>'installationId'),'sha256'),'base64'),'='),'+/','-_');
  insert into public.push_registrations(id,company_id,user_id,installation_id,token,platform)
  values(v_id,p_company,p_actor,p_input->>'installationId',p_input->>'token',coalesce(p_input->>'platform','web'))
  on conflict(company_id,user_id,installation_id) do update set token=excluded.token,platform=excluded.platform,active=true,last_registered_at=now(),updated_at=now();result:='{"registered":true}';
 elsif p_action='unregister' then
  update public.push_registrations set active=false,updated_at=now() where company_id=p_company and user_id=p_actor and installation_id=p_input->>'installationId';result:='{"unregistered":true}';
 else raise exception 'INVALID_ACTION';end if;
 return result||jsonb_build_object('settings',coalesce((select jsonb_build_object('version',s.version,'sound',s.sound,'volume',s.volume,
   'deadlineCutoff',to_char(s.deadline_cutoff,'HH24:MI'),'dailyReminderTime',to_char(s.daily_reminder_time,'HH24:MI'))
   from public.company_notification_settings s where s.company_id=p_company),'{"version":0,"sound":"chime","volume":0.65,"deadlineCutoff":"23:59","dailyReminderTime":"09:00"}'::jsonb),
  'preferences',coalesce((select jsonb_build_object('assignmentEnabled',p.assignment_enabled,'updatesEnabled',p.updates_enabled,
   'deadlineEnabled',p.deadline_enabled,'overdueEnabled',p.overdue_enabled,'pushEnabled',p.push_enabled,
   'quietStart',coalesce(to_char(p.quiet_start,'HH24:MI'),''),'quietEnd',coalesce(to_char(p.quiet_end,'HH24:MI'),''))
   from public.notification_preferences p where p.company_id=p_company and p.user_id=p_actor),
   '{"assignmentEnabled":true,"updatesEnabled":true,"deadlineEnabled":true,"overdueEnabled":true,"pushEnabled":true,"quietStart":"","quietEnd":""}'::jsonb),
  'timeZone',(select time_zone from public.companies where id=p_company),'canManageSettings',m.role='ADMIN');
end $$;

create function private.notify_payroll_paid() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  event_key text;
begin
  if new.section<>'Payroll' or new.deleted
    or new.payload->>'status' is distinct from 'PAID' then return new;end if;
  if tg_op='UPDATE' and old.payload->>'status'='PAID' then return new;end if;

  event_key:='Payroll:'||new.record_id||':'||new.version::text||':paid';
  insert into public.notifications(id,company_id,employee_id,recipient_user_id,event_id,type,title,body,metadata)
  select translate(rtrim(encode(extensions.digest(new.company_id||event_key||m.user_id::text,'sha256'),'base64'),'='),'+/','-_'),
    new.company_id,m.employee_id,m.user_id,event_key,'payroll-paid','Salary payment recorded',
    case when nullif(new.payload->>'month','') is not null and nullif(new.payload->>'paidDate','') is not null
      then format('Your salary payment for %s was recorded on %s.',new.payload->>'month',new.payload->>'paidDate')
      else 'Your salary payment was recorded.' end,
    jsonb_build_object('month',new.payload->>'month','canOpenTask',false)
  from public.company_memberships m
  where m.company_id=new.company_id and m.status='ACTIVE' and m.employee_id=new.payload->>'employeeId'
  on conflict do nothing;
  return new;
end $$;

create trigger zz_payroll_paid_notification after insert or update on public.business_records
  for each row execute function private.notify_payroll_paid();

-- The payroll payment policy allows payment from the last day of the payroll
-- month. Remind authorized accountants once per month with approved unpaid payroll.
create function private.queue_payroll_reminders() returns void
language sql security definer set search_path='' as $$
 insert into public.notifications(id,company_id,employee_id,recipient_user_id,event_id,type,title,body,metadata)
 select translate(rtrim(encode(extensions.digest(p.company_id||p.event_key||m.user_id::text,'sha256'),'base64'),'='),'+/','-_'),
   p.company_id,coalesce(m.employee_id,''),m.user_id,p.event_key,'payroll-due','Payroll payment reminder',
   'Approved payroll for '||p.month||' is ready for payment.',
   jsonb_build_object('month',p.month,'canOpenTask',false)
 from (
   select distinct r.company_id,r.month,'Payroll:'||r.month||':due' as event_key
   from business.payroll r join public.companies c on c.id=r.company_id and c.deleted_at is null
   where not r.deleted and r.status='APPROVED'
   and case when r.month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$' and left(r.month,4)<>'0000'
     then (now() at time zone c.time_zone) >= ((r.month||'-01')::date + interval '1 month' - interval '1 day' + interval '9 hours')
       and (now() at time zone c.time_zone) < (r.month||'-01')::date + interval '2 months'
     else false end
 ) p join public.company_memberships m on m.company_id=p.company_id and m.role='Accountant'
 where private.task_notice_visible(p.company_id,m.user_id,null,'payroll-due')
 on conflict do nothing
$$;

revoke all on function private.notify_payroll_paid(),private.queue_payroll_reminders() from public,anon,authenticated;
select cron.schedule('tpc-payroll-reminders','*/15 * * * *','select private.queue_payroll_reminders()');
