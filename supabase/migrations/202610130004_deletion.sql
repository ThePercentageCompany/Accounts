create or replace function public.begin_workspace_deletion(p_company text,p_actor uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.companies where id=p_company for update;
  if not private.is_admin(p_company,p_actor) then raise exception 'WORKSPACE_CHANGED'; end if;
  update public.companies set deleted_at=now(),updated_at=now(),revision=revision+1 where id=p_company;
  update public.company_memberships set status='REVOKED' where company_id=p_company;
end $$;
create or replace function public.complete_workspace_deletion(p_company text,p_actor uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.companies where id=p_company for update;
  if not exists(select 1 from public.company_memberships where company_id=p_company and user_id=p_actor and role='ADMIN') then raise exception 'ADMIN_REQUIRED'; end if;
  if not exists(select 1 from public.companies where id=p_company and deleted_at is not null) then raise exception 'DELETION_NOT_STARTED'; end if;
  delete from private.access_operations where company_id=p_company;
  delete from private.employee_invites where company_id=p_company;
  delete from private.operations where company_id=p_company;
  delete from private.registration_operations where company_id=p_company;
  delete from private.audit_events where company_id=p_company;
  delete from public.notifications where company_id=p_company;
  delete from public.section_permissions where company_id=p_company;
  delete from public.company_memberships where company_id=p_company;
  delete from public.business_records where company_id=p_company;
  delete from public.company_changes where company_id=p_company;
  delete from public.companies where id=p_company;
end $$;
revoke all on function public.begin_workspace_deletion(text,uuid),public.complete_workspace_deletion(text,uuid) from public,anon,authenticated;
grant execute on function public.begin_workspace_deletion(text,uuid),public.complete_workspace_deletion(text,uuid) to service_role;
