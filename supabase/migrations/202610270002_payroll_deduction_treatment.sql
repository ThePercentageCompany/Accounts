-- Salary reductions and amounts withheld for later remittance have different
-- accounting effects. Preserve historical postings; never infer their type.
alter table business.payroll add column if not exists deduction_type text;

-- Extend the existing projector without replacing any unrelated table branches.
do $$
declare definition text;
begin
  select pg_get_functiondef('private.project_business_record(text,text,text)'::regprocedure) into definition;
  if position('"deduction_type"' in definition) = 0 then
    if position('"bonus_notes","deduction_notes","gross_salary"' in definition) = 0
      or position('r.payload->>''deductionNotes'',' in definition) = 0
      or position('"deduction_notes"=excluded."deduction_notes",' in definition) = 0 then
      raise exception 'PAYROLL_PROJECTOR_REVIEW_REQUIRED';
    end if;
    definition := replace(definition, '"bonus_notes","deduction_notes","gross_salary"', '"bonus_notes","deduction_notes","deduction_type","gross_salary"');
    definition := replace(definition, 'r.payload->>''deductionNotes'',', 'r.payload->>''deductionNotes'', r.payload->>''deductionType'',');
    definition := replace(definition, '"deduction_notes"=excluded."deduction_notes",',
      '"deduction_notes"=excluded."deduction_notes","deduction_type"=excluded."deduction_type",');
    execute definition;
  end if;
end $$;

update business.payroll p set deduction_type = r.payload->>'deductionType'
from public.business_records r
where r.company_id=p.company_id and r.record_id=p.record_id and r.section='Payroll';
