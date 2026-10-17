create table private.access_operations (
  company_id text not null references public.companies(id),
  operation_key text not null,
  employee_id text not null,
  action text not null check(action in ('issue','reset','revoke')),
  invite_id text not null,
  auth_email text not null,
  status text not null default 'PENDING' check(status in ('PENDING','COMPLETED')),
  primary key(company_id,operation_key)
);
alter table public.company_memberships add column access_valid_after timestamptz not null default '-infinity';
grant all on private.access_operations to service_role;

create or replace function private.refresh_employee_permissions(p_company text,p_user uuid,p_employee text)
returns void language plpgsql security definer set search_path='' as $$
declare v_employee jsonb; v_section text; v_role text; v_scope text;
begin
  select payload into strict v_employee from public.business_records
    where company_id=p_company and section='Employees' and record_id=p_employee and not deleted;
  v_role:=v_employee->>'role';
  if v_role not in ('Staff','Manager','Accountant') then raise exception 'INVALID_EMPLOYEE_ROLE'; end if;
  update public.company_memberships set role=v_role,
    status=case when v_employee->>'employmentStatus'='ACTIVE' then status else 'REVOKED' end
    where company_id=p_company and user_id=p_user;
  delete from public.section_permissions where company_id=p_company and user_id=p_user;
  for v_section in select jsonb_array_elements_text(coalesce(v_employee->'allowedSections','[]')) loop
    v_scope:=case when v_role='Staff' and v_section in ('Employees','Payroll','Office & Attendance','Fixed Assets','Income & Expenses','Tasks','Calendar') then 'SELF' else 'COMPANY' end;
    insert into public.section_permissions(company_id,user_id,section,scope,can_write)
    values(p_company,p_user,v_section,v_scope,
      v_scope='COMPANY' and coalesce(v_employee->'writableSections','[]'::jsonb) ? v_section);
  end loop;
end $$;
revoke all on function private.refresh_employee_permissions(text,uuid,text) from public,anon,authenticated;

