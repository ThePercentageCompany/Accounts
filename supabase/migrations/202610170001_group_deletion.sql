create or replace function public.delete_business_group(p_group text,p_actor uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.business_groups where id=p_group for update;
  if not found then return; end if;
  if not exists(select 1 from public.group_memberships where group_id=p_group and user_id=p_actor and role='ADMIN') then
    raise exception 'ADMIN_REQUIRED';
  end if;
  if exists(select 1 from public.companies where group_id=p_group) then
    raise exception 'GROUP_NOT_EMPTY';
  end if;
  delete from public.group_memberships where group_id=p_group;
  delete from private.group_operations where result->>'id'=p_group or result->>'groupId'=p_group;
  delete from public.business_groups where id=p_group;
end $$;
revoke all on function public.delete_business_group(text,uuid) from public,anon,authenticated;
grant execute on function public.delete_business_group(text,uuid) to service_role;
