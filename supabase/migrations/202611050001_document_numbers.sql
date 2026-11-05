-- Document numbers for every business file.
--
-- Income, expense, payroll and asset records gain a structured "number"
-- column; the projection trigger copies payload->>'number' into it, and every
-- legacy record without a number is numbered once below (ordinal order,
-- continuing after the highest existing sequence per company and year).
-- Receipts posted before the PAY prefix keep their REC- numbers.

alter table business."income" add column if not exists "number" text;
alter table business."expenses" add column if not exists "number" text;
alter table business."payroll" add column if not exists "number" text;
alter table business."assets" add column if not exists "number" text;

create or replace function private.sync_structured_record() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_table text;
begin
  perform private.project_business_record(new.company_id,new.section,new.record_id);
  -- These sections carry their document number in the payload only; their
  -- structured projections predate create-time numbering.
  v_table := case new.section
    when 'Income' then 'income' when 'Expenses' then 'expenses'
    when 'Payroll' then 'payroll' when 'Assets' then 'assets' end;
  if v_table is not null then
    execute format('update business.%I set "number"=$1
      where company_id=$2 and record_id=$3 and "number" is distinct from $1', v_table)
      using new.payload->>'number', new.company_id, new.record_id;
  end if;
  return new;
end $$;
revoke all on function private.sync_structured_record() from public,anon,authenticated;

-- One-time backfill. Every payload update fires sync_structured_record, which
-- re-projects the record and fills the new structured column, so no explicit
-- projection call is needed here.
do $$
declare
  v_section text; v_profile_field text; v_prefix text; v_date_field text;
  v_company text; v_year text; v_seq int; v_row record; v_number text;
begin
  for v_section, v_profile_field, v_prefix, v_date_field in
    select * from (values
      ('Income', null::text, 'INC', 'date'),
      ('Expenses', null::text, 'EXP', 'date'),
      ('Payroll', null::text, 'PAYR', 'month'),
      ('Assets', null::text, 'AST', 'purchaseDate'),
      ('Invoices', 'invoicePrefix', null::text, 'issueDate'),
      ('Quotations', 'quotationPrefix', null::text, 'issueDate'),
      ('Receipts', null::text, 'PAY', 'paymentDate'),
      ('CreditNotes', null::text, 'CN', 'date')
    ) as t(section, profile_field, prefix, date_field)
  loop
    for v_company in
      select distinct company_id from public.business_records where section = v_section
    loop
      if v_prefix is null then
        select upper(nullif(payload->>v_profile_field, '')) into v_prefix
          from public.business_records
          where company_id = v_company and section = 'CompanyProfile' and not deleted
          order by ordinal desc limit 1;
        -- Mirror the service default for companies without a saved prefix.
        v_prefix := coalesce(v_prefix, case when v_section = 'Invoices' then 'INV' else 'QUO' end);
      end if;
      for v_year in
        select distinct substring(payload->>v_date_field from 1 for 4)
          from public.business_records
          where section = v_section and company_id = v_company and not deleted
            and coalesce(payload->>'number', '') = ''
            and payload->>v_date_field ~ '^\d{4}-'
      loop
        select coalesce(max((regexp_match(payload->>'number',
          '^' || v_prefix || '-' || v_year || '-(\d{6})$'))[1]::int), 0) into v_seq
          from public.business_records
          where section = v_section and company_id = v_company and not deleted
            and payload->>'number' ~ ('^' || v_prefix || '-' || v_year || '-\d{6}$');
        for v_row in
          select record_id from public.business_records
          where section = v_section and company_id = v_company and not deleted
            and coalesce(payload->>'number', '') = ''
            and substring(payload->>v_date_field from 1 for 4) = v_year
          order by ordinal
        loop
          v_seq := v_seq + 1;
          if v_seq > 999999 then raise exception 'DOCUMENT_NUMBER_BACKFILL_EXHAUSTED'; end if;
          v_number := v_prefix || '-' || v_year || '-' || lpad(v_seq::text, 6, '0');
          update public.business_records set payload = jsonb_set(payload, '{number}', to_jsonb(v_number))
            where company_id = v_company and section = v_section and record_id = v_row.record_id;
        end loop;
      end loop;
    end loop;
  end loop;
end $$;
