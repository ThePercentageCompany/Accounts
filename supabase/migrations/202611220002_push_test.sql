create or replace function private.task_notice_visible(p_company text,p_user uuid,p_task text,p_type text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
   select 1 from public.company_memberships m
   join public.companies c on c.id=m.company_id and c.deleted_at is null
   where m.company_id=p_company and m.user_id=p_user and m.status='ACTIVE'
   and case
     when p_type in ('payroll-paid','push-test') then true
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

create function public.queue_notification_test(p_company text, p_actor uuid, p_installation text)
returns text language plpgsql security definer set search_path='' as $$
declare
  registration text;
  event_key text;
  notice_id text;
begin
  if not private.task_notice_visible(p_company,p_actor,null,'push-test') then
    return 'NOT_REGISTERED';
  end if;

  select id into registration from public.push_registrations
  where company_id=p_company and user_id=p_actor and installation_id=p_installation and active
  for update;
  if not found then return 'NOT_REGISTERED'; end if;

  if exists (select 1 from public.notification_preferences
    where company_id=p_company and user_id=p_actor and (not push_enabled or not updates_enabled))
  then return 'PUSH_DISABLED'; end if;

  if exists (
    select 1 from private.notification_push_jobs j
    join public.notifications n on n.id=j.notification_id
    where j.registration_id=registration and n.type='push-test'
      and n.created_at > now() - interval '1 minute'
  ) then return 'RATE_LIMITED'; end if;

  event_key := gen_random_uuid()::text;
  notice_id := translate(rtrim(encode(extensions.digest(event_key,'sha256'),'base64'),'='),'+/','-_');
  insert into public.notifications
    (id,company_id,employee_id,recipient_user_id,actor_user_id,event_id,type,title,body,metadata)
  select notice_id,p_company,coalesce(employee_id,''),p_actor,p_actor,event_key,
    'push-test','Test notification','This is a test from your notification settings.',
    '{"canOpenTask":false}'::jsonb
  from public.company_memberships where company_id=p_company and user_id=p_actor and status='ACTIVE';
  if not found then return 'NOT_REGISTERED'; end if;

  -- The inbox trigger skips self-authored notices. Queue only this device.
  insert into private.notification_push_jobs(notification_id,registration_id)
  values(notice_id,registration);
  return 'QUEUED';
end $$;
revoke all on function public.queue_notification_test(text,uuid,text) from public,anon,authenticated;
grant execute on function public.queue_notification_test(text,uuid,text) to service_role;
