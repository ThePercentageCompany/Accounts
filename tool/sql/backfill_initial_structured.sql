-- One-time bootstrap for the current small installation only.
-- Large tenants must use backfill_structured_records in separate transactions
-- with the returned cursor; this guard prevents accidental giant transactions.
do $$
declare p record; result jsonb; total integer;
begin
  select count(*) into total from (select 1 from public.business_records limit 5001) sample;
  if total>5000 then raise exception 'USE_BATCHED_BACKFILL: more than 5000 source records'; end if;
  for p in select distinct company_id,section from public.business_records order by company_id,section loop
    result:=public.backfill_structured_records(p.company_id,p.section,0,5000);
    if (result->>'failed')::integer<>0 or not (result->>'done')::boolean then
      raise exception 'BACKFILL_INCOMPLETE section=% result=%',p.section,result;
    end if;
  end loop;
end $$;

alter table public.business_records validate constraint records_known_section;
alter table public.business_records validate constraint records_payload_company;
alter table public.business_records validate constraint records_payload_identity;

-- Verify source/structured counts in one snapshot. No business payloads returned.
create temporary table structured_verification(section text,source_rows bigint,structured_rows bigint) on commit drop;
do $$
declare p record; actual bigint; expected bigint;
begin
  for p in select section,table_name from private.structured_sections order by section loop
    select count(*) into expected from public.business_records where section=p.section;
    execute format('select count(*) from business.%I',p.table_name) into actual;
    if actual<>expected then raise exception 'STRUCTURED_COUNT_MISMATCH section=%',p.section; end if;
    insert into structured_verification values(p.section,expected,actual);
  end loop;
end $$;
select * from structured_verification where source_rows>0 order by section;
