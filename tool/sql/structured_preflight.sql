-- Read-only preflight. Empty result means no detected reference/type anomalies.
select * from (
select 'Employees' as section,'joinDate' as field,count(*)::bigint as issues from public.business_records r where section='Employees' and nullif(payload->>'joinDate','') is not null and (not pg_input_is_valid(payload->>'joinDate','date'))
union all
select 'Employees' as section,'lastEmploymentDate' as field,count(*)::bigint as issues from public.business_records r where section='Employees' and nullif(payload->>'lastEmploymentDate','') is not null and (not pg_input_is_valid(payload->>'lastEmploymentDate','date'))
union all
select 'Employees' as section,'basicSalary' as field,count(*)::bigint as issues from public.business_records r where section='Employees' and nullif(payload->>'basicSalary','') is not null and (length(payload->>'basicSalary')>100 or payload->>'basicSalary' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Employees' as section,'allowances' as field,count(*)::bigint as issues from public.business_records r where section='Employees' and nullif(payload->>'allowances','') is not null and (length(payload->>'allowances')>100 or payload->>'allowances' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Employees' as section,'visaExpiry' as field,count(*)::bigint as issues from public.business_records r where section='Employees' and nullif(payload->>'visaExpiry','') is not null and (not pg_input_is_valid(payload->>'visaExpiry','date'))
union all
select 'ProductsServices' as section,'unitPrice' as field,count(*)::bigint as issues from public.business_records r where section='ProductsServices' and nullif(payload->>'unitPrice','') is not null and (length(payload->>'unitPrice')>100 or payload->>'unitPrice' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ProductsServices' as section,'taxRate' as field,count(*)::bigint as issues from public.business_records r where section='ProductsServices' and nullif(payload->>'taxRate','') is not null and (length(payload->>'taxRate')>100 or payload->>'taxRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'customerId' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'customerId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Customers' and parent.record_id=r.payload->>'customerId'))
union all
select 'Invoices' as section,'issueDate' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'issueDate','') is not null and (not pg_input_is_valid(payload->>'issueDate','date'))
union all
select 'Invoices' as section,'dueDate' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'dueDate','') is not null and (not pg_input_is_valid(payload->>'dueDate','date'))
union all
select 'Invoices' as section,'subtotal' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'subtotal','') is not null and (length(payload->>'subtotal')>100 or payload->>'subtotal' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'discount' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'discount','') is not null and (length(payload->>'discount')>100 or payload->>'discount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'taxAmount' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'taxAmount','') is not null and (length(payload->>'taxAmount')>100 or payload->>'taxAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'total' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'total','') is not null and (length(payload->>'total')>100 or payload->>'total' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'paidAmount' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'paidAmount','') is not null and (length(payload->>'paidAmount')>100 or payload->>'paidAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'balance' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'balance','') is not null and (length(payload->>'balance')>100 or payload->>'balance' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'voidDate' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'voidDate','') is not null and (not pg_input_is_valid(payload->>'voidDate','date'))
union all
select 'Invoices' as section,'exchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'exchangeRate','') is not null and (length(payload->>'exchangeRate')>100 or payload->>'exchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'rateDate' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'rateDate','') is not null and (not pg_input_is_valid(payload->>'rateDate','date'))
union all
select 'Invoices' as section,'paymentExchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'paymentExchangeRate','') is not null and (length(payload->>'paymentExchangeRate')>100 or payload->>'paymentExchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Invoices' as section,'baseAmount' as field,count(*)::bigint as issues from public.business_records r where section='Invoices' and nullif(payload->>'baseAmount','') is not null and (length(payload->>'baseAmount')>100 or payload->>'baseAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'InvoiceItems' as section,'invoiceId' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'invoiceId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Invoices' and parent.record_id=r.payload->>'invoiceId'))
union all
select 'InvoiceItems' as section,'lineNumber' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'lineNumber','') is not null and (length(payload->>'lineNumber')>100 or payload->>'lineNumber' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'InvoiceItems' as section,'productId' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'productId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='ProductsServices' and parent.record_id=r.payload->>'productId'))
union all
select 'InvoiceItems' as section,'quantity' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'quantity','') is not null and (length(payload->>'quantity')>100 or payload->>'quantity' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'InvoiceItems' as section,'unitPrice' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'unitPrice','') is not null and (length(payload->>'unitPrice')>100 or payload->>'unitPrice' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'InvoiceItems' as section,'discount' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'discount','') is not null and (length(payload->>'discount')>100 or payload->>'discount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'InvoiceItems' as section,'taxRate' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'taxRate','') is not null and (length(payload->>'taxRate')>100 or payload->>'taxRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'InvoiceItems' as section,'taxAmount' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'taxAmount','') is not null and (length(payload->>'taxAmount')>100 or payload->>'taxAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'InvoiceItems' as section,'lineTotal' as field,count(*)::bigint as issues from public.business_records r where section='InvoiceItems' and nullif(payload->>'lineTotal','') is not null and (length(payload->>'lineTotal')>100 or payload->>'lineTotal' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Receipts' as section,'customerId' as field,count(*)::bigint as issues from public.business_records r where section='Receipts' and nullif(payload->>'customerId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Customers' and parent.record_id=r.payload->>'customerId'))
union all
select 'Receipts' as section,'paymentDate' as field,count(*)::bigint as issues from public.business_records r where section='Receipts' and nullif(payload->>'paymentDate','') is not null and (not pg_input_is_valid(payload->>'paymentDate','date'))
union all
select 'Receipts' as section,'amount' as field,count(*)::bigint as issues from public.business_records r where section='Receipts' and nullif(payload->>'amount','') is not null and (length(payload->>'amount')>100 or payload->>'amount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Receipts' as section,'reversalDate' as field,count(*)::bigint as issues from public.business_records r where section='Receipts' and nullif(payload->>'reversalDate','') is not null and (not pg_input_is_valid(payload->>'reversalDate','date'))
union all
select 'Receipts' as section,'exchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Receipts' and nullif(payload->>'exchangeRate','') is not null and (length(payload->>'exchangeRate')>100 or payload->>'exchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Receipts' as section,'rateDate' as field,count(*)::bigint as issues from public.business_records r where section='Receipts' and nullif(payload->>'rateDate','') is not null and (not pg_input_is_valid(payload->>'rateDate','date'))
union all
select 'Receipts' as section,'paymentExchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Receipts' and nullif(payload->>'paymentExchangeRate','') is not null and (length(payload->>'paymentExchangeRate')>100 or payload->>'paymentExchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Receipts' as section,'baseAmount' as field,count(*)::bigint as issues from public.business_records r where section='Receipts' and nullif(payload->>'baseAmount','') is not null and (length(payload->>'baseAmount')>100 or payload->>'baseAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ReceiptAllocations' as section,'receiptId' as field,count(*)::bigint as issues from public.business_records r where section='ReceiptAllocations' and nullif(payload->>'receiptId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Receipts' and parent.record_id=r.payload->>'receiptId'))
union all
select 'ReceiptAllocations' as section,'invoiceId' as field,count(*)::bigint as issues from public.business_records r where section='ReceiptAllocations' and nullif(payload->>'invoiceId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Invoices' and parent.record_id=r.payload->>'invoiceId'))
union all
select 'ReceiptAllocations' as section,'amount' as field,count(*)::bigint as issues from public.business_records r where section='ReceiptAllocations' and nullif(payload->>'amount','') is not null and (length(payload->>'amount')>100 or payload->>'amount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Quotations' as section,'customerId' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'customerId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Customers' and parent.record_id=r.payload->>'customerId'))
union all
select 'Quotations' as section,'issueDate' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'issueDate','') is not null and (not pg_input_is_valid(payload->>'issueDate','date'))
union all
select 'Quotations' as section,'validUntil' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'validUntil','') is not null and (not pg_input_is_valid(payload->>'validUntil','date'))
union all
select 'Quotations' as section,'subtotal' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'subtotal','') is not null and (length(payload->>'subtotal')>100 or payload->>'subtotal' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Quotations' as section,'discount' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'discount','') is not null and (length(payload->>'discount')>100 or payload->>'discount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Quotations' as section,'taxAmount' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'taxAmount','') is not null and (length(payload->>'taxAmount')>100 or payload->>'taxAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Quotations' as section,'total' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'total','') is not null and (length(payload->>'total')>100 or payload->>'total' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Quotations' as section,'exchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'exchangeRate','') is not null and (length(payload->>'exchangeRate')>100 or payload->>'exchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Quotations' as section,'rateDate' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'rateDate','') is not null and (not pg_input_is_valid(payload->>'rateDate','date'))
union all
select 'Quotations' as section,'paymentExchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'paymentExchangeRate','') is not null and (length(payload->>'paymentExchangeRate')>100 or payload->>'paymentExchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Quotations' as section,'baseAmount' as field,count(*)::bigint as issues from public.business_records r where section='Quotations' and nullif(payload->>'baseAmount','') is not null and (length(payload->>'baseAmount')>100 or payload->>'baseAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'QuotationItems' as section,'quotationId' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'quotationId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Quotations' and parent.record_id=r.payload->>'quotationId'))
union all
select 'QuotationItems' as section,'lineNumber' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'lineNumber','') is not null and (length(payload->>'lineNumber')>100 or payload->>'lineNumber' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'QuotationItems' as section,'productId' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'productId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='ProductsServices' and parent.record_id=r.payload->>'productId'))
union all
select 'QuotationItems' as section,'quantity' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'quantity','') is not null and (length(payload->>'quantity')>100 or payload->>'quantity' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'QuotationItems' as section,'unitPrice' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'unitPrice','') is not null and (length(payload->>'unitPrice')>100 or payload->>'unitPrice' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'QuotationItems' as section,'discount' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'discount','') is not null and (length(payload->>'discount')>100 or payload->>'discount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'QuotationItems' as section,'taxRate' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'taxRate','') is not null and (length(payload->>'taxRate')>100 or payload->>'taxRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'QuotationItems' as section,'taxAmount' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'taxAmount','') is not null and (length(payload->>'taxAmount')>100 or payload->>'taxAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'QuotationItems' as section,'lineTotal' as field,count(*)::bigint as issues from public.business_records r where section='QuotationItems' and nullif(payload->>'lineTotal','') is not null and (length(payload->>'lineTotal')>100 or payload->>'lineTotal' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Income' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'Income' as section,'amount' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'amount','') is not null and (length(payload->>'amount')>100 or payload->>'amount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Income' as section,'taxRate' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'taxRate','') is not null and (length(payload->>'taxRate')>100 or payload->>'taxRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Income' as section,'taxAmount' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'taxAmount','') is not null and (length(payload->>'taxAmount')>100 or payload->>'taxAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Income' as section,'total' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'total','') is not null and (length(payload->>'total')>100 or payload->>'total' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Income' as section,'paidDate' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'paidDate','') is not null and (not pg_input_is_valid(payload->>'paidDate','date'))
union all
select 'Income' as section,'dueDate' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'dueDate','') is not null and (not pg_input_is_valid(payload->>'dueDate','date'))
union all
select 'Income' as section,'exchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'exchangeRate','') is not null and (length(payload->>'exchangeRate')>100 or payload->>'exchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Income' as section,'rateDate' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'rateDate','') is not null and (not pg_input_is_valid(payload->>'rateDate','date'))
union all
select 'Income' as section,'paymentExchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'paymentExchangeRate','') is not null and (length(payload->>'paymentExchangeRate')>100 or payload->>'paymentExchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Income' as section,'baseAmount' as field,count(*)::bigint as issues from public.business_records r where section='Income' and nullif(payload->>'baseAmount','') is not null and (length(payload->>'baseAmount')>100 or payload->>'baseAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Expenses' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'Expenses' as section,'amount' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'amount','') is not null and (length(payload->>'amount')>100 or payload->>'amount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Expenses' as section,'taxRate' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'taxRate','') is not null and (length(payload->>'taxRate')>100 or payload->>'taxRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Expenses' as section,'taxAmount' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'taxAmount','') is not null and (length(payload->>'taxAmount')>100 or payload->>'taxAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Expenses' as section,'total' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'total','') is not null and (length(payload->>'total')>100 or payload->>'total' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Expenses' as section,'paidDate' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'paidDate','') is not null and (not pg_input_is_valid(payload->>'paidDate','date'))
union all
select 'Expenses' as section,'dueDate' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'dueDate','') is not null and (not pg_input_is_valid(payload->>'dueDate','date'))
union all
select 'Expenses' as section,'exchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'exchangeRate','') is not null and (length(payload->>'exchangeRate')>100 or payload->>'exchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Expenses' as section,'rateDate' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'rateDate','') is not null and (not pg_input_is_valid(payload->>'rateDate','date'))
union all
select 'Expenses' as section,'paymentExchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'paymentExchangeRate','') is not null and (length(payload->>'paymentExchangeRate')>100 or payload->>'paymentExchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Expenses' as section,'baseAmount' as field,count(*)::bigint as issues from public.business_records r where section='Expenses' and nullif(payload->>'baseAmount','') is not null and (length(payload->>'baseAmount')>100 or payload->>'baseAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Attendance' as section,'employeeId' as field,count(*)::bigint as issues from public.business_records r where section='Attendance' and nullif(payload->>'employeeId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Employees' and parent.record_id=r.payload->>'employeeId'))
union all
select 'Attendance' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='Attendance' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'Attendance' as section,'hours' as field,count(*)::bigint as issues from public.business_records r where section='Attendance' and nullif(payload->>'hours','') is not null and (length(payload->>'hours')>100 or payload->>'hours' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Overtime' as section,'employeeId' as field,count(*)::bigint as issues from public.business_records r where section='Overtime' and nullif(payload->>'employeeId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Employees' and parent.record_id=r.payload->>'employeeId'))
union all
select 'Overtime' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='Overtime' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'Overtime' as section,'hours' as field,count(*)::bigint as issues from public.business_records r where section='Overtime' and nullif(payload->>'hours','') is not null and (length(payload->>'hours')>100 or payload->>'hours' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Overtime' as section,'rate' as field,count(*)::bigint as issues from public.business_records r where section='Overtime' and nullif(payload->>'rate','') is not null and (length(payload->>'rate')>100 or payload->>'rate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'employeeId' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'employeeId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Employees' and parent.record_id=r.payload->>'employeeId'))
union all
select 'Payroll' as section,'basicSalary' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'basicSalary','') is not null and (length(payload->>'basicSalary')>100 or payload->>'basicSalary' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'allowances' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'allowances','') is not null and (length(payload->>'allowances')>100 or payload->>'allowances' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'overtimeAmount' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'overtimeAmount','') is not null and (length(payload->>'overtimeAmount')>100 or payload->>'overtimeAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'bonus' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'bonus','') is not null and (length(payload->>'bonus')>100 or payload->>'bonus' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'deductions' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'deductions','') is not null and (length(payload->>'deductions')>100 or payload->>'deductions' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'grossSalary' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'grossSalary','') is not null and (length(payload->>'grossSalary')>100 or payload->>'grossSalary' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'netSalary' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'netSalary','') is not null and (length(payload->>'netSalary')>100 or payload->>'netSalary' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'paidDate' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'paidDate','') is not null and (not pg_input_is_valid(payload->>'paidDate','date'))
union all
select 'Payroll' as section,'reversalDate' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'reversalDate','') is not null and (not pg_input_is_valid(payload->>'reversalDate','date'))
union all
select 'Payroll' as section,'exchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'exchangeRate','') is not null and (length(payload->>'exchangeRate')>100 or payload->>'exchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'rateDate' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'rateDate','') is not null and (not pg_input_is_valid(payload->>'rateDate','date'))
union all
select 'Payroll' as section,'paymentExchangeRate' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'paymentExchangeRate','') is not null and (length(payload->>'paymentExchangeRate')>100 or payload->>'paymentExchangeRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payroll' as section,'baseAmount' as field,count(*)::bigint as issues from public.business_records r where section='Payroll' and nullif(payload->>'baseAmount','') is not null and (length(payload->>'baseAmount')>100 or payload->>'baseAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'PayrollItems' as section,'payrollId' as field,count(*)::bigint as issues from public.business_records r where section='PayrollItems' and nullif(payload->>'payrollId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Payroll' and parent.record_id=r.payload->>'payrollId'))
union all
select 'PayrollItems' as section,'quantity' as field,count(*)::bigint as issues from public.business_records r where section='PayrollItems' and nullif(payload->>'quantity','') is not null and (length(payload->>'quantity')>100 or payload->>'quantity' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'PayrollItems' as section,'rate' as field,count(*)::bigint as issues from public.business_records r where section='PayrollItems' and nullif(payload->>'rate','') is not null and (length(payload->>'rate')>100 or payload->>'rate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'PayrollItems' as section,'amount' as field,count(*)::bigint as issues from public.business_records r where section='PayrollItems' and nullif(payload->>'amount','') is not null and (length(payload->>'amount')>100 or payload->>'amount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Payslips' as section,'payrollId' as field,count(*)::bigint as issues from public.business_records r where section='Payslips' and nullif(payload->>'payrollId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Payroll' and parent.record_id=r.payload->>'payrollId'))
union all
select 'Payslips' as section,'employeeId' as field,count(*)::bigint as issues from public.business_records r where section='Payslips' and nullif(payload->>'employeeId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Employees' and parent.record_id=r.payload->>'employeeId'))
union all
select 'Assets' as section,'purchaseDate' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'purchaseDate','') is not null and (not pg_input_is_valid(payload->>'purchaseDate','date'))
union all
select 'Assets' as section,'cost' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'cost','') is not null and (length(payload->>'cost')>100 or payload->>'cost' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Assets' as section,'usefulLife' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'usefulLife','') is not null and (length(payload->>'usefulLife')>100 or payload->>'usefulLife' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Assets' as section,'residualValue' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'residualValue','') is not null and (length(payload->>'residualValue')>100 or payload->>'residualValue' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Assets' as section,'accumulatedDepreciation' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'accumulatedDepreciation','') is not null and (length(payload->>'accumulatedDepreciation')>100 or payload->>'accumulatedDepreciation' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Assets' as section,'netBookValue' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'netBookValue','') is not null and (length(payload->>'netBookValue')>100 or payload->>'netBookValue' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Assets' as section,'lastDepreciationDate' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'lastDepreciationDate','') is not null and (not pg_input_is_valid(payload->>'lastDepreciationDate','date'))
union all
select 'Assets' as section,'disposalDate' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'disposalDate','') is not null and (not pg_input_is_valid(payload->>'disposalDate','date'))
union all
select 'Assets' as section,'disposalProceeds' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'disposalProceeds','') is not null and (length(payload->>'disposalProceeds')>100 or payload->>'disposalProceeds' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Assets' as section,'assignedEmployeeId' as field,count(*)::bigint as issues from public.business_records r where section='Assets' and nullif(payload->>'assignedEmployeeId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Employees' and parent.record_id=r.payload->>'assignedEmployeeId'))
union all
select 'CapitalAccounts' as section,'shareholderId' as field,count(*)::bigint as issues from public.business_records r where section='CapitalAccounts' and nullif(payload->>'shareholderId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Shareholders' and parent.record_id=r.payload->>'shareholderId'))
union all
select 'CapitalTransactions' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='CapitalTransactions' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'CapitalTransactions' as section,'capitalAccountId' as field,count(*)::bigint as issues from public.business_records r where section='CapitalTransactions' and nullif(payload->>'capitalAccountId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='CapitalAccounts' and parent.record_id=r.payload->>'capitalAccountId'))
union all
select 'CapitalTransactions' as section,'shareholderId' as field,count(*)::bigint as issues from public.business_records r where section='CapitalTransactions' and nullif(payload->>'shareholderId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Shareholders' and parent.record_id=r.payload->>'shareholderId'))
union all
select 'CapitalTransactions' as section,'amount' as field,count(*)::bigint as issues from public.business_records r where section='CapitalTransactions' and nullif(payload->>'amount','') is not null and (length(payload->>'amount')>100 or payload->>'amount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Shareholders' as section,'agreedCapital' as field,count(*)::bigint as issues from public.business_records r where section='Shareholders' and nullif(payload->>'agreedCapital','') is not null and (length(payload->>'agreedCapital')>100 or payload->>'agreedCapital' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Shareholders' as section,'investmentDate' as field,count(*)::bigint as issues from public.business_records r where section='Shareholders' and nullif(payload->>'investmentDate','') is not null and (not pg_input_is_valid(payload->>'investmentDate','date'))
union all
select 'Shareholders' as section,'ownershipPercentage' as field,count(*)::bigint as issues from public.business_records r where section='Shareholders' and nullif(payload->>'ownershipPercentage','') is not null and (length(payload->>'ownershipPercentage')>100 or payload->>'ownershipPercentage' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ShareholderEquity' as section,'shareholderId' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderEquity' and nullif(payload->>'shareholderId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Shareholders' and parent.record_id=r.payload->>'shareholderId'))
union all
select 'ShareholderEquity' as section,'effectiveDate' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderEquity' and nullif(payload->>'effectiveDate','') is not null and (not pg_input_is_valid(payload->>'effectiveDate','date'))
union all
select 'ShareholderEquity' as section,'percentage' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderEquity' and nullif(payload->>'percentage','') is not null and (length(payload->>'percentage')>100 or payload->>'percentage' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ShareholderEquity' as section,'amount' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderEquity' and nullif(payload->>'amount','') is not null and (length(payload->>'amount')>100 or payload->>'amount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ShareholderLoans' as section,'shareholderId' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderLoans' and nullif(payload->>'shareholderId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Shareholders' and parent.record_id=r.payload->>'shareholderId'))
union all
select 'ShareholderLoans' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderLoans' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'ShareholderLoans' as section,'principal' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderLoans' and nullif(payload->>'principal','') is not null and (length(payload->>'principal')>100 or payload->>'principal' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ShareholderLoans' as section,'interestRate' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderLoans' and nullif(payload->>'interestRate','') is not null and (length(payload->>'interestRate')>100 or payload->>'interestRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ShareholderLoans' as section,'repaidAmount' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderLoans' and nullif(payload->>'repaidAmount','') is not null and (length(payload->>'repaidAmount')>100 or payload->>'repaidAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ShareholderLoans' as section,'outstandingBalance' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderLoans' and nullif(payload->>'outstandingBalance','') is not null and (length(payload->>'outstandingBalance')>100 or payload->>'outstandingBalance' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'ShareholderLoans' as section,'dueDate' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderLoans' and nullif(payload->>'dueDate','') is not null and (not pg_input_is_valid(payload->>'dueDate','date'))
union all
select 'ShareholderLoans' as section,'lastRepaymentDate' as field,count(*)::bigint as issues from public.business_records r where section='ShareholderLoans' and nullif(payload->>'lastRepaymentDate','') is not null and (not pg_input_is_valid(payload->>'lastRepaymentDate','date'))
union all
select 'FinancialPeriods' as section,'startDate' as field,count(*)::bigint as issues from public.business_records r where section='FinancialPeriods' and nullif(payload->>'startDate','') is not null and (not pg_input_is_valid(payload->>'startDate','date'))
union all
select 'Journals' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='Journals' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'Journals' as section,'totalDebit' as field,count(*)::bigint as issues from public.business_records r where section='Journals' and nullif(payload->>'totalDebit','') is not null and (length(payload->>'totalDebit')>100 or payload->>'totalDebit' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Journals' as section,'totalCredit' as field,count(*)::bigint as issues from public.business_records r where section='Journals' and nullif(payload->>'totalCredit','') is not null and (length(payload->>'totalCredit')>100 or payload->>'totalCredit' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'JournalLines' as section,'journalId' as field,count(*)::bigint as issues from public.business_records r where section='JournalLines' and nullif(payload->>'journalId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Journals' and parent.record_id=r.payload->>'journalId'))
union all
select 'JournalLines' as section,'lineNumber' as field,count(*)::bigint as issues from public.business_records r where section='JournalLines' and nullif(payload->>'lineNumber','') is not null and (length(payload->>'lineNumber')>100 or payload->>'lineNumber' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'JournalLines' as section,'debit' as field,count(*)::bigint as issues from public.business_records r where section='JournalLines' and nullif(payload->>'debit','') is not null and (length(payload->>'debit')>100 or payload->>'debit' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'JournalLines' as section,'credit' as field,count(*)::bigint as issues from public.business_records r where section='JournalLines' and nullif(payload->>'credit','') is not null and (length(payload->>'credit')>100 or payload->>'credit' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'DocumentRegistry' as section,'byteLength' as field,count(*)::bigint as issues from public.business_records r where section='DocumentRegistry' and nullif(payload->>'byteLength','') is not null and (length(payload->>'byteLength')>100 or payload->>'byteLength' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'NumberSequences' as section,'nextNumber' as field,count(*)::bigint as issues from public.business_records r where section='NumberSequences' and nullif(payload->>'nextNumber','') is not null and (length(payload->>'nextNumber')>100 or payload->>'nextNumber' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNotes' as section,'invoiceId' as field,count(*)::bigint as issues from public.business_records r where section='CreditNotes' and nullif(payload->>'invoiceId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Invoices' and parent.record_id=r.payload->>'invoiceId'))
union all
select 'CreditNotes' as section,'customerId' as field,count(*)::bigint as issues from public.business_records r where section='CreditNotes' and nullif(payload->>'customerId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Customers' and parent.record_id=r.payload->>'customerId'))
union all
select 'CreditNotes' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='CreditNotes' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'CreditNotes' as section,'subtotal' as field,count(*)::bigint as issues from public.business_records r where section='CreditNotes' and nullif(payload->>'subtotal','') is not null and (length(payload->>'subtotal')>100 or payload->>'subtotal' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNotes' as section,'discount' as field,count(*)::bigint as issues from public.business_records r where section='CreditNotes' and nullif(payload->>'discount','') is not null and (length(payload->>'discount')>100 or payload->>'discount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNotes' as section,'taxAmount' as field,count(*)::bigint as issues from public.business_records r where section='CreditNotes' and nullif(payload->>'taxAmount','') is not null and (length(payload->>'taxAmount')>100 or payload->>'taxAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNotes' as section,'total' as field,count(*)::bigint as issues from public.business_records r where section='CreditNotes' and nullif(payload->>'total','') is not null and (length(payload->>'total')>100 or payload->>'total' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNotes' as section,'refundAmount' as field,count(*)::bigint as issues from public.business_records r where section='CreditNotes' and nullif(payload->>'refundAmount','') is not null and (length(payload->>'refundAmount')>100 or payload->>'refundAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNoteItems' as section,'creditNoteId' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'creditNoteId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='CreditNotes' and parent.record_id=r.payload->>'creditNoteId'))
union all
select 'CreditNoteItems' as section,'invoiceId' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'invoiceId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Invoices' and parent.record_id=r.payload->>'invoiceId'))
union all
select 'CreditNoteItems' as section,'invoiceItemId' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'invoiceItemId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='InvoiceItems' and parent.record_id=r.payload->>'invoiceItemId'))
union all
select 'CreditNoteItems' as section,'lineNumber' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'lineNumber','') is not null and (length(payload->>'lineNumber')>100 or payload->>'lineNumber' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNoteItems' as section,'quantity' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'quantity','') is not null and (length(payload->>'quantity')>100 or payload->>'quantity' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNoteItems' as section,'unitPrice' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'unitPrice','') is not null and (length(payload->>'unitPrice')>100 or payload->>'unitPrice' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNoteItems' as section,'discount' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'discount','') is not null and (length(payload->>'discount')>100 or payload->>'discount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNoteItems' as section,'taxRate' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'taxRate','') is not null and (length(payload->>'taxRate')>100 or payload->>'taxRate' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNoteItems' as section,'taxAmount' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'taxAmount','') is not null and (length(payload->>'taxAmount')>100 or payload->>'taxAmount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNoteItems' as section,'lineTotal' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'lineTotal','') is not null and (length(payload->>'lineTotal')>100 or payload->>'lineTotal' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'CreditNoteItems' as section,'subtotal' as field,count(*)::bigint as issues from public.business_records r where section='CreditNoteItems' and nullif(payload->>'subtotal','') is not null and (length(payload->>'subtotal')>100 or payload->>'subtotal' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'Tasks' as section,'employeeId' as field,count(*)::bigint as issues from public.business_records r where section='Tasks' and nullif(payload->>'employeeId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Employees' and parent.record_id=r.payload->>'employeeId'))
union all
select 'Tasks' as section,'startDate' as field,count(*)::bigint as issues from public.business_records r where section='Tasks' and nullif(payload->>'startDate','') is not null and (not pg_input_is_valid(payload->>'startDate','date'))
union all
select 'Tasks' as section,'dueDate' as field,count(*)::bigint as issues from public.business_records r where section='Tasks' and nullif(payload->>'dueDate','') is not null and (not pg_input_is_valid(payload->>'dueDate','date'))
union all
select 'TaskComments' as section,'taskId' as field,count(*)::bigint as issues from public.business_records r where section='TaskComments' and nullif(payload->>'taskId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Tasks' and parent.record_id=r.payload->>'taskId'))
union all
select 'TaskActivity' as section,'taskId' as field,count(*)::bigint as issues from public.business_records r where section='TaskActivity' and nullif(payload->>'taskId','') is not null and (not exists(select 1 from public.business_records parent where parent.company_id=r.company_id and parent.section='Tasks' and parent.record_id=r.payload->>'taskId'))
union all
select 'MoneyTransfers' as section,'date' as field,count(*)::bigint as issues from public.business_records r where section='MoneyTransfers' and nullif(payload->>'date','') is not null and (not pg_input_is_valid(payload->>'date','date'))
union all
select 'MoneyTransfers' as section,'amount' as field,count(*)::bigint as issues from public.business_records r where section='MoneyTransfers' and nullif(payload->>'amount','') is not null and (length(payload->>'amount')>100 or payload->>'amount' !~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]{1,3})?$')
union all
select 'MoneyTransfers' as section,'statementDate' as field,count(*)::bigint as issues from public.business_records r where section='MoneyTransfers' and nullif(payload->>'statementDate','') is not null and (not pg_input_is_valid(payload->>'statementDate','date'))
union all
select 'MoneyTransfers' as section,'reversalDate' as field,count(*)::bigint as issues from public.business_records r where section='MoneyTransfers' and nullif(payload->>'reversalDate','') is not null and (not pg_input_is_valid(payload->>'reversalDate','date'))
) audit where issues>0 order by section,field;
