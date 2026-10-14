create table public.business_groups (
  id text primary key default translate(rtrim(encode(extensions.gen_random_bytes(32),'base64'),'='),'+/','-_'),
  name text not null check(length(btrim(name)) between 1 and 160),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table public.group_memberships (
  group_id text not null references public.business_groups(id),
  user_id uuid not null references auth.users(id),
  role text not null default 'ADMIN' check(role='ADMIN'),
  primary key(group_id,user_id)
);
alter table public.companies add column group_id text references public.business_groups(id);
alter table public.companies add column country_code text check(country_code ~ '^[A-Z]{2}$');
alter table public.companies add column base_currency text not null default 'AED' check(base_currency ~ '^[A-Z]{3}$');
alter table public.companies add column time_zone text not null default 'Asia/Dubai';
alter table public.companies add column tax_registration text not null default '';
create index companies_group on public.companies(group_id) where deleted_at is null;
alter table public.business_groups enable row level security;
alter table public.group_memberships enable row level security;
create policy group_membership_read on public.group_memberships for select to authenticated using(user_id=auth.uid());
create policy business_group_read on public.business_groups for select to authenticated using(
  exists(select 1 from public.group_memberships m where m.group_id=id and m.user_id=auth.uid()));
revoke all on public.business_groups,public.group_memberships from anon,authenticated;
grant select on public.business_groups,public.group_memberships to authenticated;
grant all on public.business_groups,public.group_memberships to service_role;
create table private.group_operations (
  actor_id uuid not null,operation_key text not null,fingerprint text not null,result jsonb not null,
  primary key(actor_id,operation_key)
);
create or replace function public.create_business_group(p_name text,p_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid();v_id text;v_old private.group_operations;v_fingerprint text:='group:'||btrim(p_name);v_result jsonb;
begin
  if v_actor is null or exists(select 1 from auth.users where id=v_actor and raw_app_meta_data->>'kind'='employee') then raise exception 'ADMIN_REQUIRED';end if;
  if p_key !~ '^[A-Za-z0-9_-]{16,128}$' or length(btrim(p_name)) not between 1 and 160 then raise exception 'INVALID_GROUP';end if;
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text||p_key,0));
  select * into v_old from private.group_operations where actor_id=v_actor and operation_key=p_key;
  if found then if v_old.fingerprint<>v_fingerprint then raise exception 'IDEMPOTENCY_CONFLICT';end if;return v_old.result;end if;
  insert into public.business_groups(name,created_by) values(btrim(p_name),v_actor) returning id into v_id;
  insert into public.group_memberships(group_id,user_id) values(v_id,v_actor);
  v_result:=jsonb_build_object('id',v_id,'name',btrim(p_name));
  insert into private.group_operations values(v_actor,p_key,v_fingerprint,v_result);return v_result;
end $$;
create or replace function public.create_country_entity(p_group text,p_name text,p_country text,p_currency text,p_zone text,p_tax text,p_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid();v_result jsonb;v_id text;v_old private.group_operations;
v_fingerprint text:=jsonb_build_array(p_group,btrim(p_name),p_country,p_currency,p_zone,btrim(p_tax))::text;
begin
  if not exists(select 1 from public.group_memberships where group_id=p_group and user_id=v_actor) then raise exception 'ADMIN_REQUIRED';end if;
  if p_country is null or p_currency is null or p_zone is null or p_country !~ '^[A-Z]{2}$' or p_currency !~ '^[A-Z]{3}$' or length(p_tax)>100 or not exists(select 1 from pg_timezone_names where name=p_zone) then raise exception 'INVALID_ENTITY';end if;
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text||p_key,0));
  select * into v_old from private.group_operations where actor_id=v_actor and operation_key=p_key;
  if found then if v_old.fingerprint<>v_fingerprint then raise exception 'IDEMPOTENCY_CONFLICT';end if;return v_old.result;end if;
  if exists(select 1 from private.registration_operations where user_id=v_actor and operation_key=p_key) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  v_result:=public.create_workspace(p_name,p_key);v_id:=v_result->>'companyId';
  update public.companies set group_id=p_group,country_code=p_country,base_currency=p_currency,time_zone=p_zone,tax_registration=btrim(p_tax) where id=v_id;
  update public.business_records set payload=payload||jsonb_build_object('currency',p_currency,'countryCode',p_country,'timeZone',p_zone,'taxNumber',btrim(p_tax))
    where company_id=v_id and section='CompanyProfile';
  v_result:=v_result||jsonb_build_object('groupId',p_group,'countryCode',p_country,'currency',p_currency,'timeZone',p_zone);
  insert into private.group_operations values(v_actor,p_key,v_fingerprint,v_result);return v_result;
