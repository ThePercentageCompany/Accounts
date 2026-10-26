-- Company borrowing from banks, private institutions and individuals.
insert into private.structured_sections(section,table_name,access_section)
values ('CompanyLoans','company_loans','Cash & Bank');
create table business.company_loans (
  company_id text not null,
  record_id text not null,
  source_section text not null default 'CompanyLoans' check(source_section='CompanyLoans'),
  ordinal bigint not null check(ordinal>0), version bigint not null check(version>0),
  deleted boolean not null default false, updated_at timestamptz not null,
  created_at_ms numeric, created_by text, updated_by text,
  lender_name text,
  lender_type text,
  date date,
  principal numeric,
  interest_rate numeric,
  installment_amount numeric,
  due_date date,
  payment_account text,
  reference text,
  notes text,
  repaid_amount numeric,
  interest_paid numeric,
  outstanding_balance numeric,
  last_repayment_date date,
  principal_payment numeric,
  interest_payment numeric,
  payment_reference text,
  status text,
  primary key(company_id,record_id), unique(company_id,ordinal),
  foreign key(company_id,source_section,record_id)
    references public.business_records(company_id,section,record_id) on delete cascade
);
alter table business.company_loans enable row level security;
revoke all on business.company_loans from public,anon,authenticated;
grant select on business.company_loans to service_role;
create index company_loans_live on business.company_loans(company_id,ordinal) where not deleted;
create index company_loans_status on business.company_loans(company_id,status,ordinal) where not deleted;
create index company_loans_due_date on business.company_loans(company_id,due_date,ordinal) where not deleted;
-- Preserve all existing typed projections, including payroll notes.
create or replace function private.project_business_record(p_company text,p_section text,p_id text)
returns void language plpgsql security definer set search_path='' as $$
begin
  case p_section
    when 'CompanyProfile' then
      insert into business."company_profile" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","name","address","email","phone","tax_number","currency","invoice_prefix","quotation_prefix","bank_name","account_holder","account_number","iban","swift","logo_document_id")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'name',
        r.payload->>'address',
        r.payload->>'email',
        r.payload->>'phone',
        r.payload->>'taxNumber',
        r.payload->>'currency',
        r.payload->>'invoicePrefix',
        r.payload->>'quotationPrefix',
        r.payload->>'bankName',
        r.payload->>'accountHolder',
        r.payload->>'accountNumber',
        r.payload->>'iban',
        r.payload->>'swift',
        r.payload->>'logoDocumentId'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","name"=excluded."name","address"=excluded."address","email"=excluded."email","phone"=excluded."phone","tax_number"=excluded."tax_number","currency"=excluded."currency","invoice_prefix"=excluded."invoice_prefix","quotation_prefix"=excluded."quotation_prefix","bank_name"=excluded."bank_name","account_holder"=excluded."account_holder","account_number"=excluded."account_number","iban"=excluded."iban","swift"=excluded."swift","logo_document_id"=excluded."logo_document_id"
      where "company_profile".version<=excluded.version;
    when 'Employees' then
      insert into business."employees" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","employee_code","full_name","email","phone","department","designation","join_date","last_employment_date","employment_status","role_id","basic_salary","allowances","iban","address","bank_name","emirates_id","passport_number","visa_expiry","currency","role","allowed_sections","writable_sections")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'employeeCode',
        r.payload->>'fullName',
        r.payload->>'email',
        r.payload->>'phone',
        r.payload->>'department',
        r.payload->>'designation',
        nullif(r.payload->>'joinDate','')::date,
        nullif(r.payload->>'lastEmploymentDate','')::date,
        r.payload->>'employmentStatus',
        r.payload->>'roleId',
        private.structured_number(r.payload->>'basicSalary'),
        private.structured_number(r.payload->>'allowances'),
        r.payload->>'iban',
        r.payload->>'address',
        r.payload->>'bankName',
        r.payload->>'emiratesId',
        r.payload->>'passportNumber',
        nullif(r.payload->>'visaExpiry','')::date,
        r.payload->>'currency',
        r.payload->>'role',
        r.payload->'allowedSections',
        r.payload->'writableSections'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","employee_code"=excluded."employee_code","full_name"=excluded."full_name","email"=excluded."email","phone"=excluded."phone","department"=excluded."department","designation"=excluded."designation","join_date"=excluded."join_date","last_employment_date"=excluded."last_employment_date","employment_status"=excluded."employment_status","role_id"=excluded."role_id","basic_salary"=excluded."basic_salary","allowances"=excluded."allowances","iban"=excluded."iban","address"=excluded."address","bank_name"=excluded."bank_name","emirates_id"=excluded."emirates_id","passport_number"=excluded."passport_number","visa_expiry"=excluded."visa_expiry","currency"=excluded."currency","role"=excluded."role","allowed_sections"=excluded."allowed_sections","writable_sections"=excluded."writable_sections"
      where "employees".version<=excluded.version;
    when 'Customers' then
      insert into business."customers" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","name","email","phone","tax_number","address","preferred_currency")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'name',
        r.payload->>'email',
        r.payload->>'phone',
        r.payload->>'taxNumber',
        r.payload->>'address',
        r.payload->>'preferredCurrency'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","name"=excluded."name","email"=excluded."email","phone"=excluded."phone","tax_number"=excluded."tax_number","address"=excluded."address","preferred_currency"=excluded."preferred_currency"
      where "customers".version<=excluded.version;
    when 'ProductsServices' then
      insert into business."products_services" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","name","description","unit","unit_price","tax_rate","status")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'name',
        r.payload->>'description',
        r.payload->>'unit',
        private.structured_number(r.payload->>'unitPrice'),
        private.structured_number(r.payload->>'taxRate'),
        r.payload->>'status'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","name"=excluded."name","description"=excluded."description","unit"=excluded."unit","unit_price"=excluded."unit_price","tax_rate"=excluded."tax_rate","status"=excluded."status"
      where "products_services".version<=excluded.version;
    when 'Invoices' then
      insert into business."invoices" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","number","customer_id","issue_date","due_date","status","currency","subtotal","discount","tax_amount","total","paid_amount","balance","void_date","void_reason","notes","payment_terms","document_id","base_currency","exchange_rate","rate_date","rate_source","payment_exchange_rate","base_amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'number',
        nullif(r.payload->>'customerId',''),
        nullif(r.payload->>'issueDate','')::date,
        nullif(r.payload->>'dueDate','')::date,
        r.payload->>'status',
        r.payload->>'currency',
        private.structured_number(r.payload->>'subtotal'),
        private.structured_number(r.payload->>'discount'),
        private.structured_number(r.payload->>'taxAmount'),
        private.structured_number(r.payload->>'total'),
        private.structured_number(r.payload->>'paidAmount'),
        private.structured_number(r.payload->>'balance'),
        nullif(r.payload->>'voidDate','')::date,
        r.payload->>'voidReason',
        r.payload->>'notes',
        r.payload->>'paymentTerms',
        r.payload->>'documentId',
        r.payload->>'baseCurrency',
        private.structured_number(r.payload->>'exchangeRate'),
        nullif(r.payload->>'rateDate','')::date,
        r.payload->>'rateSource',
        private.structured_number(r.payload->>'paymentExchangeRate'),
        private.structured_number(r.payload->>'baseAmount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","number"=excluded."number","customer_id"=excluded."customer_id","issue_date"=excluded."issue_date","due_date"=excluded."due_date","status"=excluded."status","currency"=excluded."currency","subtotal"=excluded."subtotal","discount"=excluded."discount","tax_amount"=excluded."tax_amount","total"=excluded."total","paid_amount"=excluded."paid_amount","balance"=excluded."balance","void_date"=excluded."void_date","void_reason"=excluded."void_reason","notes"=excluded."notes","payment_terms"=excluded."payment_terms","document_id"=excluded."document_id","base_currency"=excluded."base_currency","exchange_rate"=excluded."exchange_rate","rate_date"=excluded."rate_date","rate_source"=excluded."rate_source","payment_exchange_rate"=excluded."payment_exchange_rate","base_amount"=excluded."base_amount"
      where "invoices".version<=excluded.version;
    when 'InvoiceItems' then
      insert into business."invoice_items" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","invoice_id","line_number","product_id","description","quantity","unit_price","discount","tax_rate","tax_amount","line_total")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'invoiceId',''),
        private.structured_number(r.payload->>'lineNumber'),
        nullif(r.payload->>'productId',''),
        r.payload->>'description',
        private.structured_number(r.payload->>'quantity'),
        private.structured_number(r.payload->>'unitPrice'),
        private.structured_number(r.payload->>'discount'),
        private.structured_number(r.payload->>'taxRate'),
        private.structured_number(r.payload->>'taxAmount'),
        private.structured_number(r.payload->>'lineTotal')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","invoice_id"=excluded."invoice_id","line_number"=excluded."line_number","product_id"=excluded."product_id","description"=excluded."description","quantity"=excluded."quantity","unit_price"=excluded."unit_price","discount"=excluded."discount","tax_rate"=excluded."tax_rate","tax_amount"=excluded."tax_amount","line_total"=excluded."line_total"
      where "invoice_items".version<=excluded.version;
    when 'Receipts' then
      insert into business."receipts" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","number","customer_id","payment_date","amount","currency","payment_account","reference","status","reversal_date","reversal_reason","document_id","base_currency","exchange_rate","rate_date","rate_source","payment_exchange_rate","base_amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'number',
        nullif(r.payload->>'customerId',''),
        nullif(r.payload->>'paymentDate','')::date,
        private.structured_number(r.payload->>'amount'),
        r.payload->>'currency',
        r.payload->>'paymentAccount',
        r.payload->>'reference',
        r.payload->>'status',
        nullif(r.payload->>'reversalDate','')::date,
        r.payload->>'reversalReason',
        r.payload->>'documentId',
        r.payload->>'baseCurrency',
        private.structured_number(r.payload->>'exchangeRate'),
        nullif(r.payload->>'rateDate','')::date,
        r.payload->>'rateSource',
        private.structured_number(r.payload->>'paymentExchangeRate'),
        private.structured_number(r.payload->>'baseAmount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","number"=excluded."number","customer_id"=excluded."customer_id","payment_date"=excluded."payment_date","amount"=excluded."amount","currency"=excluded."currency","payment_account"=excluded."payment_account","reference"=excluded."reference","status"=excluded."status","reversal_date"=excluded."reversal_date","reversal_reason"=excluded."reversal_reason","document_id"=excluded."document_id","base_currency"=excluded."base_currency","exchange_rate"=excluded."exchange_rate","rate_date"=excluded."rate_date","rate_source"=excluded."rate_source","payment_exchange_rate"=excluded."payment_exchange_rate","base_amount"=excluded."base_amount"
      where "receipts".version<=excluded.version;
    when 'ReceiptAllocations' then
      insert into business."receipt_allocations" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","receipt_id","invoice_id","amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'receiptId',''),
        nullif(r.payload->>'invoiceId',''),
        private.structured_number(r.payload->>'amount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","receipt_id"=excluded."receipt_id","invoice_id"=excluded."invoice_id","amount"=excluded."amount"
      where "receipt_allocations".version<=excluded.version;
    when 'Quotations' then
      insert into business."quotations" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","number","customer_id","issue_date","valid_until","status","currency","subtotal","discount","tax_amount","total","notes","payment_terms","converted_invoice_id","document_id","base_currency","exchange_rate","rate_date","rate_source","payment_exchange_rate","base_amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'number',
        nullif(r.payload->>'customerId',''),
        nullif(r.payload->>'issueDate','')::date,
        nullif(r.payload->>'validUntil','')::date,
        r.payload->>'status',
        r.payload->>'currency',
        private.structured_number(r.payload->>'subtotal'),
        private.structured_number(r.payload->>'discount'),
        private.structured_number(r.payload->>'taxAmount'),
        private.structured_number(r.payload->>'total'),
        r.payload->>'notes',
        r.payload->>'paymentTerms',
        r.payload->>'convertedInvoiceId',
        r.payload->>'documentId',
        r.payload->>'baseCurrency',
        private.structured_number(r.payload->>'exchangeRate'),
        nullif(r.payload->>'rateDate','')::date,
        r.payload->>'rateSource',
        private.structured_number(r.payload->>'paymentExchangeRate'),
        private.structured_number(r.payload->>'baseAmount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","number"=excluded."number","customer_id"=excluded."customer_id","issue_date"=excluded."issue_date","valid_until"=excluded."valid_until","status"=excluded."status","currency"=excluded."currency","subtotal"=excluded."subtotal","discount"=excluded."discount","tax_amount"=excluded."tax_amount","total"=excluded."total","notes"=excluded."notes","payment_terms"=excluded."payment_terms","converted_invoice_id"=excluded."converted_invoice_id","document_id"=excluded."document_id","base_currency"=excluded."base_currency","exchange_rate"=excluded."exchange_rate","rate_date"=excluded."rate_date","rate_source"=excluded."rate_source","payment_exchange_rate"=excluded."payment_exchange_rate","base_amount"=excluded."base_amount"
      where "quotations".version<=excluded.version;
    when 'QuotationItems' then
      insert into business."quotation_items" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","quotation_id","line_number","product_id","description","quantity","unit_price","discount","tax_rate","tax_amount","line_total")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'quotationId',''),
        private.structured_number(r.payload->>'lineNumber'),
        nullif(r.payload->>'productId',''),
        r.payload->>'description',
        private.structured_number(r.payload->>'quantity'),
        private.structured_number(r.payload->>'unitPrice'),
        private.structured_number(r.payload->>'discount'),
        private.structured_number(r.payload->>'taxRate'),
        private.structured_number(r.payload->>'taxAmount'),
        private.structured_number(r.payload->>'lineTotal')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","quotation_id"=excluded."quotation_id","line_number"=excluded."line_number","product_id"=excluded."product_id","description"=excluded."description","quantity"=excluded."quantity","unit_price"=excluded."unit_price","discount"=excluded."discount","tax_rate"=excluded."tax_rate","tax_amount"=excluded."tax_amount","line_total"=excluded."line_total"
      where "quotation_items".version<=excluded.version;
    when 'Income' then
      insert into business."income" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","date","category","description","amount","tax_rate","tax_amount","total","payment_status","paid_date","due_date","account","reference","currency","base_currency","exchange_rate","rate_date","rate_source","payment_exchange_rate","base_amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'date','')::date,
        r.payload->>'category',
        r.payload->>'description',
        private.structured_number(r.payload->>'amount'),
        private.structured_number(r.payload->>'taxRate'),
        private.structured_number(r.payload->>'taxAmount'),
        private.structured_number(r.payload->>'total'),
        r.payload->>'paymentStatus',
        nullif(r.payload->>'paidDate','')::date,
        nullif(r.payload->>'dueDate','')::date,
        r.payload->>'account',
        r.payload->>'reference',
        r.payload->>'currency',
        r.payload->>'baseCurrency',
        private.structured_number(r.payload->>'exchangeRate'),
        nullif(r.payload->>'rateDate','')::date,
        r.payload->>'rateSource',
        private.structured_number(r.payload->>'paymentExchangeRate'),
        private.structured_number(r.payload->>'baseAmount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","date"=excluded."date","category"=excluded."category","description"=excluded."description","amount"=excluded."amount","tax_rate"=excluded."tax_rate","tax_amount"=excluded."tax_amount","total"=excluded."total","payment_status"=excluded."payment_status","paid_date"=excluded."paid_date","due_date"=excluded."due_date","account"=excluded."account","reference"=excluded."reference","currency"=excluded."currency","base_currency"=excluded."base_currency","exchange_rate"=excluded."exchange_rate","rate_date"=excluded."rate_date","rate_source"=excluded."rate_source","payment_exchange_rate"=excluded."payment_exchange_rate","base_amount"=excluded."base_amount"
      where "income".version<=excluded.version;
    when 'Expenses' then
      insert into business."expenses" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","date","category","description","supplier","amount","tax_rate","tax_amount","total","payment_status","paid_date","due_date","account","reference","currency","base_currency","exchange_rate","rate_date","rate_source","payment_exchange_rate","base_amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'date','')::date,
        r.payload->>'category',
        r.payload->>'description',
        r.payload->>'supplier',
        private.structured_number(r.payload->>'amount'),
        private.structured_number(r.payload->>'taxRate'),
        private.structured_number(r.payload->>'taxAmount'),
        private.structured_number(r.payload->>'total'),
        r.payload->>'paymentStatus',
        nullif(r.payload->>'paidDate','')::date,
        nullif(r.payload->>'dueDate','')::date,
        r.payload->>'account',
        r.payload->>'reference',
        r.payload->>'currency',
        r.payload->>'baseCurrency',
        private.structured_number(r.payload->>'exchangeRate'),
        nullif(r.payload->>'rateDate','')::date,
        r.payload->>'rateSource',
        private.structured_number(r.payload->>'paymentExchangeRate'),
        private.structured_number(r.payload->>'baseAmount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","date"=excluded."date","category"=excluded."category","description"=excluded."description","supplier"=excluded."supplier","amount"=excluded."amount","tax_rate"=excluded."tax_rate","tax_amount"=excluded."tax_amount","total"=excluded."total","payment_status"=excluded."payment_status","paid_date"=excluded."paid_date","due_date"=excluded."due_date","account"=excluded."account","reference"=excluded."reference","currency"=excluded."currency","base_currency"=excluded."base_currency","exchange_rate"=excluded."exchange_rate","rate_date"=excluded."rate_date","rate_source"=excluded."rate_source","payment_exchange_rate"=excluded."payment_exchange_rate","base_amount"=excluded."base_amount"
      where "expenses".version<=excluded.version;
    when 'ExpenseAttachments' then
      insert into business."expense_attachments" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","expense_id","document_id")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'expenseId',
        r.payload->>'documentId'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","expense_id"=excluded."expense_id","document_id"=excluded."document_id"
      where "expense_attachments".version<=excluded.version;
    when 'Attendance' then
      insert into business."attendance" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","employee_id","date","status","hours","notes")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'employeeId',''),
        nullif(r.payload->>'date','')::date,
        r.payload->>'status',
        private.structured_number(r.payload->>'hours'),
        r.payload->>'notes'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","employee_id"=excluded."employee_id","date"=excluded."date","status"=excluded."status","hours"=excluded."hours","notes"=excluded."notes"
      where "attendance".version<=excluded.version;
    when 'Overtime' then
      insert into business."overtime" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","employee_id","date","hours","rate","approval_status","approved_by")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'employeeId',''),
        nullif(r.payload->>'date','')::date,
        private.structured_number(r.payload->>'hours'),
        private.structured_number(r.payload->>'rate'),
        r.payload->>'approvalStatus',
        r.payload->>'approvedBy'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","employee_id"=excluded."employee_id","date"=excluded."date","hours"=excluded."hours","rate"=excluded."rate","approval_status"=excluded."approval_status","approved_by"=excluded."approved_by"
      where "overtime".version<=excluded.version;
    when 'Payroll' then
      insert into business."payroll" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","month","employee_id","status","basic_salary","allowances","overtime_amount","bonus","deductions","notes","bonus_notes","deduction_notes","gross_salary","net_salary","paid_date","payment_account","payment_reference","reversal_date","reversal_reason","currency","base_currency","exchange_rate","rate_date","rate_source","payment_exchange_rate","base_amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'month',
        nullif(r.payload->>'employeeId',''),
        r.payload->>'status',
        private.structured_number(r.payload->>'basicSalary'),
        private.structured_number(r.payload->>'allowances'),
        private.structured_number(r.payload->>'overtimeAmount'),
        private.structured_number(r.payload->>'bonus'),
        private.structured_number(r.payload->>'deductions'),
        r.payload->>'notes',
        r.payload->>'bonusNotes',
        r.payload->>'deductionNotes',
        private.structured_number(r.payload->>'grossSalary'),
        private.structured_number(r.payload->>'netSalary'),
        nullif(r.payload->>'paidDate','')::date,
        r.payload->>'paymentAccount',
        r.payload->>'paymentReference',
        nullif(r.payload->>'reversalDate','')::date,
        r.payload->>'reversalReason',
        r.payload->>'currency',
        r.payload->>'baseCurrency',
        private.structured_number(r.payload->>'exchangeRate'),
        nullif(r.payload->>'rateDate','')::date,
        r.payload->>'rateSource',
        private.structured_number(r.payload->>'paymentExchangeRate'),
        private.structured_number(r.payload->>'baseAmount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","month"=excluded."month","employee_id"=excluded."employee_id","status"=excluded."status","basic_salary"=excluded."basic_salary","allowances"=excluded."allowances","overtime_amount"=excluded."overtime_amount","bonus"=excluded."bonus","deductions"=excluded."deductions","notes"=excluded."notes","bonus_notes"=excluded."bonus_notes","deduction_notes"=excluded."deduction_notes","gross_salary"=excluded."gross_salary","net_salary"=excluded."net_salary","paid_date"=excluded."paid_date","payment_account"=excluded."payment_account","payment_reference"=excluded."payment_reference","reversal_date"=excluded."reversal_date","reversal_reason"=excluded."reversal_reason","currency"=excluded."currency","base_currency"=excluded."base_currency","exchange_rate"=excluded."exchange_rate","rate_date"=excluded."rate_date","rate_source"=excluded."rate_source","payment_exchange_rate"=excluded."payment_exchange_rate","base_amount"=excluded."base_amount"
      where "payroll".version<=excluded.version;
    when 'PayrollItems' then
      insert into business."payroll_items" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","payroll_id","kind","description","quantity","rate","amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'payrollId',''),
        r.payload->>'kind',
        r.payload->>'description',
        private.structured_number(r.payload->>'quantity'),
        private.structured_number(r.payload->>'rate'),
        private.structured_number(r.payload->>'amount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","payroll_id"=excluded."payroll_id","kind"=excluded."kind","description"=excluded."description","quantity"=excluded."quantity","rate"=excluded."rate","amount"=excluded."amount"
      where "payroll_items".version<=excluded.version;
    when 'Payslips' then
      insert into business."payslips" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","payroll_id","employee_id","document_id","issued_at")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'payrollId',''),
        nullif(r.payload->>'employeeId',''),
        r.payload->>'documentId',
        r.payload->>'issuedAt'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","payroll_id"=excluded."payroll_id","employee_id"=excluded."employee_id","document_id"=excluded."document_id","issued_at"=excluded."issued_at"
      where "payslips".version<=excluded.version;
    when 'Assets' then
      insert into business."assets" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","asset_code","name","category","purchase_date","cost","useful_life","residual_value","depreciation_method","payment_account","accumulated_depreciation","net_book_value","last_depreciation_date","disposal_date","disposal_proceeds","disposal_account","disposal_reason","status","location","assigned_employee_id","serial_number","acquisition_type","acquisition_journal_id")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'assetCode',
        r.payload->>'name',
        r.payload->>'category',
        nullif(r.payload->>'purchaseDate','')::date,
        private.structured_number(r.payload->>'cost'),
        private.structured_number(r.payload->>'usefulLife'),
        private.structured_number(r.payload->>'residualValue'),
        r.payload->>'depreciationMethod',
        r.payload->>'paymentAccount',
        private.structured_number(r.payload->>'accumulatedDepreciation'),
        private.structured_number(r.payload->>'netBookValue'),
        nullif(r.payload->>'lastDepreciationDate','')::date,
        nullif(r.payload->>'disposalDate','')::date,
        private.structured_number(r.payload->>'disposalProceeds'),
        r.payload->>'disposalAccount',
        r.payload->>'disposalReason',
        r.payload->>'status',
        r.payload->>'location',
        nullif(r.payload->>'assignedEmployeeId',''),
        r.payload->>'serialNumber',
        r.payload->>'acquisitionType',
        r.payload->>'acquisitionJournalId'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","asset_code"=excluded."asset_code","name"=excluded."name","category"=excluded."category","purchase_date"=excluded."purchase_date","cost"=excluded."cost","useful_life"=excluded."useful_life","residual_value"=excluded."residual_value","depreciation_method"=excluded."depreciation_method","payment_account"=excluded."payment_account","accumulated_depreciation"=excluded."accumulated_depreciation","net_book_value"=excluded."net_book_value","last_depreciation_date"=excluded."last_depreciation_date","disposal_date"=excluded."disposal_date","disposal_proceeds"=excluded."disposal_proceeds","disposal_account"=excluded."disposal_account","disposal_reason"=excluded."disposal_reason","status"=excluded."status","location"=excluded."location","assigned_employee_id"=excluded."assigned_employee_id","serial_number"=excluded."serial_number","acquisition_type"=excluded."acquisition_type","acquisition_journal_id"=excluded."acquisition_journal_id"
      where "assets".version<=excluded.version;
    when 'CapitalAccounts' then
      insert into business."capital_accounts" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","name","kind","shareholder_id","currency","status")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'name',
        r.payload->>'kind',
        nullif(r.payload->>'shareholderId',''),
        r.payload->>'currency',
        r.payload->>'status'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","name"=excluded."name","kind"=excluded."kind","shareholder_id"=excluded."shareholder_id","currency"=excluded."currency","status"=excluded."status"
      where "capital_accounts".version<=excluded.version;
    when 'CapitalTransactions' then
      insert into business."capital_transactions" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","date","capital_account_id","shareholder_id","kind","amount","method","destination_account","asset_id","status","reference")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'date','')::date,
        nullif(r.payload->>'capitalAccountId',''),
        nullif(r.payload->>'shareholderId',''),
        r.payload->>'kind',
        private.structured_number(r.payload->>'amount'),
        r.payload->>'method',
        r.payload->>'destinationAccount',
        r.payload->>'assetId',
        r.payload->>'status',
        r.payload->>'reference'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","date"=excluded."date","capital_account_id"=excluded."capital_account_id","shareholder_id"=excluded."shareholder_id","kind"=excluded."kind","amount"=excluded."amount","method"=excluded."method","destination_account"=excluded."destination_account","asset_id"=excluded."asset_id","status"=excluded."status","reference"=excluded."reference"
      where "capital_transactions".version<=excluded.version;
    when 'Shareholders' then
      insert into business."shareholders" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","name","email","phone","role","status","agreed_capital","investment_date","ownership_percentage")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'name',
        r.payload->>'email',
        r.payload->>'phone',
        r.payload->>'role',
        r.payload->>'status',
        private.structured_number(r.payload->>'agreedCapital'),
        nullif(r.payload->>'investmentDate','')::date,
        private.structured_number(r.payload->>'ownershipPercentage')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","name"=excluded."name","email"=excluded."email","phone"=excluded."phone","role"=excluded."role","status"=excluded."status","agreed_capital"=excluded."agreed_capital","investment_date"=excluded."investment_date","ownership_percentage"=excluded."ownership_percentage"
      where "shareholders".version<=excluded.version;
    when 'ShareholderEquity' then
      insert into business."shareholder_equity" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","shareholder_id","effective_date","percentage","amount")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'shareholderId',''),
        nullif(r.payload->>'effectiveDate','')::date,
        private.structured_number(r.payload->>'percentage'),
        private.structured_number(r.payload->>'amount')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","shareholder_id"=excluded."shareholder_id","effective_date"=excluded."effective_date","percentage"=excluded."percentage","amount"=excluded."amount"
      where "shareholder_equity".version<=excluded.version;
    when 'ShareholderLoans' then
      insert into business."shareholder_loans" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","shareholder_id","date","kind","principal","interest_rate","repaid_amount","outstanding_balance","due_date","payment_account","last_repayment_date","payment_reference","status","reference")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'shareholderId',''),
        nullif(r.payload->>'date','')::date,
        r.payload->>'kind',
        private.structured_number(r.payload->>'principal'),
        private.structured_number(r.payload->>'interestRate'),
        private.structured_number(r.payload->>'repaidAmount'),
        private.structured_number(r.payload->>'outstandingBalance'),
        nullif(r.payload->>'dueDate','')::date,
        r.payload->>'paymentAccount',
        nullif(r.payload->>'lastRepaymentDate','')::date,
        r.payload->>'paymentReference',
        r.payload->>'status',
        r.payload->>'reference'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","shareholder_id"=excluded."shareholder_id","date"=excluded."date","kind"=excluded."kind","principal"=excluded."principal","interest_rate"=excluded."interest_rate","repaid_amount"=excluded."repaid_amount","outstanding_balance"=excluded."outstanding_balance","due_date"=excluded."due_date","payment_account"=excluded."payment_account","last_repayment_date"=excluded."last_repayment_date","payment_reference"=excluded."payment_reference","status"=excluded."status","reference"=excluded."reference"
      where "shareholder_loans".version<=excluded.version;
    when 'FinancialPeriods' then
      insert into business."financial_periods" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","name","start_date","end_date","status","closed_by","closed_at")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'name',
        nullif(r.payload->>'startDate','')::date,
        r.payload->>'endDate',
        r.payload->>'status',
        r.payload->>'closedBy',
        r.payload->>'closedAt'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","name"=excluded."name","start_date"=excluded."start_date","end_date"=excluded."end_date","status"=excluded."status","closed_by"=excluded."closed_by","closed_at"=excluded."closed_at"
      where "financial_periods".version<=excluded.version;
    when 'Journals' then
      insert into business."journals" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","number","date","description","source_type","source_id","total_debit","total_credit","status")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'number',
        nullif(r.payload->>'date','')::date,
        r.payload->>'description',
        r.payload->>'sourceType',
        r.payload->>'sourceId',
        private.structured_number(r.payload->>'totalDebit'),
        private.structured_number(r.payload->>'totalCredit'),
        r.payload->>'status'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","number"=excluded."number","date"=excluded."date","description"=excluded."description","source_type"=excluded."source_type","source_id"=excluded."source_id","total_debit"=excluded."total_debit","total_credit"=excluded."total_credit","status"=excluded."status"
      where "journals".version<=excluded.version;
    when 'JournalLines' then
      insert into business."journal_lines" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","journal_id","line_number","account_id","account_name","account_group","debit","credit")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'journalId',''),
        private.structured_number(r.payload->>'lineNumber'),
        r.payload->>'accountId',
        r.payload->>'accountName',
        r.payload->>'accountGroup',
        private.structured_number(r.payload->>'debit'),
        private.structured_number(r.payload->>'credit')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","journal_id"=excluded."journal_id","line_number"=excluded."line_number","account_id"=excluded."account_id","account_name"=excluded."account_name","account_group"=excluded."account_group","debit"=excluded."debit","credit"=excluded."credit"
      where "journal_lines".version<=excluded.version;
    when 'DocumentRegistry' then
      insert into business."document_registry" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","kind","name","mime_type","byte_length","related_section","related_record_id","status")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'kind',
        r.payload->>'name',
        r.payload->>'mimeType',
        private.structured_number(r.payload->>'byteLength'),
        r.payload->>'relatedSection',
        r.payload->>'relatedRecordId',
        r.payload->>'status'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","kind"=excluded."kind","name"=excluded."name","mime_type"=excluded."mime_type","byte_length"=excluded."byte_length","related_section"=excluded."related_section","related_record_id"=excluded."related_record_id","status"=excluded."status"
      where "document_registry".version<=excluded.version;
    when 'NumberSequences' then
      insert into business."number_sequences" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","kind","prefix","period","next_number")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'kind',
        r.payload->>'prefix',
        r.payload->>'period',
        private.structured_number(r.payload->>'nextNumber')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","kind"=excluded."kind","prefix"=excluded."prefix","period"=excluded."period","next_number"=excluded."next_number"
      where "number_sequences".version<=excluded.version;
    when 'CreditNotes' then
      insert into business."credit_notes" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","number","invoice_id","customer_id","date","reason","currency","subtotal","discount","tax_amount","total","refund_amount","refund_account","status")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'number',
        nullif(r.payload->>'invoiceId',''),
        nullif(r.payload->>'customerId',''),
        nullif(r.payload->>'date','')::date,
        r.payload->>'reason',
        r.payload->>'currency',
        private.structured_number(r.payload->>'subtotal'),
        private.structured_number(r.payload->>'discount'),
        private.structured_number(r.payload->>'taxAmount'),
        private.structured_number(r.payload->>'total'),
        private.structured_number(r.payload->>'refundAmount'),
        r.payload->>'refundAccount',
        r.payload->>'status'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","number"=excluded."number","invoice_id"=excluded."invoice_id","customer_id"=excluded."customer_id","date"=excluded."date","reason"=excluded."reason","currency"=excluded."currency","subtotal"=excluded."subtotal","discount"=excluded."discount","tax_amount"=excluded."tax_amount","total"=excluded."total","refund_amount"=excluded."refund_amount","refund_account"=excluded."refund_account","status"=excluded."status"
      where "credit_notes".version<=excluded.version;
    when 'CreditNoteItems' then
      insert into business."credit_note_items" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","credit_note_id","invoice_id","invoice_item_id","line_number","description","quantity","unit_price","discount","tax_rate","tax_amount","line_total","subtotal")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'creditNoteId',''),
        nullif(r.payload->>'invoiceId',''),
        nullif(r.payload->>'invoiceItemId',''),
        private.structured_number(r.payload->>'lineNumber'),
        r.payload->>'description',
        private.structured_number(r.payload->>'quantity'),
        private.structured_number(r.payload->>'unitPrice'),
        private.structured_number(r.payload->>'discount'),
        private.structured_number(r.payload->>'taxRate'),
        private.structured_number(r.payload->>'taxAmount'),
        private.structured_number(r.payload->>'lineTotal'),
        private.structured_number(r.payload->>'subtotal')
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","credit_note_id"=excluded."credit_note_id","invoice_id"=excluded."invoice_id","invoice_item_id"=excluded."invoice_item_id","line_number"=excluded."line_number","description"=excluded."description","quantity"=excluded."quantity","unit_price"=excluded."unit_price","discount"=excluded."discount","tax_rate"=excluded."tax_rate","tax_amount"=excluded."tax_amount","line_total"=excluded."line_total","subtotal"=excluded."subtotal"
      where "credit_note_items".version<=excluded.version;
    when 'Tasks' then
      insert into business."tasks" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","title","description","employee_id","assignee_name","priority","status","start_date","due_date","start_time","end_time","project","tags","reminder")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'title',
        r.payload->>'description',
        nullif(r.payload->>'employeeId',''),
        r.payload->>'assigneeName',
        r.payload->>'priority',
        r.payload->>'status',
        nullif(r.payload->>'startDate','')::date,
        nullif(r.payload->>'dueDate','')::date,
        r.payload->>'startTime',
        r.payload->>'endTime',
        r.payload->>'project',
        r.payload->>'tags',
        r.payload->>'reminder'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","title"=excluded."title","description"=excluded."description","employee_id"=excluded."employee_id","assignee_name"=excluded."assignee_name","priority"=excluded."priority","status"=excluded."status","start_date"=excluded."start_date","due_date"=excluded."due_date","start_time"=excluded."start_time","end_time"=excluded."end_time","project"=excluded."project","tags"=excluded."tags","reminder"=excluded."reminder"
      where "tasks".version<=excluded.version;
    when 'TaskComments' then
      insert into business."task_comments" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","task_id","body")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'taskId',''),
        r.payload->>'body'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","task_id"=excluded."task_id","body"=excluded."body"
      where "task_comments".version<=excluded.version;
    when 'TaskActivity' then
      insert into business."task_activity" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","task_id","action","summary","author_name")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'taskId',''),
        r.payload->>'action',
        r.payload->>'summary',
        r.payload->>'authorName'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","task_id"=excluded."task_id","action"=excluded."action","summary"=excluded."summary","author_name"=excluded."author_name"
      where "task_activity".version<=excluded.version;
    when 'Projects' then
      insert into business."projects" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","name","description","status")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'name',
        r.payload->>'description',
        r.payload->>'status'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","name"=excluded."name","description"=excluded."description","status"=excluded."status"
      where "projects".version<=excluded.version;
    when 'MoneyTransfers' then
      insert into business."money_transfers" ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","date","from_account","to_account","amount","description","reference","status","bank_status","statement_date","statement_reference","reversal_date","reversal_reason")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        nullif(r.payload->>'date','')::date,
        r.payload->>'fromAccount',
        r.payload->>'toAccount',
        private.structured_number(r.payload->>'amount'),
        r.payload->>'description',
        r.payload->>'reference',
        r.payload->>'status',
        r.payload->>'bankStatus',
        nullif(r.payload->>'statementDate','')::date,
        r.payload->>'statementReference',
        nullif(r.payload->>'reversalDate','')::date,
        r.payload->>'reversalReason'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","date"=excluded."date","from_account"=excluded."from_account","to_account"=excluded."to_account","amount"=excluded."amount","description"=excluded."description","reference"=excluded."reference","status"=excluded."status","bank_status"=excluded."bank_status","statement_date"=excluded."statement_date","statement_reference"=excluded."statement_reference","reversal_date"=excluded."reversal_date","reversal_reason"=excluded."reversal_reason"
      where "money_transfers".version<=excluded.version;
    when 'CompanyLoans' then
      insert into business.company_loans ("company_id","record_id","ordinal","version","deleted","updated_at","created_at_ms","created_by","updated_by","lender_name","lender_type","date","principal","interest_rate","installment_amount","due_date","payment_account","reference","notes","repaid_amount","interest_paid","outstanding_balance","last_repayment_date","principal_payment","interest_payment","payment_reference","status")
      select r.company_id,r.record_id,r.ordinal,r.version,r.deleted,r.updated_at,
        private.structured_number(r.payload->>'createdAt'),r.payload->>'createdBy',r.payload->>'updatedBy',
        r.payload->>'lenderName',
        r.payload->>'lenderType',
        nullif(r.payload->>'date','')::date,
        private.structured_number(r.payload->>'principal'),
        private.structured_number(r.payload->>'interestRate'),
        private.structured_number(r.payload->>'installmentAmount'),
        nullif(r.payload->>'dueDate','')::date,
        r.payload->>'paymentAccount',
        r.payload->>'reference',
        r.payload->>'notes',
        private.structured_number(r.payload->>'repaidAmount'),
        private.structured_number(r.payload->>'interestPaid'),
        private.structured_number(r.payload->>'outstandingBalance'),
        nullif(r.payload->>'lastRepaymentDate','')::date,
        private.structured_number(r.payload->>'principalPayment'),
        private.structured_number(r.payload->>'interestPayment'),
        r.payload->>'paymentReference',
        r.payload->>'status'
      from public.business_records r where r.company_id=p_company and r.section=p_section and r.record_id=p_id
      on conflict(company_id,record_id) do update set
        "ordinal"=excluded."ordinal","version"=excluded."version","deleted"=excluded."deleted","updated_at"=excluded."updated_at","created_at_ms"=excluded."created_at_ms","created_by"=excluded."created_by","updated_by"=excluded."updated_by","lender_name"=excluded."lender_name","lender_type"=excluded."lender_type","date"=excluded."date","principal"=excluded."principal","interest_rate"=excluded."interest_rate","installment_amount"=excluded."installment_amount","due_date"=excluded."due_date","payment_account"=excluded."payment_account","reference"=excluded."reference","notes"=excluded."notes","repaid_amount"=excluded."repaid_amount","interest_paid"=excluded."interest_paid","outstanding_balance"=excluded."outstanding_balance","last_repayment_date"=excluded."last_repayment_date","principal_payment"=excluded."principal_payment","interest_payment"=excluded."interest_payment","payment_reference"=excluded."payment_reference","status"=excluded."status"
      where company_loans.version<=excluded.version;
    else raise exception 'INVALID_RECORD_SECTION';
  end case;
end $$;

revoke all on function private.project_business_record(text,text,text) from public,anon,authenticated;
