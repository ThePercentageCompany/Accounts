create table public.notifications (
  id text primary key,
  company_id text not null references public.companies(id),
  employee_id text not null,
  task_id text not null,
  type text not null,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index notifications_employee on public.notifications(company_id,employee_id,created_at desc);
alter table public.notifications enable row level security;
create policy notification_read on public.notifications for select to authenticated using (
  exists(select 1 from public.company_memberships m where m.company_id=notifications.company_id
    and m.user_id=auth.uid() and m.employee_id=notifications.employee_id and m.status='ACTIVE')
  and private.can_section(company_id,'Tasks'));
revoke all on public.notifications from anon,authenticated;
grant select on public.notifications to authenticated;
alter publication supabase_realtime add table public.notifications;

create or replace function private.task_assignment_notification()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_id text;
begin
  if new.section='Tasks' and not new.deleted and new.payload->>'employeeId' is not null
    and (tg_op='INSERT' or (old.payload->>'employeeId') is distinct from (new.payload->>'employeeId')) then
    v_id:=translate(rtrim(encode(extensions.digest(new.company_id||new.record_id||new.version::text||'assigned','sha256'),'base64'),'='),'+/','-_');
    insert into public.notifications(id,company_id,employee_id,task_id,type,title,body)
      values(v_id,new.company_id,new.payload->>'employeeId',new.record_id,'task-assigned','New task assigned',
        'You have been assigned: '||left(new.payload->>'title',160)) on conflict(id) do nothing;
  end if;
  return new;
end $$;
create trigger task_assignment_notification after insert or update on public.business_records
  for each row execute function private.task_assignment_notification();

create or replace function private.queue_task_reminders()
returns void language plpgsql security definer set search_path='' as $$
declare r record; v_due timestamptz; v_minutes integer; v_id text;
begin
  for r in select b.* from public.business_records b join public.companies c on c.id=b.company_id
    where b.section='Tasks' and not b.deleted and c.deleted_at is null and b.payload->>'status'<>'COMPLETED'
      and b.payload->>'reminder' in ('AT_DUE','15_MIN','30_MIN','1_HOUR','2_HOURS','1_DAY') loop
    v_due:=((r.payload->>'dueDate')||' '||coalesce(nullif(r.payload->>'endTime',''),'23:59'))::timestamp at time zone 'Asia/Dubai';
    v_minutes:=case r.payload->>'reminder' when '15_MIN' then 15 when '30_MIN' then 30 when '1_HOUR' then 60 when '2_HOURS' then 120 when '1_DAY' then 1440 else 0 end;
    if now()>=v_due-make_interval(mins=>v_minutes) and now()<v_due+interval '1 minute' then
      v_id:=translate(rtrim(encode(extensions.digest(r.company_id||r.record_id||v_due::text||(r.payload->>'reminder'),'sha256'),'base64'),'='),'+/','-_');
      insert into public.notifications(id,company_id,employee_id,task_id,type,title,body)
        values(v_id,r.company_id,r.payload->>'employeeId',r.record_id,'task-due','Task deadline reminder',
          left(r.payload->>'title',160)||' is due '||(r.payload->>'dueDate')||' (Dubai time)') on conflict(id) do nothing;
    end if;
  end loop;
  delete from public.company_changes where created_at<now()-interval '7 days';
end $$;
revoke all on function private.queue_task_reminders() from public,anon,authenticated;
grant execute on function private.queue_task_reminders() to service_role;
-- Enable pg_cron in the project's Integrations > Cron before deploying this
-- migration. A database job avoids an external scheduler or Google task queue.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('tpc-task-reminders','* * * * *','select private.queue_task_reminders()');
