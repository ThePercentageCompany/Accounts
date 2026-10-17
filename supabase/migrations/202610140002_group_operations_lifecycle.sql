-- Registration retry markers belong to an Auth account, not an orphan identity.
alter table private.group_operations add constraint group_operations_actor
  foreign key(actor_id) references auth.users(id) on delete cascade;