create or replace function public.prepare_employee_access(p_company text,p_actor uuid,p_employee text,p_action text,
  p_key text,p_invite text,p_email text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_op private.access_operations; v_member public.company_memberships;
begin
  perform 1 from public.companies where id=p_company and deleted_at is null for update;
  if not private.is_admin(p_company,p_actor) then raise exception 'WORKSPACE_CHANGED'; end if;
  if p_action not in ('issue','reset','revoke') or p_key !~ '^[A-Za-z0-9_-]{16,128}$' then raise exception 'INVALID_ACCESS'; end if;
  select * into v_op from private.access_operations where company_id=p_company and operation_key=p_key;
  if found then
    if v_op.employee_id<>p_employee or v_op.action<>p_action then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return to_jsonb(v_op);
  end if;
  if exists(select 1 from private.access_operations where company_id=p_company and employee_id=p_employee and status='PENDING') then raise exception 'ACCESS_UPDATE_PENDING'; end if;
  if not exists(select 1 from public.business_records where company_id=p_company and section='Employees'
    and record_id=p_employee and not deleted and (p_action='revoke' or payload->>'employmentStatus'='ACTIVE')) then raise exception 'EMPLOYEE_NOT_FOUND'; end if;
  select * into v_member from public.company_memberships where company_id=p_company and employee_id=p_employee;
  if p_action='issue' and v_member.status='ACTIVE' then raise exception 'ACCESS_ALREADY_ACTIVE'; end if;
  update public.company_memberships set status='REVOKED',access_valid_after=now() where company_id=p_company and employee_id=p_employee;
  update private.employee_invites set revoked_at=now() where company_id=p_company and employee_id=p_employee;
  insert into private.access_operations values(p_company,p_key,p_employee,p_action,p_invite,p_email,
    case when p_action='revoke' then 'COMPLETED' else 'PENDING' end) returning * into v_op;
  update public.companies set revision=revision+1,updated_at=now() where id=p_company;
  insert into public.company_changes(company_id,sections,revision)
    select id,array['Employees','EmployeeAccess'],revision from public.companies where id=p_company;
  return to_jsonb(v_op);
end $$;

create or replace function public.complete_employee_access(p_company text,p_actor uuid,p_key text,p_user uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_op private.access_operations;
begin
  perform 1 from public.companies where id=p_company and deleted_at is null for update;
  if not private.is_admin(p_company,p_actor) then raise exception 'WORKSPACE_CHANGED'; end if;
  select * into strict v_op from private.access_operations where company_id=p_company and operation_key=p_key;
  if v_op.status='COMPLETED' then return to_jsonb(v_op); end if;
  if not exists(select 1 from auth.users where id=p_user and email=v_op.auth_email) then raise exception 'AUTH_IDENTITY_MISMATCH'; end if;
  if exists(select 1 from private.access_operations where company_id=p_company and employee_id=v_op.employee_id
    and operation_key<>p_key and status='PENDING') then raise exception 'ACCESS_UPDATE_PENDING'; end if;
  delete from private.employee_invites where company_id=p_company and employee_id=v_op.employee_id;
  insert into private.employee_invites values(v_op.invite_id,p_company,v_op.employee_id,p_user,v_op.auth_email,null);
  insert into public.company_memberships(company_id,user_id,employee_id,role,status)
    values(p_company,p_user,v_op.employee_id,'Staff','ACTIVE')
    on conflict(company_id,user_id) do update set employee_id=excluded.employee_id,status='ACTIVE';
  perform private.refresh_employee_permissions(p_company,p_user,v_op.employee_id);
  update private.access_operations set status='COMPLETED' where company_id=p_company and operation_key=p_key returning * into v_op;
  update public.companies set revision=revision+1,updated_at=now() where id=p_company;
  insert into public.company_changes(company_id,sections,revision)
    select id,array['Employees','EmployeeAccess'],revision from public.companies where id=p_company;
  return to_jsonb(v_op);
end $$;

create or replace function public.employee_auth_identity(p_email text)
returns uuid language sql stable security definer set search_path='' as $$
  select id from auth.users where email=p_email
$$;
create or replace function public.employee_invitation(p_invite text)
returns jsonb language sql stable security definer set search_path='' as $$
  select to_jsonb(i) from private.employee_invites i join public.company_memberships m on m.company_id=i.company_id and m.user_id=i.user_id
    join public.companies c on c.id=i.company_id
    where i.invite_id=p_invite and i.revoked_at is null and m.status='ACTIVE' and c.deleted_at is null
$$;
create or replace function public.auth_session_created_at(p_user uuid,p_session uuid)
returns timestamptz language sql stable security definer set search_path='' as $$
  select created_at from auth.sessions where id=p_session and user_id=p_user
$$;
revoke all on function public.auth_session_created_at(uuid,uuid) from public,anon,authenticated;
grant execute on function public.auth_session_created_at(uuid,uuid) to service_role;
revoke all on function public.prepare_employee_access(text,uuid,text,text,text,text,text),
  public.complete_employee_access(text,uuid,text,uuid),public.employee_auth_identity(text),public.employee_invitation(text) from public,anon,authenticated;
grant execute on function public.prepare_employee_access(text,uuid,text,text,text,text,text),
  public.complete_employee_access(text,uuid,text,uuid),public.employee_auth_identity(text),public.employee_invitation(text) to service_role;

create or replace function private.employee_permissions_changed()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_user uuid;
begin
  if new.section='Employees' then
    select user_id into v_user from public.company_memberships where company_id=new.company_id and employee_id=new.record_id;
    if v_user is not null then perform private.refresh_employee_permissions(new.company_id,v_user,new.record_id); end if;
  end if;
  return new;
end $$;
create trigger employee_permissions_changed after insert or update on public.business_records
  for each row execute function private.employee_permissions_changed();

alter publication supabase_realtime add table public.company_memberships;