end $$;
revoke all on function public.create_business_group(text,text),public.create_country_entity(text,text,text,text,text,text,text) from public,anon;
grant execute on function public.create_business_group(text,text),public.create_country_entity(text,text,text,text,text,text,text) to authenticated;

create or replace function private.entity_profile_changed()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.section='CompanyProfile' then
    update public.companies set base_currency=coalesce(nullif(new.payload->>'currency',''),base_currency),
      tax_registration=coalesce(new.payload->>'taxNumber',tax_registration) where id=new.company_id;
  end if;
  return new;
end $$;
create trigger entity_profile_changed after insert or update on public.business_records for each row execute function private.entity_profile_changed();

-- Aggregate in Postgres rather than downloading every entity's records to Edge.
create or replace function public.business_group_overview(p_actor uuid,p_company text default null)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
  'groups',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name) order by g.name)
    from public.business_groups g join public.group_memberships m on m.group_id=g.id where m.user_id=p_actor),'[]'::jsonb),
  'entities',coalesce((select jsonb_agg(jsonb_build_object('companyId',c.id,'name',c.name,'groupId',c.group_id,
    'countryCode',c.country_code,'currency',c.base_currency,'timeZone',c.time_zone,'taxRegistration',c.tax_registration,
    'metrics',jsonb_build_object(
      'employees',(select count(*) from public.business_records b where b.company_id=c.id and b.section='Employees' and not b.deleted and b.payload->>'employmentStatus'='ACTIVE'),
      'openTasks',(select count(*) from public.business_records b where b.company_id=c.id and b.section='Tasks' and not b.deleted and b.payload->>'status' not in ('COMPLETED','CANCELLED')),
      'invoices',(select count(*) from public.business_records b where b.company_id=c.id and b.section='Invoices' and not b.deleted),
      'outstandingByCurrency',coalesce((select jsonb_object_agg(x.currency,x.amount) from (
        select coalesce(nullif(b.payload->>'currency',''),c.base_currency) as currency,
          sum(coalesce(nullif(b.payload->>'balance',''),'0')::numeric) as amount
        from public.business_records b where b.company_id=c.id and b.section='Invoices' and not b.deleted
          and b.payload->>'status' in ('ISSUED','PARTIALLY_PAID','PARTIALLY_RETURNED','OVERDUE')
        group by coalesce(nullif(b.payload->>'currency',''),c.base_currency)) x),'{}'::jsonb))) order by c.name)
    from public.companies c join public.company_memberships m on m.company_id=c.id
    where m.user_id=p_actor and m.role='ADMIN' and m.status='ACTIVE' and c.deleted_at is null
      and (p_company is null or c.id=p_company)),'[]'::jsonb))
$$;
revoke all on function public.business_group_overview(uuid,text) from public,anon,authenticated;
grant execute on function public.business_group_overview(uuid,text) to service_role;

create or replace function private.queue_task_reminders()
returns void language plpgsql security definer set search_path='' as $$
declare r record;v_due timestamptz;v_minutes integer;v_id text;
begin
  for r in select b.*,c.time_zone from public.business_records b join public.companies c on c.id=b.company_id
    where b.section='Tasks' and not b.deleted and c.deleted_at is null and b.payload->>'status' not in ('COMPLETED','CANCELLED')
      and b.payload->>'reminder' in ('AT_DUE','15_MIN','30_MIN','1_HOUR','2_HOURS','1_DAY') loop
    v_due:=((r.payload->>'dueDate')||' '||coalesce(nullif(r.payload->>'endTime',''),'23:59'))::timestamp at time zone r.time_zone;
    v_minutes:=case r.payload->>'reminder' when '15_MIN' then 15 when '30_MIN' then 30 when '1_HOUR' then 60 when '2_HOURS' then 120 when '1_DAY' then 1440 else 0 end;
    if now()>=v_due-make_interval(mins=>v_minutes) and now()<v_due+interval '1 minute' then
      v_id:=translate(rtrim(encode(extensions.digest(r.company_id||r.record_id||v_due::text||(r.payload->>'reminder'),'sha256'),'base64'),'='),'+/','-_');
      insert into public.notifications(id,company_id,employee_id,task_id,type,title,body)
        values(v_id,r.company_id,r.payload->>'employeeId',r.record_id,'task-due','Task deadline reminder',
          left(r.payload->>'title',160)||' is due '||(r.payload->>'dueDate')||' ('||r.time_zone||')') on conflict(id) do nothing;
    end if;
  end loop;
  delete from public.company_changes where created_at<now()-interval '7 days';
end $$;
