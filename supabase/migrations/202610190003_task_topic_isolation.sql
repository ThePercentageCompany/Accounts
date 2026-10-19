-- Match both the requested channel and stored message topic. This also prevents
-- authenticated SQL reads from using one authorized topic to read other topics.
alter policy task_broadcast_read on realtime.messages using (
 extension='broadcast' and topic=realtime.topic() and exists(
  select 1 from public.company_memberships m
  where m.user_id=(select auth.uid()) and m.status='ACTIVE'
   and realtime.topic()='tasks:'||m.company_id||':'||m.user_id::text
   and private.can_section(m.company_id,'Tasks')));
