-- Reuse notifications and the existing task/Cron transaction boundary.
alter table public.notifications add column recipient_user_id uuid references auth.users(id);
alter table public.notifications add column actor_user_id uuid;
alter table public.notifications add column event_id text;
alter table public.notifications add column metadata jsonb not null default '{}';
update public.notifications n set recipient_user_id=m.user_id,event_id=n.id
from public.company_memberships m where m.company_id=n.company_id and m.employee_id=n.employee_id;
create index notifications_recipient_page on public.notifications(company_id,recipient_user_id,created_at desc,id desc);
create index notifications_recipient_unread on public.notifications(company_id,recipient_user_id,created_at desc) where read_at is null;
create unique index notifications_event_recipient on public.notifications(company_id,recipient_user_id,event_id);

create table public.company_notification_settings (
 company_id text primary key references public.companies(id),version bigint not null default 1,
 sound text not null default 'chime' check(sound in ('none','chime','bell','alert')),
 volume numeric not null default 0.65 check(volume between 0 and 1),
 deadline_cutoff time not null default '23:59',daily_reminder_time time not null default '09:00',
 updated_at timestamptz not null default now()
);
create table public.notification_preferences (
 company_id text not null references public.companies(id),user_id uuid not null references auth.users(id),
 assignment_enabled boolean not null default true,updates_enabled boolean not null default true,
 deadline_enabled boolean not null default true,overdue_enabled boolean not null default true,
 push_enabled boolean not null default true,quiet_start time,quiet_end time,
 primary key(company_id,user_id),check((quiet_start is null)=(quiet_end is null))
);
create table public.push_registrations (
 id text primary key,company_id text not null references public.companies(id),user_id uuid not null references auth.users(id),
 installation_id text not null,token text not null,platform text not null default 'web',
 active boolean not null default true,last_registered_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(company_id,user_id,installation_id)
);
create index push_registrations_active on public.push_registrations(company_id,user_id) where active;
create table private.notification_push_jobs (
 id bigint generated always as identity primary key,notification_id text not null references public.notifications(id) on delete cascade,
 registration_id text not null references public.push_registrations(id),status text not null default 'PENDING',
 attempts integer not null default 0,available_at timestamptz not null default now(),lease_id uuid,lease_until timestamptz,
 last_error text,delivered_at timestamptz,unique(notification_id,registration_id)
);
create index notification_push_pending on private.notification_push_jobs(available_at,id) where status in ('PENDING','SENDING');
alter table public.company_notification_settings enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.push_registrations enable row level security;
revoke all on public.company_notification_settings,public.notification_preferences,public.push_registrations,private.notification_push_jobs from public,anon,authenticated;
grant all on public.company_notification_settings,public.notification_preferences,public.push_registrations,private.notification_push_jobs to service_role;
grant usage,select on sequence private.notification_push_jobs_id_seq to service_role;

create function private.task_deadline(p_company text,p_task text) returns timestamptz
language sql stable security definer set search_path='' as $$
 select (t.due_date+coalesce(nullif(t.end_time,'')::time,s.deadline_cutoff,'23:59'::time)) at time zone c.time_zone
 from business.tasks t join public.companies c on c.id=t.company_id
 left join public.company_notification_settings s on s.company_id=c.id
 where t.company_id=p_company and t.record_id=p_task and not t.deleted
$$;
create function private.task_notice_visible(p_company text,p_user uuid,p_task text,p_type text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.company_memberships m join public.companies c on c.id=m.company_id
 where m.company_id=p_company and m.user_id=p_user and m.status='ACTIVE' and c.deleted_at is null and
 (m.role='ADMIN' or exists(select 1 from private.task_access(p_company,p_user) a where
   p_type in ('task-unassigned','task-deleted') or exists(select 1 from business.tasks t where t.company_id=p_company and t.record_id=p_task and not t.deleted and (a.all_tasks or a.employee_id=t.employee_id)))))
$$;
revoke all on function private.task_notice_visible(text,uuid,text,text) from public,anon;
grant execute on function private.task_notice_visible(text,uuid,text,text) to authenticated,service_role;
drop policy notification_read on public.notifications;
create policy notification_read on public.notifications for select to authenticated using(
 recipient_user_id=(select auth.uid()) and private.task_notice_visible(company_id,recipient_user_id,task_id,type));

create function private.queue_notification_push() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into private.notification_push_jobs(notification_id,registration_id)
 select new.id,r.id from public.push_registrations r where r.company_id=new.company_id and r.user_id=new.recipient_user_id and r.active
 and new.actor_user_id is distinct from r.user_id on conflict do nothing;
 return new;
