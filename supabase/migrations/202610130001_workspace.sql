create schema if not exists private;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
revoke all on schema private from public, anon, authenticated;

create table public.companies (
  id text primary key check (id ~ '^[A-Za-z0-9_-]{43}$'),
  name text not null check (length(btrim(name)) between 1 and 160),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision bigint not null default 0,
  configuration jsonb not null default '{}'::jsonb,
  deleted_at timestamptz
);
create table public.company_memberships (
  company_id text not null references public.companies(id),
  user_id uuid not null references auth.users(id),
  employee_id text,
  role text not null check (role in ('ADMIN','Staff','Manager','Accountant')),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','REVOKED')),
  created_at timestamptz not null default now(),
  primary key (company_id,user_id),
  unique (company_id,employee_id)
);
create index memberships_user on public.company_memberships(user_id, status);
create table public.section_permissions (
  company_id text not null,
  user_id uuid not null,
  section text not null,
  scope text not null check (scope in ('SELF','COMPANY')),
  can_write boolean not null default false,
  primary key (company_id,user_id,section),
  foreign key (company_id,user_id) references public.company_memberships(company_id,user_id) on delete cascade
);

-- Records use the existing versioned document contract. Indexed identity and
-- foreign-reference expressions avoid spreadsheet scans; business mutations
-- are validated in the Edge domain layer and committed in one SQL transaction.
create table public.business_records (
  company_id text not null references public.companies(id),
  section text not null,
  record_id text not null,
  ordinal bigint not null check (ordinal > 0),
  version bigint not null check (version > 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (company_id,section,record_id),
  unique (company_id,section,ordinal),
  check (record_id ~ '^[A-Za-z0-9_-]{43}$' or (section='CompanyProfile' and record_id='company'))
);
create index records_company_section on public.business_records(company_id,section,ordinal) where not deleted;
create index records_invoice on public.business_records(company_id,section,(payload->>'invoiceId')) where not deleted;
create index records_journal on public.business_records(company_id,section,(payload->>'journalId')) where not deleted;
create index records_employee on public.business_records(company_id,section,(payload->>'employeeId')) where not deleted;
create index records_source on public.business_records(company_id,section,(payload->>'sourceId')) where not deleted;
create index records_date on public.business_records(company_id,section,(payload->>'date')) where not deleted;

create table private.operations (
  company_id text not null references public.companies(id),
  operation_key text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  primary key(company_id,operation_key)
);
create table private.registration_operations (
  user_id uuid not null references auth.users(id),
  operation_key text not null,
  company_id text not null references public.companies(id),
  name text not null,
  primary key(user_id,operation_key)
);
create table private.employee_invites (
  invite_id text primary key,
  company_id text not null references public.companies(id),
  employee_id text not null,
  user_id uuid not null references auth.users(id),
  auth_email text not null,
  revoked_at timestamptz,
  unique(company_id,employee_id)
);
create table private.audit_events (
  id bigint generated always as identity primary key,
  company_id text not null references public.companies(id),
  actor_id uuid not null references auth.users(id),
  changes jsonb not null,
  created_at timestamptz not null default now()
);

create table public.company_changes (
  id bigint generated always as identity primary key,
  company_id text not null references public.companies(id),
  sections text[] not null,
  revision bigint not null,
  created_at timestamptz not null default now()
);
create index company_changes_company on public.company_changes(company_id,id);

create or replace function private.is_admin(p_company text, p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.company_memberships m join public.companies c on c.id=m.company_id
    where m.company_id=p_company and m.user_id=p_user and m.role='ADMIN' and m.status='ACTIVE' and c.deleted_at is null)
$$;
create or replace function private.is_member(p_company text, p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.company_memberships m join public.companies c on c.id=m.company_id
    where m.company_id=p_company and m.user_id=p_user and m.status='ACTIVE' and c.deleted_at is null)
$$;
create or replace function private.can_section(p_company text, p_section text, p_write boolean default false, p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_admin(p_company,p_user) or exists(
    select 1 from public.section_permissions p join public.company_memberships m
      on m.company_id=p.company_id and m.user_id=p.user_id
    join public.companies c on c.id=p.company_id
    where p.company_id=p_company and p.user_id=p_user and p.section=p_section
      and m.status='ACTIVE' and c.deleted_at is null and (not p_write or p.can_write))
$$;

alter table public.companies enable row level security;
alter table public.company_memberships enable row level security;
alter table public.section_permissions enable row level security;
alter table public.business_records enable row level security;
alter table public.company_changes enable row level security;
create policy company_read on public.companies for select to authenticated using (private.is_member(id));
create policy membership_read on public.company_memberships for select to authenticated
  using (user_id=auth.uid() or private.is_admin(company_id));
create policy permission_read on public.section_permissions for select to authenticated
  using (user_id=auth.uid() or private.is_admin(company_id));
create policy change_read on public.company_changes for select to authenticated
  using (private.is_member(company_id) and (private.is_admin(company_id) or exists(
    select 1 from public.section_permissions p where p.company_id=company_changes.company_id
      and p.user_id=auth.uid())));
-- Raw payloads never go directly to clients: Edge functions enforce field
-- projection and SELF-scoped parent visibility before returning records.
revoke all on public.business_records from anon, authenticated;
revoke insert, update, delete on public.companies, public.company_memberships,
  public.section_permissions, public.company_changes from anon, authenticated;
grant select on public.companies, public.company_memberships, public.section_permissions, public.company_changes to authenticated;
grant usage on schema private to authenticated, service_role;
grant execute on function private.is_admin(text,uuid), private.is_member(text,uuid), private.can_section(text,text,boolean,uuid) to authenticated, service_role;
grant all on all tables in schema private to service_role;

create or replace function public.create_workspace(p_name text, p_operation_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_id text; v_old private.registration_operations; v_name text:=btrim(p_name);
begin
  if v_user is null then raise exception 'UNAUTHORIZED'; end if;
  if exists(select 1 from auth.users where id=v_user and raw_app_meta_data->>'kind'='employee') then raise exception 'ADMIN_REQUIRED'; end if;
  if length(v_name) not between 1 and 160 or p_operation_key !~ '^[A-Za-z0-9_-]{16,128}$' then raise exception 'INVALID_COMPANY'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user::text||p_operation_key,0));
  select * into v_old from private.registration_operations where user_id=v_user and operation_key=p_operation_key;
  if found then
    if v_old.name<>v_name then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    if not private.is_admin(v_old.company_id,v_user) then raise exception 'COMPANY_NOT_FOUND'; end if;
    return jsonb_build_object('companyId',v_old.company_id,'name',v_name,'stage','READY','version',1,'replayed',true);
  end if;
  v_id:=translate(rtrim(encode(extensions.gen_random_bytes(32),'base64'),'='),'+/','-_');
  insert into public.companies(id,name,created_by) values(v_id,v_name,v_user);
  insert into public.company_memberships(company_id,user_id,role) values(v_id,v_user,'ADMIN');
  insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
  values(v_id,'CompanyProfile','company',2,1,jsonb_build_object('recordId','company','companyId',v_id,
    'name',v_name,'currency','AED','recordVersion',1,'isDeleted',false,'createdBy',v_user::text,'updatedBy',v_user::text,
    'createdAt',floor(extract(epoch from now())*1000),'updatedAt',floor(extract(epoch from now())*1000)));
  insert into private.registration_operations values(v_user,p_operation_key,v_id,v_name);
  return jsonb_build_object('companyId',v_id,'name',v_name,'stage','READY','version',1,'replayed',false);
end $$;
revoke all on function public.create_workspace(text,text) from public,anon;
grant execute on function public.create_workspace(text,text) to authenticated;

-- Only the verified Edge service may call this commit boundary. It checks live
-- membership again, serializes per tenant, and atomically persists source rows,
-- ledger rows, operation markers, configuration, audit and Realtime invalidation.
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
    select version into v_version from public.business_records where company_id=p_company and section=v_section and record_id=v_change->>'recordId';
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

create or replace function public.load_workspace_operations(p_company text,p_keys text[])
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(operation_key,payload),'{}'::jsonb)
  from private.operations where company_id=p_company and operation_key=any(p_keys)
$$;
revoke all on function public.load_workspace_operations(text,text[]) from public,anon,authenticated;
grant execute on function public.load_workspace_operations(text,text[]) to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('company-documents','company-documents',false,6291456,array['application/pdf','image/png','image/jpeg','text/html'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
-- Storage access is through the Edge API's record authorization. No raw file
-- paths or public URLs bypass employee section/record permissions.

alter publication supabase_realtime add table public.company_changes;
grant all on public.companies,public.company_memberships,public.section_permissions,
  public.business_records,public.company_changes to service_role;
