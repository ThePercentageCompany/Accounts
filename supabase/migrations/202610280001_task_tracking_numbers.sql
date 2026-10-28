-- Keep tracking numbers server-owned and consistent in compatibility records,
-- typed task payloads, list/detail responses, and offline replication.
begin;
create function private.task_tracking_number() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.section = 'Tasks' then
    new.payload := new.payload || jsonb_build_object('taskNumber', new.ordinal);
  end if;
  return new;
end $$;
revoke all on function private.task_tracking_number() from public,anon,authenticated;
create trigger task_tracking_number before insert or update on public.business_records
for each row execute function private.task_tracking_number();

update public.business_records set payload = payload ||
  jsonb_build_object('taskNumber', ordinal) where section='Tasks';
-- The existing task_payload trigger copies the enriched compatibility payload.
update business.tasks set payload = payload;
commit;