end $$;
create trigger notification_push_outbox after insert on public.notifications for each row execute function private.queue_notification_push();

create function private.emit_task_notice(p_company text,p_task text,p_event text,p_type text,p_title text,p_body text,p_actor uuid,
 p_employee text,p_previous text default null,p_metadata jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare m record;v_type text;v_id text;v_body text;v_title text;
begin
 for m in select distinct x.user_id,x.employee_id,x.role from public.company_memberships x
 where x.company_id=p_company and x.status='ACTIVE' and (x.role='ADMIN' or x.employee_id=p_employee or x.employee_id=p_previous)
 loop
  v_type:=case when m.role<>'ADMIN' and m.employee_id=p_previous and p_previous is distinct from p_employee then 'task-unassigned' else p_type end;
  if not private.task_notice_visible(p_company,m.user_id,p_task,v_type) then continue;end if;
  v_title:=case when v_type='task-unassigned' then 'Task unassigned' else p_title end;
  v_body:=case when v_type='task-unassigned' then 'A task has been removed from your assignments.'
    when v_type='task-deleted' and m.role<>'ADMIN' then 'An assigned task was deleted.' else p_body end;
  v_id:=translate(rtrim(encode(extensions.digest(p_company||p_event||m.user_id::text,'sha256'),'base64'),'='),'+/','-_');
  insert into public.notifications(id,company_id,employee_id,recipient_user_id,actor_user_id,task_id,event_id,type,title,body,metadata)
  values(v_id,p_company,coalesce(m.employee_id,''),m.user_id,p_actor,p_task,p_event,v_type,v_title,v_body,
    p_metadata||jsonb_build_object('canOpenTask',v_type not in ('task-unassigned','task-deleted')))
  on conflict do nothing;
 end loop;
end $$;

drop trigger task_assignment_notification on public.business_records;
create or replace function private.task_assignment_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare t business.tasks;v_task text;v_actor uuid;v_actor_name text;v_type text;v_title text;v_body text;v_previous text;v_fields jsonb;v_event text;
begin
 if new.section not in ('Tasks','TaskComments','DocumentRegistry') then return new;end if;
 if tg_op='UPDATE' and old.payload=new.payload and old.deleted=new.deleted then return new;end if;
 if new.section='Tasks' then v_task:=new.record_id;
 elsif new.section='TaskComments' then v_task:=new.payload->>'taskId';
 elsif new.payload->>'relatedSection'='Tasks' then v_task:=new.payload->>'relatedRecordId';else return new;end if;
 select * into t from business.tasks where company_id=new.company_id and record_id=v_task;
 if not found then return new;end if;
 select m.user_id,coalesce(e.full_name,case when m.role='ADMIN' then 'Admin' else 'Workspace user' end)
 into v_actor,v_actor_name from public.company_memberships m left join business.employees e on e.company_id=m.company_id and e.record_id=m.employee_id
 where m.company_id=new.company_id and (m.user_id::text=new.payload->>'updatedBy' or m.employee_id=new.payload->>'updatedBy') limit 1;
 v_actor_name:=coalesce(v_actor_name,'Workspace user');
 v_event:=new.section||':'||new.record_id||':'||new.version::text;
 if new.section='Tasks' then
  if tg_op='UPDATE' then v_previous:=old.payload->>'employeeId';end if;
  select coalesce(jsonb_agg(k),'[]') into v_fields from jsonb_object_keys(new.payload) k
   where k in ('title','description','employeeId','status','priority','dueDate','endTime','startDate','startTime','project','reminder')
   and (tg_op='INSERT' or old.payload->k is distinct from new.payload->k);
  if new.deleted then v_type:='task-deleted';v_title:='Task deleted';
  elsif tg_op='INSERT' then v_type:='task-assigned';v_title:='New task assigned';
  elsif v_previous is distinct from new.payload->>'employeeId' then v_type:='task-assigned';v_title:='Task reassigned';
  elsif new.payload->>'status' is distinct from old.payload->>'status' then
   v_type:='task-status';v_title:='Task status updated';
  elsif new.payload->>'dueDate' is distinct from old.payload->>'dueDate' or new.payload->>'endTime' is distinct from old.payload->>'endTime' then
   v_type:='task-deadline';v_title:='Task deadline updated';
  else v_type:='task-updated';v_title:='Task updated';end if;
  if tg_op='UPDATE' and v_fields='[]' and not new.deleted and old.deleted=new.deleted then return new;end if;
  v_body:=v_actor_name||': '||left(t.title,160)||case when v_type='task-status' then ' ('||coalesce(old.payload->>'status','')||' → '||coalesce(new.payload->>'status','')||')' else '' end;
 else
  v_fields:='[]';v_type:=case when new.section='TaskComments' then 'task-comment' else 'task-attachment' end;
  v_title:=case when new.section='TaskComments' then 'Task comment added' when new.deleted then 'Task attachment removed' else 'Task attachment added' end;
  v_body:=v_actor_name||': '||left(t.title,160);
 end if;
 perform private.emit_task_notice(new.company_id,v_task,v_event,v_type,v_title,v_body,v_actor,t.employee_id,v_previous,
  jsonb_build_object('actorName',v_actor_name,'changedFields',v_fields,'taskVersion',t.version));
 return new;
end $$;
-- Run after sync_structured_record so task payloads and assignments are current.
create trigger zz_task_notification after insert or update on public.business_records for each row execute function private.task_assignment_notification();

create or replace function private.queue_task_reminders() returns void language plpgsql security definer set search_path='' as $$
declare r record;v_due timestamptz;v_type text;v_stage text;v_local timestamp;v_event text;
begin
 for r in select t.*,c.time_zone,coalesce(s.daily_reminder_time,'09:00'::time) daily_time
 from business.tasks t join public.companies c on c.id=t.company_id
 left join public.company_notification_settings s on s.company_id=c.id
 where not t.deleted and c.deleted_at is null and t.status not in ('COMPLETED','CANCELLED','ARCHIVED')
 and coalesce(t.reminder,'1_DAY')<>'NONE' and t.due_date <= ((now() at time zone c.time_zone)::date+1)
 loop
  v_due:=private.task_deadline(r.company_id,r.record_id);v_local:=now() at time zone r.time_zone;v_stage:=null;
  if now()>=v_due-interval '24 hours' and now()<v_due-interval '24 hours'+interval '5 minutes' then v_stage:='24h';
  elsif now()>=v_due-interval '1 hour' and now()<v_due-interval '1 hour'+interval '5 minutes' then v_stage:='1h';
  elsif now()>=v_due and now()<v_due+interval '1 minute' then v_stage:='due';
  elsif now()>=v_due+interval '1 minute' and now()<v_due+interval '5 minutes' then v_stage:='overdue';
  elsif now()>v_due and v_local::date>(v_due at time zone r.time_zone)::date
    and v_local::time>=r.daily_time and v_local::time<r.daily_time+interval '5 minutes' then v_stage:='daily-'||v_local::date::text;end if;
  if v_stage is null then continue;end if;
  v_type:=case when v_stage in ('24h','1h','due') then 'task-due' else 'task-overdue' end;
  v_event:='reminder:'||r.record_id||':'||extract(epoch from v_due)::text||':'||v_stage;
  perform private.emit_task_notice(r.company_id,r.record_id,v_event,v_type,
   case v_stage when '24h' then 'Task deadline tomorrow' when '1h' then 'Task due in one hour' when 'due' then 'Task deadline reached' else 'Overdue task' end,
   left(r.title,160)||' · '||r.due_date::text||' ('||r.time_zone||')',null,r.employee_id,null,
   jsonb_build_object('deadlineAt',v_due,'reminderStage',v_stage));
 end loop;
 delete from public.company_changes where created_at<now()-interval '7 days';
end $$;

create function private.task_push_allowed(n public.notifications) returns boolean language sql stable security definer set search_path='' as $$
 select private.task_notice_visible(n.company_id,n.recipient_user_id,n.task_id,n.type)
 and coalesce(p.push_enabled,true)
 and case when n.type='task-overdue' then coalesce(p.overdue_enabled,true)
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

create function public.claim_notification_push(p_limit integer default 50) returns jsonb language plpgsql security definer set search_path='' as $$
declare j record;v_result jsonb:='[]';v_lease uuid;v_quiet timestamptz;v_now timestamp;
begin
 if p_limit not between 1 and 100 then raise exception 'INVALID_LIMIT';end if;
 for j in select q.*,n as notice,r.token,r.active,c.time_zone,s.sound,s.volume,p.quiet_start,p.quiet_end
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
   'companyId',(j.notice).company_id,'taskId',(j.notice).task_id,'eventId',(j.notice).event_id,'type',(j.notice).type,
   'sound',coalesce(j.sound,'chime'),'volume',coalesce(j.volume,0.65),'attempts',j.attempts+1));
 end loop;
 return v_result;
end $$;
create function public.finish_notification_push(p_id bigint,p_lease uuid,p_status text,p_error text default null) returns void
language plpgsql security definer set search_path='' as $$
declare registration text;
begin
 if p_status not in ('DELIVERED','RETRY','INVALID','FAILED') then raise exception 'INVALID_STATUS';end if;
 update private.notification_push_jobs set status=case when p_status='RETRY' and attempts<8 then 'PENDING'
  when p_status='DELIVERED' then 'DELIVERED' else 'FAILED' end,
  available_at=now()+make_interval(secs=>least(3600,15*power(2,attempts)::integer)),lease_until=null,
  delivered_at=case when p_status='DELIVERED' then now() end,last_error=left(p_error,120)
 where id=p_id and lease_id=p_lease and status='SENDING' returning registration_id into registration;
 if p_status='INVALID' and registration is not null then update public.push_registrations set active=false,updated_at=now() where id=registration;end if;
end $$;
revoke all on function public.claim_notification_push(integer),public.finish_notification_push(bigint,uuid,text,text) from public,anon,authenticated;
grant execute on function public.claim_notification_push(integer),public.finish_notification_push(bigint,uuid,text,text) to service_role;
revoke all on function private.emit_task_notice(text,text,text,text,text,text,uuid,text,text,jsonb),private.task_deadline(text,text),private.task_push_allowed(public.notifications),private.queue_notification_push(),private.task_assignment_notification() from public,anon,authenticated;
create function public.task_notification_api(p_company text,p_actor uuid,p_action text,p_input jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.company_memberships;result jsonb;v_notifications jsonb;v_unread bigint;v_cursor timestamptz;v_cursor_id text;v_filter text;v_id text;v_version bigint;v_limit integer;
begin
 select * into m from public.company_memberships where company_id=p_company and user_id=p_actor and status='ACTIVE';
 if not found or not exists(select 1 from public.companies where id=p_company and deleted_at is null)
  or (m.role<>'ADMIN' and not exists(select 1 from private.task_access(p_company,p_actor))) then raise exception 'NOTIFICATION_FORBIDDEN';end if;
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
   and (v_filter not in ('unread','deadline','overdue') or v_filter='unread' and n.read_at is null
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
  update public.push_registrations set active=false,updated_at=now() where user_id<>p_actor and (token=p_input->>'token' or installation_id=p_input->>'installationId');
  v_id:=translate(rtrim(encode(extensions.digest(p_company||p_actor::text||(p_input->>'installationId'),'sha256'),'base64'),'='),'+/','-_');
  insert into public.push_registrations(id,company_id,user_id,installation_id,token,platform)
  values(v_id,p_company,p_actor,p_input->>'installationId',p_input->>'token','web')
  on conflict(company_id,user_id,installation_id) do update set token=excluded.token,active=true,last_registered_at=now(),updated_at=now();result:='{"registered":true}';
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
create function public.deactivate_push_installation(p_actor uuid,p_installation text) returns void language sql security definer set search_path='' as $$
 update public.push_registrations set active=false,updated_at=now() where user_id=p_actor and installation_id=p_installation
$$;
revoke all on function public.task_notification_api(text,uuid,text,jsonb),public.deactivate_push_installation(uuid,text) from public,anon,authenticated;
grant execute on function public.task_notification_api(text,uuid,text,jsonb),public.deactivate_push_installation(uuid,text) to service_role;

-- This job is inert until the administrator configures its Vault secrets and
-- enables pg_net. The existing reminder job continues to persist in-app alerts.
create function private.dispatch_task_push() returns void language plpgsql security definer set search_path='' as $$
declare worker_url text;worker_secret text;
begin
 if to_regclass('vault.decrypted_secrets') is null or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then return;end if;
 execute 'select decrypted_secret from vault.decrypted_secrets where name=''tpc_push_worker_url'' limit 1' into worker_url;
 execute 'select decrypted_secret from vault.decrypted_secrets where name=''tpc_push_worker_secret'' limit 1' into worker_secret;
 if worker_url is null or worker_secret is null then return;end if;
 if worker_url !~ '^https://[a-z0-9]+\.supabase\.co/functions/v1/task-push-worker$' then raise exception 'INVALID_WORKER_URL';end if;
 execute 'select net.http_post(url:=$1,body:=''{}''::jsonb,headers:=$2,timeout_milliseconds:=10000)'
 using worker_url,jsonb_build_object('Content-Type','application/json','X-Task-Worker-Secret',worker_secret);
end $$;
revoke all on function private.dispatch_task_push() from public,anon,authenticated;
select cron.schedule('tpc-task-push-dispatch','* * * * *','select private.dispatch_task_push()');
