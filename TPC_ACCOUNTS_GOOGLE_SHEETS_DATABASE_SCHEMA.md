# TPC Accounts — Google Sheets Database Schema

**Project:** The Percentage Company FZ LLC (TPC)  
**Application:** TPC Accounts  
**Frontend:** Flutter Web / Mobile  
**Primary structured datastore:** Google Sheets  
**Document vault:** Google Drive  
**Version:** 1.0  
**Status:** Implementation specification

---

## 1. Purpose

This document defines the complete Google Sheets database structure for TPC Accounts.

The database must **not store business records as JSON blobs in individual cells**.

The required database rule is:

> **One sheet = one entity/table, one row = one record, one column = one field, one cell = one scalar value.**

Flutter may continue to use Dart models and JSON serialization internally, but the Google Sheets persistence layer must map each model field to a dedicated Google Sheets column.

---

# 2. Core Database Rules

## 2.1 No JSON blobs

Do not store records like:

```json
{
  "invoiceNo": "INV-0001",
  "customer": {
    "id": "CUS-001",
    "name": "ABC Trading"
  },
  "items": [],
  "payment": {}
}
```

inside one Google Sheets cell.

Instead:

```text
INVOICES
invoice_id | invoice_no | customer_id | invoice_date | subtotal | vat | total
```

and:

```text
INVOICE_ITEMS
item_id | invoice_id | product_id | description | qty | unit_price | vat_rate | vat_amount | line_total
```

---

## 2.2 IDs

Every business table must have a stable primary key.

Recommended format:

```text
CUS-000001
SUP-000001
INV-000001
INVITEM-000001
QUO-000001
EXP-000001
AST-000001
EMP-000001
PAY-000001
JRN-000001
```

The ID must never change after creation.

Do not use Google Sheets row numbers as IDs.

---

## 2.3 Dates

Store dates as:

```text
YYYY-MM-DD
```

Example:

```text
2026-09-12
```

Date/time fields use:

```text
YYYY-MM-DDTHH:mm:ssZ
```

The application may display UAE-local formatting such as:

```text
12 Sep 2026
```

but persistence should use a consistent machine-readable format.

---

## 2.4 Currency

Primary currency:

```text
AED
```

Monetary values must be stored as numeric cells, not formatted strings.

Correct:

```text
1500.00
```

Incorrect:

```text
AED 1,500
```

Currency code must be stored separately where multi-currency support is needed.

---

## 2.5 Boolean values

Use:

```text
TRUE
FALSE
```

Do not use inconsistent values such as:

```text
yes
Y
1
active
```

---

## 2.6 Status values

Statuses must be controlled enums.

Example:

```text
DRAFT
POSTED
VOID
CANCELLED
PAID
PARTIALLY_PAID
UNPAID
ACTIVE
INACTIVE
```

---

# 3. Sheet Naming Convention

Use uppercase sheet names:

```text
CONFIG
USERS
COMPANY
SHAREHOLDERS
CHART_OF_ACCOUNTS
CUSTOMERS
SUPPLIERS
PRODUCTS
TAX_CODES
BANK_ACCOUNTS
CASH_ACCOUNTS
QUOTATIONS
QUOTATION_ITEMS
INVOICES
INVOICE_ITEMS
PAYMENTS
PAYMENT_ALLOCATIONS
EXPENSES
EXPENSE_ITEMS
JOURNAL_ENTRIES
JOURNAL_LINES
CAPITAL_TRANSACTIONS
ASSETS
ASSET_DEPRECIATION
ASSET_DISPOSALS
EMPLOYEES
EMPLOYEE_BANK_ACCOUNTS
ATTENDANCE
OVERTIME
LEAVE
PAYROLL_RUNS
PAYROLL_ITEMS
PAYSLIPS
DOCUMENTS
AUDIT_LOG
SYNC_LOG
```

Reports should generally be **calculated from transactional sheets**, not duplicated as manually maintained database records.

---

# 4. Common Audit Columns

Transactional tables should include these fields whenever applicable:

| Column | Type | Description |
|---|---|---|
| created_at | datetime | Record creation time |
| created_by | string | User ID |
| updated_at | datetime | Last modification time |
| updated_by | string | User ID |
| status | enum | Current record status |

These are dedicated cells.

Do not put audit information into a JSON metadata column.

---

# 5. CONFIG

Stores application configuration that does not belong to a business transaction.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| config_id | string | PK | Unique configuration ID |
| config_key | string | UNIQUE | Configuration key |
| config_value | string | | Configuration value |
| value_type | enum | | STRING, NUMBER, BOOLEAN, DATE |
| description | string | | Description |
| updated_at | datetime | | Last update |

Examples:

```text
DEFAULT_CURRENCY = AED
DEFAULT_VAT_RATE = 5
INVOICE_PREFIX = INV
QUOTATION_PREFIX = QUO
```

Do not use CONFIG for transactional records.

---

# 6. USERS

Application users.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| user_id | string | PK | User ID |
| email | string | UNIQUE | Google account email |
| display_name | string | | User name |
| role | enum | | ADMIN, ACCOUNTANT, HR, SALES, VIEWER |
| active | boolean | | User active flag |
| created_at | datetime | | Creation time |
| updated_at | datetime | | Last update |

---

# 7. COMPANY

Company master record.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| company_id | string | PK | Company ID |
| legal_name | string | | Legal company name |
| trade_name | string | | Trading name |
| license_no | string | | Trade/license number |
| tax_registration_no | string | | UAE VAT TRN |
| email | string | | Company email |
| phone | string | | Company phone |
| address_line1 | string | | Address |
| address_line2 | string | | Address |
| city | string | | City |
| emirate | string | | Emirate |
| country | string | | Country |
| postal_code | string | | Postal code |
| currency_code | string | | Default currency |
| fiscal_year_start | date | | Fiscal year start |
| fiscal_year_end | date | | Fiscal year end |
| status | enum | | ACTIVE, INACTIVE |
| created_at | datetime | | |
| updated_at | datetime | | |

---

# 8. SHAREHOLDERS

Shareholder/partner master.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| shareholder_id | string | PK | Shareholder ID |
| company_id | string | FK → COMPANY | Company |
| shareholder_code | string | UNIQUE | Short code |
| name | string | | Full name |
| ownership_percent | decimal | | Agreed ownership percentage |
| agreed_capital | decimal | | Agreed contribution |
| phone | string | | Contact |
| email | string | | Email |
| status | enum | | ACTIVE, INACTIVE |
| created_at | datetime | | |
| updated_at | datetime | | |

### Formula

Ownership validation:

```text
SUM(active shareholders.ownership_percent) = 100%
```

The application should warn if ownership does not total 100%.

---

# 9. CHART_OF_ACCOUNTS

Accounting account master.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| account_id | string | PK | Account ID |
| account_code | string | UNIQUE | Account code |
| account_name | string | | Account name |
| account_type | enum | | ASSET, LIABILITY, EQUITY, INCOME, EXPENSE |
| parent_account_id | string | FK → CHART_OF_ACCOUNTS | Parent account |
| normal_balance | enum | | DEBIT, CREDIT |
| is_control_account | boolean | | Control account |
| active | boolean | | Active |
| description | string | | Description |

Recommended account ranges:

```text
1000–1999 Assets
2000–2999 Liabilities
3000–3999 Equity
4000–4999 Income
5000–5999 Expenses
```

Recommended equity accounts:

```text
3000 Equity
3100 Partner A Capital
3200 Partner B Capital
3300 Retained Earnings
3400 Current Year Profit
```

---

# 10. CUSTOMERS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| customer_id | string | PK | Customer ID |
| customer_code | string | UNIQUE | Customer code |
| name | string | | Customer name |
| company_name | string | | Company |
| email | string | | Email |
| phone | string | | Phone |
| tax_registration_no | string | | VAT TRN |
| address_line1 | string | | |
| address_line2 | string | | |
| city | string | | |
| emirate | string | | |
| country | string | | |
| credit_limit | decimal | | Credit limit |
| payment_terms_days | integer | | Payment terms |
| receivable_account_id | string | FK → CHART_OF_ACCOUNTS | AR account |
| status | enum | | ACTIVE, INACTIVE |
| created_at | datetime | | |
| updated_at | datetime | | |

---

# 11. SUPPLIERS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| supplier_id | string | PK | Supplier ID |
| supplier_code | string | UNIQUE | Supplier code |
| name | string | | Supplier name |
| company_name | string | | Company |
| email | string | | |
| phone | string | | |
| tax_registration_no | string | | VAT TRN |
| address_line1 | string | | |
| address_line2 | string | | |
| city | string | | |
| country | string | | |
| payment_terms_days | integer | | |
| payable_account_id | string | FK → CHART_OF_ACCOUNTS | AP account |
| status | enum | | |
| created_at | datetime | | |
| updated_at | datetime | | |

---

# 12. PRODUCTS

Used for products/services appearing in quotations and invoices.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| product_id | string | PK | Product ID |
| sku | string | UNIQUE | SKU |
| name | string | | Product/service name |
| description | string | | Description |
| product_type | enum | | PRODUCT, SERVICE |
| unit | string | | PCS, HOUR, MONTH etc. |
| default_price | decimal | | Default selling price |
| cost_price | decimal | | Cost |
| tax_code_id | string | FK → TAX_CODES | VAT code |
| income_account_id | string | FK → CHART_OF_ACCOUNTS | Sales account |
| expense_account_id | string | FK → CHART_OF_ACCOUNTS | Cost account |
| active | boolean | | |
| created_at | datetime | | |
| updated_at | datetime | | |

---

# 13. TAX_CODES

| Column | Type | PK/FK | Description |
|---|---|---|---|
| tax_code_id | string | PK | Tax code |
| code | string | UNIQUE | VAT5, ZERO, EXEMPT etc. |
| name | string | | Tax name |
| rate | decimal | | VAT rate |
| tax_type | enum | | OUTPUT_VAT, INPUT_VAT, ZERO, EXEMPT |
| active | boolean | | |
| description | string | | |

For UAE standard VAT:

```text
VAT5
rate = 5
tax_type = OUTPUT_VAT / INPUT_VAT depending on transaction
```

---

# 14. BANK_ACCOUNTS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| bank_account_id | string | PK | Bank account ID |
| account_name | string | | Display name |
| bank_name | string | | Bank |
| account_number_masked | string | | Masked account number |
| iban_masked | string | | Masked IBAN |
| currency_code | string | | Currency |
| ledger_account_id | string | FK → CHART_OF_ACCOUNTS | Bank GL account |
| opening_balance | decimal | | Opening balance |
| active | boolean | | |
| created_at | datetime | | |
| updated_at | datetime | | |

Do not store banking passwords, OTPs, full credentials or API secrets in Sheets.

---

# 15. CASH_ACCOUNTS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| cash_account_id | string | PK | Cash account |
| account_name | string | | Cash account name |
| ledger_account_id | string | FK → CHART_OF_ACCOUNTS | Cash GL account |
| opening_balance | decimal | | Opening balance |
| active | boolean | | |
| created_at | datetime | | |
| updated_at | datetime | | |

---

# 16. QUOTATIONS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| quotation_id | string | PK | Quotation ID |
| quotation_no | string | UNIQUE | Quotation number |
| customer_id | string | FK → CUSTOMERS | Customer |
| quotation_date | date | | Date |
| expiry_date | date | | Valid until |
| currency_code | string | | Currency |
| subtotal | decimal | | Before VAT |
| discount_total | decimal | | Discount |
| taxable_amount | decimal | | Taxable amount |
| vat_amount | decimal | | VAT |
| total_amount | decimal | | Grand total |
| notes | string | | Notes |
| terms | string | | Terms |
| status | enum | | DRAFT, SENT, ACCEPTED, REJECTED, EXPIRED, CONVERTED |
| created_at | datetime | | |
| created_by | string | FK → USERS | |
| updated_at | datetime | | |
| updated_by | string | FK → USERS | |

### Formula

```text
taxable_amount = subtotal - discount_total
total_amount = taxable_amount + vat_amount
```

---

# 17. QUOTATION_ITEMS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| quotation_item_id | string | PK | Line ID |
| quotation_id | string | FK → QUOTATIONS | Parent quotation |
| line_no | integer | | Line number |
| product_id | string | FK → PRODUCTS | Product/service |
| description | string | | Snapshot description |
| quantity | decimal | | Quantity |
| unit | string | | Unit |
| unit_price | decimal | | Price |
| discount_percent | decimal | | Discount |
| discount_amount | decimal | | Discount amount |
| tax_code_id | string | FK → TAX_CODES | Tax |
| tax_rate | decimal | | Snapshot VAT rate |
| taxable_amount | decimal | | |
| tax_amount | decimal | | |
| line_total | decimal | | |

### Formulas

```text
gross_amount = quantity × unit_price

discount_amount =
gross_amount × discount_percent / 100

taxable_amount =
gross_amount - discount_amount

tax_amount =
taxable_amount × tax_rate / 100

line_total =
taxable_amount + tax_amount
```

The Flutter app should calculate and validate these values before posting.

---

# 18. INVOICES

| Column | Type | PK/FK | Description |
|---|---|---|---|
| invoice_id | string | PK | Invoice ID |
| invoice_no | string | UNIQUE | Invoice number |
| quotation_id | string | FK → QUOTATIONS | Optional source quotation |
| customer_id | string | FK → CUSTOMERS | Customer |
| invoice_date | date | | Invoice date |
| due_date | date | | Due date |
| currency_code | string | | Currency |
| subtotal | decimal | | |
| discount_total | decimal | | |
| taxable_amount | decimal | | |
| vat_amount | decimal | | |
| total_amount | decimal | | |
| amount_paid | decimal | | |
| balance_due | decimal | | |
| notes | string | | |
| terms | string | | |
| status | enum | | DRAFT, POSTED, PARTIALLY_PAID, PAID, VOID, CANCELLED |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | Posted journal |
| created_at | datetime | | |
| created_by | string | FK → USERS | |
| updated_at | datetime | | |
| updated_by | string | FK → USERS | |

### Formulas

```text
balance_due = total_amount - amount_paid
```

Invoice totals should be derived from invoice items.

---

# 19. INVOICE_ITEMS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| invoice_item_id | string | PK | Line ID |
| invoice_id | string | FK → INVOICES | Parent invoice |
| line_no | integer | | |
| product_id | string | FK → PRODUCTS | Product/service |
| description | string | | Snapshot |
| quantity | decimal | | |
| unit | string | | |
| unit_price | decimal | | |
| discount_percent | decimal | | |
| discount_amount | decimal | | |
| tax_code_id | string | FK → TAX_CODES | |
| tax_rate | decimal | | Snapshot |
| taxable_amount | decimal | | |
| tax_amount | decimal | | |
| line_total | decimal | | |

Use the same line formulas as QUOTATION_ITEMS.

---

# 20. PAYMENTS

Customer receipts and supplier/company payments.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| payment_id | string | PK | Payment ID |
| payment_no | string | UNIQUE | Payment number |
| payment_date | date | | |
| payment_type | enum | | RECEIPT, PAYMENT |
| customer_id | string | FK → CUSTOMERS | For receipts |
| supplier_id | string | FK → SUPPLIERS | For supplier payments |
| account_type | enum | | BANK, CASH |
| bank_account_id | string | FK → BANK_ACCOUNTS | Optional |
| cash_account_id | string | FK → CASH_ACCOUNTS | Optional |
| amount | decimal | | Payment amount |
| currency_code | string | | |
| payment_method | enum | | CASH, BANK_TRANSFER, CARD, CHEQUE, OTHER |
| reference_no | string | | Bank/cheque reference |
| notes | string | | |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | |
| status | enum | | DRAFT, POSTED, VOID |
| created_at | datetime | | |
| created_by | string | FK → USERS | |

---

# 21. PAYMENT_ALLOCATIONS

Connects payments to invoices/bills.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| allocation_id | string | PK | Allocation ID |
| payment_id | string | FK → PAYMENTS | Payment |
| invoice_id | string | FK → INVOICES | Invoice |
| allocated_amount | decimal | | Amount allocated |
| allocation_date | date | | |
| created_at | datetime | | |

### Formula

```text
invoice.amount_paid =
SUM(PAYMENT_ALLOCATIONS.allocated_amount)
```

---

# 22. EXPENSES

Expense header.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| expense_id | string | PK | Expense ID |
| expense_no | string | UNIQUE | Expense number |
| expense_date | date | | |
| supplier_id | string | FK → SUPPLIERS | Optional |
| category_account_id | string | FK → CHART_OF_ACCOUNTS | Expense account |
| description | string | | |
| payment_method | enum | | CASH, BANK, CARD, CREDIT |
| bank_account_id | string | FK → BANK_ACCOUNTS | |
| cash_account_id | string | FK → CASH_ACCOUNTS | |
| subtotal | decimal | | |
| vat_amount | decimal | | |
| total_amount | decimal | | |
| tax_code_id | string | FK → TAX_CODES | |
| reference_no | string | | |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | |
| status | enum | | DRAFT, POSTED, VOID |
| created_at | datetime | | |
| created_by | string | FK → USERS | |
| updated_at | datetime | | |

---

# 23. EXPENSE_ITEMS

Use this when an expense has multiple categories/items.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| expense_item_id | string | PK | Line ID |
| expense_id | string | FK → EXPENSES | Parent |
| line_no | integer | | |
| account_id | string | FK → CHART_OF_ACCOUNTS | Expense account |
| description | string | | |
| quantity | decimal | | |
| unit_price | decimal | | |
| taxable_amount | decimal | | |
| tax_code_id | string | FK → TAX_CODES | |
| tax_rate | decimal | | |
| tax_amount | decimal | | |
| line_total | decimal | | |

---

# 24. JOURNAL_ENTRIES

This is the accounting posting header.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| journal_entry_id | string | PK | Journal ID |
| journal_no | string | UNIQUE | Journal number |
| journal_date | date | | Posting date |
| source_type | enum | | INVOICE, PAYMENT, EXPENSE, CAPITAL, ASSET, PAYROLL, MANUAL, OPENING |
| source_id | string | | Source record ID |
| description | string | | Journal description |
| total_debit | decimal | | |
| total_credit | decimal | | |
| status | enum | | DRAFT, POSTED, VOID |
| posted_at | datetime | | |
| posted_by | string | FK → USERS | |
| created_at | datetime | | |

### Validation

```text
total_debit = total_credit
```

A journal cannot be POSTED unless:

```text
total_debit - total_credit = 0
```

---

# 25. JOURNAL_LINES

| Column | Type | PK/FK | Description |
|---|---|---|---|
| journal_line_id | string | PK | Line ID |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | Journal |
| line_no | integer | | |
| account_id | string | FK → CHART_OF_ACCOUNTS | Account |
| description | string | | |
| debit | decimal | | Debit |
| credit | decimal | | Credit |
| customer_id | string | FK → CUSTOMERS | Optional |
| supplier_id | string | FK → SUPPLIERS | Optional |
| shareholder_id | string | FK → SHAREHOLDERS | Optional |
| asset_id | string | FK → ASSETS | Optional |
| employee_id | string | FK → EMPLOYEES | Optional |

Rule:

```text
A line cannot normally have both debit and credit > 0.
```

---

# 26. CAPITAL_TRANSACTIONS

Shareholder equity movements.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| capital_transaction_id | string | PK | Transaction ID |
| transaction_no | string | UNIQUE | Reference |
| transaction_date | date | | |
| shareholder_id | string | FK → SHAREHOLDERS | Shareholder |
| transaction_type | enum | | CAPITAL_CONTRIBUTION, ADDITIONAL_CAPITAL, ASSET_CONTRIBUTION, CAPITAL_WITHDRAWAL, EQUITY_ADJUSTMENT |
| amount | decimal | | Monetary amount |
| asset_id | string | FK → ASSETS | Required for asset contribution |
| bank_account_id | string | FK → BANK_ACCOUNTS | |
| cash_account_id | string | FK → CASH_ACCOUNTS | |
| description | string | | |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | |
| status | enum | | DRAFT, POSTED, VOID |
| created_at | datetime | | |
| created_by | string | FK → USERS | |

### Capital formulas

```text
total_capital_contributions =
cash contributions
+ bank contributions
+ asset contributions
+ additional capital
+ other equity contributions
```

```text
net_capital_invested =
total_capital_contributions
- capital_withdrawals
```

```text
outstanding_capital =
agreed_capital
- net_capital_invested
```

```text
capital_contribution_percent =
net_capital_invested / agreed_capital × 100
```

Capital contribution does **not** affect P&L.

---

# 27. ASSETS

Fixed asset register.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| asset_id | string | PK | Asset ID |
| asset_code | string | UNIQUE | Asset code |
| asset_name | string | | Asset name |
| category | string | | Computer, furniture, vehicle etc. |
| description | string | | |
| purchase_date | date | | |
| purchase_cost | decimal | | Original cost |
| supplier_id | string | FK → SUPPLIERS | Supplier |
| payment_bank_account_id | string | FK → BANK_ACCOUNTS | |
| payment_cash_account_id | string | FK → CASH_ACCOUNTS | |
| contributed_by_shareholder_id | string | FK → SHAREHOLDERS | If capital contribution |
| useful_life_months | integer | | Useful life |
| residual_value | decimal | | Residual value |
| depreciation_method | enum | | STRAIGHT_LINE |
| depreciation_start_date | date | | |
| accumulated_depreciation | decimal | | |
| current_book_value | decimal | | |
| asset_account_id | string | FK → CHART_OF_ACCOUNTS | Asset GL |
| depreciation_expense_account_id | string | FK → CHART_OF_ACCOUNTS | Expense GL |
| accumulated_depreciation_account_id | string | FK → CHART_OF_ACCOUNTS | Contra asset |
| status | enum | | ACTIVE, FULLY_DEPRECIATED, DISPOSED |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | Acquisition journal |
| created_at | datetime | | |
| updated_at | datetime | | |

### Formulas

Straight-line monthly depreciation:

```text
depreciable_amount =
purchase_cost - residual_value
```

```text
monthly_depreciation =
depreciable_amount / useful_life_months
```

```text
current_book_value =
purchase_cost - accumulated_depreciation
```

Do not allow book value below residual value.

---

# 28. ASSET_DEPRECIATION

Monthly depreciation schedule.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| depreciation_id | string | PK | Depreciation ID |
| asset_id | string | FK → ASSETS | Asset |
| period | string | | YYYY-MM |
| depreciation_date | date | | Posting date |
| opening_book_value | decimal | | |
| depreciation_amount | decimal | | |
| closing_book_value | decimal | | |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | |
| status | enum | | DRAFT, POSTED, VOID |
| created_at | datetime | | |

Formula:

```text
closing_book_value =
opening_book_value - depreciation_amount
```

---

# 29. ASSET_DISPOSALS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| disposal_id | string | PK | Disposal ID |
| asset_id | string | FK → ASSETS | Asset |
| disposal_date | date | | |
| disposal_type | enum | | SALE, SCRAP, TRANSFER |
| sale_proceeds | decimal | | |
| book_value_at_disposal | decimal | | |
| gain_loss | decimal | | |
| buyer_reference | string | | |
| notes | string | | |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | |
| status | enum | | DRAFT, POSTED, VOID |
| created_at | datetime | | |

Formula:

```text
gain_loss =
sale_proceeds - book_value_at_disposal
```

---

# 30. EMPLOYEES

| Column | Type | PK/FK | Description |
|---|---|---|---|
| employee_id | string | PK | Employee ID |
| employee_code | string | UNIQUE | Employee code |
| full_name | string | | Name |
| email | string | | |
| phone | string | | |
| job_title | string | | |
| department | string | | |
| joining_date | date | | |
| employment_status | enum | | ACTIVE, INACTIVE, TERMINATED |
| basic_salary | decimal | | Basic salary |
| housing_allowance | decimal | | |
| transport_allowance | decimal | | |
| other_allowance | decimal | | |
| bank_account_id | string | FK → EMPLOYEE_BANK_ACCOUNTS | |
| payroll_account_id | string | FK → CHART_OF_ACCOUNTS | Salary expense |
| created_at | datetime | | |
| updated_at | datetime | | |

Sensitive HR information should only be stored if necessary and access-controlled.

---

# 31. EMPLOYEE_BANK_ACCOUNTS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| employee_bank_account_id | string | PK | ID |
| employee_id | string | FK → EMPLOYEES | Employee |
| bank_name | string | | |
| account_name | string | | |
| iban_masked | string | | |
| account_number_masked | string | | |
| active | boolean | | |
| created_at | datetime | | |
| updated_at | datetime | | |

Do not store online banking credentials.

---

# 32. ATTENDANCE

| Column | Type | PK/FK | Description |
|---|---|---|---|
| attendance_id | string | PK | Attendance ID |
| employee_id | string | FK → EMPLOYEES | Employee |
| attendance_date | date | | |
| check_in | datetime | | |
| check_out | datetime | | |
| regular_hours | decimal | | |
| overtime_hours | decimal | | |
| status | enum | | PRESENT, ABSENT, LATE, LEAVE, OFF |
| notes | string | | |
| approved_by | string | FK → USERS | |
| created_at | datetime | | |
| updated_at | datetime | | |

---

# 33. OVERTIME

| Column | Type | PK/FK | Description |
|---|---|---|---|
| overtime_id | string | PK | Overtime ID |
| employee_id | string | FK → EMPLOYEES | Employee |
| overtime_date | date | | |
| hours | decimal | | Hours |
| hourly_rate | decimal | | |
| multiplier | decimal | | |
| overtime_amount | decimal | | |
| approved_by | string | FK → USERS | |
| status | enum | | DRAFT, APPROVED, REJECTED, PAID |
| created_at | datetime | | |

Formula:

```text
overtime_amount =
hours × hourly_rate × multiplier
```

---

# 34. LEAVE

| Column | Type | PK/FK | Description |
|---|---|---|---|
| leave_id | string | PK | Leave ID |
| employee_id | string | FK → EMPLOYEES | Employee |
| leave_type | enum | | ANNUAL, SICK, UNPAID, OTHER |
| start_date | date | | |
| end_date | date | | |
| days | decimal | | |
| reason | string | | |
| approved_by | string | FK → USERS | |
| status | enum | | REQUESTED, APPROVED, REJECTED, CANCELLED |
| created_at | datetime | | |

---

# 35. PAYROLL_RUNS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| payroll_run_id | string | PK | Payroll run |
| payroll_no | string | UNIQUE | Payroll number |
| period_start | date | | |
| period_end | date | | |
| payroll_date | date | | |
| total_basic | decimal | | |
| total_allowances | decimal | | |
| total_overtime | decimal | | |
| total_deductions | decimal | | |
| total_net_salary | decimal | | |
| journal_entry_id | string | FK → JOURNAL_ENTRIES | |
| status | enum | | DRAFT, APPROVED, POSTED, PAID |
| created_at | datetime | | |
| created_by | string | FK → USERS | |

---

# 36. PAYROLL_ITEMS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| payroll_item_id | string | PK | Payroll item |
| payroll_run_id | string | FK → PAYROLL_RUNS | Payroll run |
| employee_id | string | FK → EMPLOYEES | Employee |
| basic_salary | decimal | | |
| allowances | decimal | | |
| overtime | decimal | | |
| gross_salary | decimal | | |
| deductions | decimal | | |
| net_salary | decimal | | |
| working_days | decimal | | |
| unpaid_leave_days | decimal | | |
| status | enum | | DRAFT, APPROVED, PAID |

Formula:

```text
gross_salary =
basic_salary + allowances + overtime
```

```text
net_salary =
gross_salary - deductions
```

---

# 37. PAYSLIPS

| Column | Type | PK/FK | Description |
|---|---|---|---|
| payslip_id | string | PK | Payslip ID |
| payroll_run_id | string | FK → PAYROLL_RUNS | |
| payroll_item_id | string | FK → PAYROLL_ITEMS | |
| employee_id | string | FK → EMPLOYEES | |
| period_start | date | | |
| period_end | date | | |
| basic_salary | decimal | | |
| allowances | decimal | | |
| overtime | decimal | | |
| gross_salary | decimal | | |
| deductions | decimal | | |
| net_salary | decimal | | |
| document_id | string | FK → DOCUMENTS | PDF payslip |
| status | enum | | GENERATED, SENT |
| created_at | datetime | | |

---

# 38. DOCUMENTS

Metadata for files stored in Google Drive.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| document_id | string | PK | Document ID |
| entity_type | enum | | INVOICE, QUOTATION, EXPENSE, ASSET, EMPLOYEE, PAYSLIP, OTHER |
| entity_id | string | | Related entity ID |
| document_type | string | | Invoice PDF, receipt, attachment etc. |
| file_name | string | | Drive file name |
| drive_file_id | string | | Google Drive file ID |
| mime_type | string | | MIME type |
| file_size | integer | | Bytes |
| drive_folder_id | string | | Drive folder |
| uploaded_by | string | FK → USERS | |
| uploaded_at | datetime | | |
| status | enum | | ACTIVE, ARCHIVED |

The actual document file belongs in Google Drive. Google Sheets stores only document metadata and Drive identifiers.

---

# 39. AUDIT_LOG

Immutable business audit trail.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| audit_id | string | PK | Audit ID |
| event_time | datetime | | Event time |
| user_id | string | FK → USERS | User |
| action | enum | | CREATE, UPDATE, DELETE, POST, VOID, LOGIN, EXPORT |
| entity_type | string | | Entity |
| entity_id | string | | Record ID |
| field_name | string | | Changed field |
| old_value | string | | Previous value |
| new_value | string | | New value |
| source | string | | WEB, MOBILE, API |
| notes | string | | |

Each changed field may be a separate audit row.

Do not store an entire changed object as JSON.

---

# 40. SYNC_LOG

Tracks Flutter ↔ Google Sheets synchronization.

| Column | Type | PK/FK | Description |
|---|---|---|---|
| sync_id | string | PK | Sync operation ID |
| sync_time | datetime | | |
| user_id | string | FK → USERS | |
| entity_type | string | | Entity |
| entity_id | string | | Record |
| operation | enum | | CREATE, UPDATE, DELETE |
| sheet_name | string | | Target sheet |
| result | enum | | SUCCESS, FAILED |
| error_code | string | | |
| error_message | string | | |
| retry_count | integer | | |
| client_version | string | | Flutter app version |

---

# 41. Accounting Journal Rules

## 41.1 Invoice

Example:

```text
Invoice = AED 1,050
Net sales = AED 1,000
VAT = AED 50
```

Journal:

```text
DR Accounts Receivable       1,050
CR Sales Revenue             1,000
CR Output VAT                   50
```

---

## 41.2 Customer receipt

```text
DR Bank/Cash                 1,050
CR Accounts Receivable       1,050
```

---

## 41.3 Expense paid immediately

Example:

```text
Expense = AED 1,050
Expense = AED 1,000
Input VAT = AED 50
```

```text
DR Expense                   1,000
DR Input VAT                    50
CR Bank/Cash                 1,050
```

---

## 41.4 Capital contribution

Cash contribution:

```text
DR Bank/Cash
CR Shareholder Capital
```

Asset contribution:

```text
DR Fixed Asset
CR Shareholder Capital
```

Capital contribution must not appear as income.

---

## 41.5 Shareholder loan

```text
DR Bank/Cash
CR Shareholder Loan Liability
```

A shareholder loan is a liability, not equity.

---

## 41.6 Asset purchase

```text
DR Fixed Asset
CR Bank/Cash
```

The original asset purchase cost is not immediately an operating expense when capitalized.

---

## 41.7 Depreciation

```text
DR Depreciation Expense
CR Accumulated Depreciation
```

Depreciation affects profit but does not directly represent a cash payment.

---

## 41.8 Payroll

At payroll posting:

```text
DR Salary Expense
DR Allowance Expense
DR Overtime Expense
CR Salary Payable
```

When salary is paid:

```text
DR Salary Payable
CR Bank
```

The exact payroll journal may be expanded based on the company's final payroll rules.

---

# 42. Capital and Equity Calculations

## Total capital contributions

```text
total_capital_contributions =
SUM(CAPITAL_TRANSACTIONS where type =
CAPITAL_CONTRIBUTION,
ADDITIONAL_CAPITAL,
ASSET_CONTRIBUTION)
```

## Capital withdrawals

```text
capital_withdrawals =
SUM(CAPITAL_TRANSACTIONS where type = CAPITAL_WITHDRAWAL)
```

## Net capital invested

```text
net_capital_invested =
total_capital_contributions - capital_withdrawals
```

## Outstanding agreed capital

```text
outstanding_capital =
shareholder.agreed_capital - net_capital_invested
```

## Current equity

```text
current_equity =
net_capital_invested
+ retained_earnings
+ current_year_profit_loss
+ equity_adjustments
```

---

# 43. Profit & Loss Calculations

## Revenue

```text
total_income =
SUM(POSTED revenue journal lines)
```

## Expenses

```text
total_expenses =
SUM(POSTED expense journal lines)
```

## Net profit

```text
net_profit =
total_income - total_expenses
```

Important:

```text
CAPITAL_CONTRIBUTION ≠ INCOME
SHAREHOLDER_LOAN ≠ INCOME
ASSET_PURCHASE ≠ EXPENSE
LOAN_REPAYMENT ≠ EXPENSE
```

---

# 44. Balance Sheet Calculations

Accounting equation:

```text
TOTAL ASSETS =
TOTAL LIABILITIES + TOTAL EQUITY
```

## Assets

Examples:

```text
Cash
Bank
Accounts Receivable
Fixed Assets
Other Assets
```

## Liabilities

Examples:

```text
Accounts Payable
Loans
Shareholder Loans
Salary Payable
VAT Payable
```

## Equity

Examples:

```text
Shareholder Capital
Retained Earnings
Current Year Profit/Loss
Equity Adjustments
```

## Balance check

```text
balance_check =
total_assets
- total_liabilities
- total_equity
```

Required:

```text
balance_check = 0.00
```

Allow only a very small decimal rounding tolerance if required.

---

# 45. Cash Flow Calculation

Cash flow should be calculated from actual cash/bank journal lines.

### Operating

```text
customer receipts
- operating payments
```

### Investing

```text
asset purchases
+ asset sale proceeds
```

### Financing

```text
capital contributions
+ shareholder loans
- capital withdrawals
- loan repayments
```

### Net cash movement

```text
net_cash_movement =
operating_cash_flow
+ investing_cash_flow
+ financing_cash_flow
```

```text
closing_cash =
opening_cash + net_cash_movement
```

---

# 46. Accounts Receivable

AR should be calculated from invoices and allocations.

```text
customer_balance =
SUM(invoice.total_amount)
- SUM(payment_allocations.allocated_amount)
```

Outstanding invoice:

```text
invoice_balance =
invoice.total_amount
- SUM(payment_allocations.allocated_amount)
```

A customer statement should be generated from posted invoices, credit adjustments and payment allocations.

---

# 47. Accounts Payable

Supplier payable should be calculated from posted supplier expenses/bills less supplier payment allocations.

Do not maintain a manually typed payable balance if it can be derived from transactions.

---

# 48. Asset Register Calculations

For each active asset:

```text
depreciable_amount =
purchase_cost - residual_value
```

```text
monthly_depreciation =
depreciable_amount / useful_life_months
```

```text
accumulated_depreciation =
SUM(ASSET_DEPRECIATION.depreciation_amount)
```

```text
book_value =
purchase_cost - accumulated_depreciation
```

---

# 49. Report Architecture

Reports should be calculated from source transactions.

Do not create duplicate manually maintained sheets such as:

```text
MONTHLY_PROFIT
MONTHLY_BALANCE
CUSTOMER_BALANCE
CAPITAL_REPORT
```

unless they are generated snapshots/export tables.

Recommended reports:

```text
Profit & Loss
Balance Sheet
Cash Flow
Trial Balance
General Ledger
Accounts Receivable
Accounts Payable
Capital & Equity
Asset Register
Depreciation
VAT Summary
Sales Report
Expense Report
Payroll Report
Attendance Report
Bank/Cash Report
```

---

# 50. Trial Balance

Trial balance is calculated from posted JOURNAL_LINES.

For every account:

```text
debit_total =
SUM(POSTED journal_lines.debit)
```

```text
credit_total =
SUM(POSTED journal_lines.credit)
```

Required:

```text
SUM(all debit balances)
=
SUM(all credit balances)
```

---

# 51. General Ledger

General ledger rows come directly from:

```text
JOURNAL_ENTRIES
+
JOURNAL_LINES
+
CHART_OF_ACCOUNTS
```

Recommended display:

```text
Date
Journal No
Source
Account Code
Account Name
Description
Debit
Credit
Running Balance
```

Running balance depends on the account's normal balance.

---

# 52. Flutter → Google Sheets Architecture

Recommended architecture:

```text
Flutter UI
   ↓
Cubit / Bloc
   ↓
Repository
   ↓
Domain Model
   ↓
Google Sheets Mapper
   ↓
Sheet Repository
   ↓
Google Sheets API
```

Never let UI widgets write directly to Google Sheets.

---

# 53. Flutter Model → Sheet Mapping

Every model needs an explicit mapper.

Example:

```dart
class Invoice {
  final String invoiceId;
  final String invoiceNo;
  final String customerId;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final double subtotal;
  final double vatAmount;
  final double totalAmount;
  final String status;
}
```

Mapper:

```dart
List<Object?> toSheetRow(Invoice model) {
  return [
    model.invoiceId,
    model.invoiceNo,
    model.customerId,
    formatDate(model.invoiceDate),
    formatDate(model.dueDate),
    model.subtotal,
    model.vatAmount,
    model.totalAmount,
    model.amountPaid,
    model.balanceDue,
    model.status,
    model.createdAt.toIso8601String(),
    model.createdBy,
    model.updatedAt.toIso8601String(),
    model.updatedBy,
  ];
}
```

The order must exactly match the sheet header.

---

# 54. Sheet Header Contract

Each sheet must have a fixed header row.

Example `INVOICES`:

```text
invoice_id
invoice_no
quotation_id
customer_id
invoice_date
due_date
currency_code
subtotal
discount_total
taxable_amount
vat_amount
total_amount
amount_paid
balance_due
notes
terms
status
journal_entry_id
created_at
created_by
updated_at
updated_by
```

The application must not depend on column letters such as:

```text
A
B
C
D
```

Instead, use header names.

---

# 55. Header-Based Column Mapping

Recommended implementation:

```dart
Map<String, int> buildHeaderIndex(List<Object?> headers) {
  final result = <String, int>{};

  for (var i = 0; i < headers.length; i++) {
    result[headers[i].toString()] = i;
  }

  return result;
}
```

Then:

```dart
row[headerIndex['invoice_id']]
row[headerIndex['customer_id']]
row[headerIndex['total_amount']]
```

This protects the app from accidental column movement.

---

# 56. Google Sheets Repository

Each repository should map to one primary sheet.

Example:

```text
InvoiceRepository
  ├── create()
  ├── update()
  ├── getById()
  ├── getByInvoiceNo()
  ├── list()
  ├── post()
  └── void()
```

Internally:

```text
InvoiceRepository
      ↓
GoogleSheetsDataSource
      ↓
INVOICES
INVOICE_ITEMS
```

---

# 57. Transactional Write Rules

A multi-sheet business transaction must be treated as one logical transaction.

Example invoice creation:

```text
1. Validate customer
2. Validate invoice items
3. Calculate totals
4. Create INVOICES row
5. Create INVOICE_ITEMS rows
6. Create JOURNAL_ENTRIES row
7. Create JOURNAL_LINES rows
8. Mark invoice POSTED
9. Write AUDIT_LOG
10. Write SYNC_LOG
```

Do not create a posted invoice without its accounting journal.

For a draft invoice, journal posting can wait until POSTED.

---

# 58. Update Rules

Do not silently overwrite accounting history.

For example:

```text
POSTED invoice
```

should generally not be directly edited for accounting fields.

Use:

```text
VOID
CREDIT ADJUSTMENT
REVERSAL
CORRECTION
```

according to the business accounting policy.

---

# 59. Delete Rules

Financial transactions should not be physically deleted after posting.

Use:

```text
status = VOID
```

and create reversal entries when required.

Master records can normally be deactivated:

```text
active = FALSE
```

instead of deleting historical records.

---

# 60. Referential Integrity

Before saving a row with a foreign key, validate that the referenced record exists.

Examples:

```text
INVOICES.customer_id
must exist in CUSTOMERS.customer_id
```

```text
INVOICE_ITEMS.invoice_id
must exist in INVOICES.invoice_id
```

```text
JOURNAL_LINES.account_id
must exist in CHART_OF_ACCOUNTS.account_id
```

```text
CAPITAL_TRANSACTIONS.shareholder_id
must exist in SHAREHOLDERS.shareholder_id
```

---

# 61. Required Validation Rules

## Invoice

```text
invoice_no unique
customer_id required
invoice_date required
at least one invoice item
quantity > 0
unit_price >= 0
VAT >= 0
total_amount >= 0
```

## Journal

```text
at least 2 lines
debit + credit lines exist
total_debit = total_credit
```

## Capital

```text
shareholder_id required
amount > 0
transaction_type required
```

## Asset

```text
purchase_cost >= 0
useful_life_months > 0
residual_value >= 0
residual_value <= purchase_cost
```

## Payroll

```text
employee_id required
gross_salary >= 0
deductions >= 0
net_salary >= 0
```

---

# 62. Recommended Google Drive Structure

Google Drive should hold generated documents, not structured accounting records.

Recommended:

```text
TPC Accounts/
├── Company/
├── Invoices/
│   ├── 2026/
│   └── 2027/
├── Quotations/
├── Expenses/
├── Assets/
├── Payroll/
│   ├── 2026/
│   └── 2027/
├── Reports/
└── Attachments/
```

Google Sheets stores:

```text
drive_file_id
file_name
entity_type
entity_id
document_type
```

---

# 63. Google Sheets Workbook Structure

Recommended workbook:

```text
TPC_ACCOUNTS_DATABASE
```

with these tabs:

```text
CONFIG
USERS
COMPANY
SHAREHOLDERS
CHART_OF_ACCOUNTS
CUSTOMERS
SUPPLIERS
PRODUCTS
TAX_CODES
BANK_ACCOUNTS
CASH_ACCOUNTS
QUOTATIONS
QUOTATION_ITEMS
INVOICES
INVOICE_ITEMS
PAYMENTS
PAYMENT_ALLOCATIONS
EXPENSES
EXPENSE_ITEMS
JOURNAL_ENTRIES
JOURNAL_LINES
CAPITAL_TRANSACTIONS
ASSETS
ASSET_DEPRECIATION
ASSET_DISPOSALS
EMPLOYEES
EMPLOYEE_BANK_ACCOUNTS
ATTENDANCE
OVERTIME
LEAVE
PAYROLL_RUNS
PAYROLL_ITEMS
PAYSLIPS
DOCUMENTS
AUDIT_LOG
SYNC_LOG
```

---

# 64. Primary Key Summary

| Sheet | Primary Key |
|---|---|
| CONFIG | config_id |
| USERS | user_id |
| COMPANY | company_id |
| SHAREHOLDERS | shareholder_id |
| CHART_OF_ACCOUNTS | account_id |
| CUSTOMERS | customer_id |
| SUPPLIERS | supplier_id |
| PRODUCTS | product_id |
| TAX_CODES | tax_code_id |
| BANK_ACCOUNTS | bank_account_id |
| CASH_ACCOUNTS | cash_account_id |
| QUOTATIONS | quotation_id |
| QUOTATION_ITEMS | quotation_item_id |
| INVOICES | invoice_id |
| INVOICE_ITEMS | invoice_item_id |
| PAYMENTS | payment_id |
| PAYMENT_ALLOCATIONS | allocation_id |
| EXPENSES | expense_id |
| EXPENSE_ITEMS | expense_item_id |
| JOURNAL_ENTRIES | journal_entry_id |
| JOURNAL_LINES | journal_line_id |
| CAPITAL_TRANSACTIONS | capital_transaction_id |
| ASSETS | asset_id |
| ASSET_DEPRECIATION | depreciation_id |
| ASSET_DISPOSALS | disposal_id |
| EMPLOYEES | employee_id |
| EMPLOYEE_BANK_ACCOUNTS | employee_bank_account_id |
| ATTENDANCE | attendance_id |
| OVERTIME | overtime_id |
| LEAVE | leave_id |
| PAYROLL_RUNS | payroll_run_id |
| PAYROLL_ITEMS | payroll_item_id |
| PAYSLIPS | payslip_id |
| DOCUMENTS | document_id |
| AUDIT_LOG | audit_id |
| SYNC_LOG | sync_id |

---

# 65. Foreign Key Summary

| Table | Foreign Key | References |
|---|---|---|
| SHAREHOLDERS | company_id | COMPANY |
| CUSTOMERS | receivable_account_id | CHART_OF_ACCOUNTS |
| SUPPLIERS | payable_account_id | CHART_OF_ACCOUNTS |
| PRODUCTS | tax_code_id | TAX_CODES |
| PRODUCTS | income_account_id | CHART_OF_ACCOUNTS |
| BANK_ACCOUNTS | ledger_account_id | CHART_OF_ACCOUNTS |
| CASH_ACCOUNTS | ledger_account_id | CHART_OF_ACCOUNTS |
| QUOTATIONS | customer_id | CUSTOMERS |
| QUOTATION_ITEMS | quotation_id | QUOTATIONS |
| QUOTATION_ITEMS | product_id | PRODUCTS |
| QUOTATION_ITEMS | tax_code_id | TAX_CODES |
| INVOICES | quotation_id | QUOTATIONS |
| INVOICES | customer_id | CUSTOMERS |
| INVOICE_ITEMS | invoice_id | INVOICES |
| INVOICE_ITEMS | product_id | PRODUCTS |
| INVOICE_ITEMS | tax_code_id | TAX_CODES |
| PAYMENTS | customer_id | CUSTOMERS |
| PAYMENTS | supplier_id | SUPPLIERS |
| PAYMENTS | bank_account_id | BANK_ACCOUNTS |
| PAYMENTS | cash_account_id | CASH_ACCOUNTS |
| PAYMENT_ALLOCATIONS | payment_id | PAYMENTS |
| PAYMENT_ALLOCATIONS | invoice_id | INVOICES |
| EXPENSES | supplier_id | SUPPLIERS |
| EXPENSES | category_account_id | CHART_OF_ACCOUNTS |
| EXPENSES | bank_account_id | BANK_ACCOUNTS |
| EXPENSES | cash_account_id | CASH_ACCOUNTS |
| EXPENSE_ITEMS | expense_id | EXPENSES |
| EXPENSE_ITEMS | account_id | CHART_OF_ACCOUNTS |
| JOURNAL_LINES | journal_entry_id | JOURNAL_ENTRIES |
| JOURNAL_LINES | account_id | CHART_OF_ACCOUNTS |
| JOURNAL_LINES | customer_id | CUSTOMERS |
| JOURNAL_LINES | supplier_id | SUPPLIERS |
| JOURNAL_LINES | shareholder_id | SHAREHOLDERS |
| JOURNAL_LINES | asset_id | ASSETS |
| CAPITAL_TRANSACTIONS | shareholder_id | SHAREHOLDERS |
| CAPITAL_TRANSACTIONS | asset_id | ASSETS |
| CAPITAL_TRANSACTIONS | bank_account_id | BANK_ACCOUNTS |
| CAPITAL_TRANSACTIONS | cash_account_id | CASH_ACCOUNTS |
| ASSETS | supplier_id | SUPPLIERS |
| ASSETS | contributed_by_shareholder_id | SHAREHOLDERS |
| ASSET_DEPRECIATION | asset_id | ASSETS |
| ASSET_DISPOSALS | asset_id | ASSETS |
| EMPLOYEES | bank_account_id | EMPLOYEE_BANK_ACCOUNTS |
| ATTENDANCE | employee_id | EMPLOYEES |
| OVERTIME | employee_id | EMPLOYEES |
| LEAVE | employee_id | EMPLOYEES |
| PAYROLL_RUNS | journal_entry_id | JOURNAL_ENTRIES |
| PAYROLL_ITEMS | payroll_run_id | PAYROLL_RUNS |
| PAYROLL_ITEMS | employee_id | EMPLOYEES |
| PAYSLIPS | payroll_run_id | PAYROLL_RUNS |
| PAYSLIPS | payroll_item_id | PAYROLL_ITEMS |
| PAYSLIPS | employee_id | EMPLOYEES |
| DOCUMENTS | uploaded_by | USERS |
| AUDIT_LOG | user_id | USERS |
| SYNC_LOG | user_id | USERS |

---

# 66. Flutter Data Layer Mapping

Recommended folder:

```text
lib/
├── core/
│   ├── auth/
│   ├── sync/
│   ├── sheets/
│   │   ├── google_sheets_client.dart
│   │   ├── sheet_schema.dart
│   │   ├── sheet_row_mapper.dart
│   │   └── sheet_repository.dart
│   └── errors/
│
├── features/
│   ├── billing/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── mappers/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── quotations/
│   ├── expenses/
│   ├── customers/
│   ├── suppliers/
│   ├── capital/
│   ├── assets/
│   ├── employees/
│   ├── attendance/
│   ├── payroll/
│   └── reports/
```

---

# 67. Model Mapping Pattern

Every model should have:

```text
fromSheetRow()
toSheetRow()
```

Example:

```dart
class CustomerSheetMapper {
  static Customer fromRow(
    Map<String, Object?> row,
  ) {
    return Customer(
      customerId: row['customer_id'] as String,
      customerCode: row['customer_code'] as String,
      name: row['name'] as String,
      companyName: row['company_name'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      taxRegistrationNo:
          row['tax_registration_no'] as String?,
      status: row['status'] as String,
    );
  }

  static List<Object?> toRow(Customer model) {
    return [
      model.customerId,
      model.customerCode,
      model.name,
      model.companyName,
      model.email,
      model.phone,
      model.taxRegistrationNo,
      model.status,
    ];
  }
}
```

The exact model fields should match the sheet contract.

---

# 68. Do Not Use Dynamic JSON for Core Fields

Avoid:

```dart
Map<String, dynamic> payload
```

as the only persistence structure.

Prefer strongly typed models:

```dart
Invoice
InvoiceItem
Customer
Payment
Expense
Asset
Shareholder
CapitalTransaction
JournalEntry
JournalLine
Employee
PayrollRun
```

Dynamic maps may be used temporarily by the Google Sheets API adapter, but they must be converted into typed models at the repository boundary.

---

# 69. Recommended Sync Strategy

## Create

```text
Flutter creates model
        ↓
Generate permanent ID
        ↓
Validate model
        ↓
Map to row
        ↓
Append row
        ↓
Write sync log
```

## Update

```text
Read record by ID
        ↓
Find row by ID
        ↓
Update only mapped columns
        ↓
Write audit record
        ↓
Write sync log
```

## Delete

For financial records:

```text
DO NOT physically delete
        ↓
VOID / CANCEL / DEACTIVATE
```

For non-financial master data:

```text
active = FALSE
```

when appropriate.

---

# 70. Finding Rows

Never rely permanently on:

```text
row 25
row 26
row 27
```

Rows can move.

Always find by primary key:

```text
invoice_id = INV-000001
```

Then update the corresponding row.

Recommended helper:

```dart
Future<int?> findRowById({
  required String sheetName,
  required String idColumn,
  required String id,
});
```

---

# 71. Google Sheets API Write Rules

When writing data:

1. Read/validate headers.
2. Confirm expected columns exist.
3. Map field names to column positions.
4. Validate data types.
5. Write scalar values.
6. Never serialize the complete model into one cell.
7. Confirm the write result.
8. Record SYNC_LOG.
9. Handle retries safely.

---

# 72. Idempotency

Every write operation must be safe against accidental retries.

Example:

```text
invoice_id = INV-000001
```

If a network request is retried, the application must not create:

```text
INV-000001
INV-000001
```

twice.

Before CREATE:

```text
check primary key
```

If it already exists:

```text
return existing record / handle as duplicate
```

---

# 73. Derived Values vs Stored Values

Prefer storing source values and calculating derived values.

### Store

```text
quantity
unit_price
discount_percent
tax_rate
```

### Calculate

```text
discount_amount
taxable_amount
tax_amount
line_total
```

Some calculated totals may also be stored on transaction headers for performance, but they must always be validated against the line records.

---

# 74. Accounting Source of Truth

For accounting reports:

```text
JOURNAL_ENTRIES
        +
JOURNAL_LINES
```

are the accounting source of truth for posted financial transactions.

Operational tables such as:

```text
INVOICES
EXPENSES
PAYMENTS
CAPITAL_TRANSACTIONS
ASSETS
PAYROLL_RUNS
```

contain business-level records and references to their accounting journals.

---

# 75. Report Source Mapping

| Report | Primary source |
|---|---|
| Dashboard | Journal + operational tables |
| Profit & Loss | JOURNAL_LINES + CHART_OF_ACCOUNTS |
| Balance Sheet | JOURNAL_LINES + CHART_OF_ACCOUNTS |
| Trial Balance | JOURNAL_LINES |
| General Ledger | JOURNAL_LINES |
| Cash Flow | Cash/Bank journal lines |
| Sales | INVOICES + INVOICE_ITEMS |
| Customer Statement | INVOICES + PAYMENT_ALLOCATIONS |
| Receivables | INVOICES + PAYMENT_ALLOCATIONS |
| Expenses | EXPENSES + EXPENSE_ITEMS |
| Payables | Supplier transactions + payments |
| Capital | CAPITAL_TRANSACTIONS + equity journals |
| Assets | ASSETS + ASSET_DEPRECIATION |
| VAT | INVOICES + EXPENSES + TAX_CODES |
| Payroll | PAYROLL_RUNS + PAYROLL_ITEMS |
| Attendance | ATTENDANCE |
| Overtime | OVERTIME |

---

# 76. Data Integrity Checks

The application should run these checks before important reports.

## Journal balance

```text
SUM(debit) = SUM(credit)
```

## Balance sheet

```text
Assets = Liabilities + Equity
```

## Ownership

```text
SUM(active shareholder ownership) = 100%
```

## Invoice

```text
invoice total = SUM(invoice item totals)
```

## Payment

```text
allocated payment <= payment amount
```

## Invoice balance

```text
balance_due >= 0
```

unless approved credit-note/overpayment functionality is implemented.

## Asset

```text
book_value >= residual_value
```

---

# 77. Performance Rules

Google Sheets is not a high-scale relational database.

For this project:

- Keep sheets structured and indexed by stable IDs.
- Avoid thousands of unnecessary formulas copied across entire columns.
- Avoid deeply nested spreadsheet formulas for core accounting logic.
- Calculate complex reports in Flutter or Apps Script from structured rows.
- Cache frequently used master data locally in Flutter.
- Batch Google Sheets API reads/writes where possible.
- Do not read the entire workbook for every screen.
- Use incremental sync where possible.

---

# 78. Security Rules

Google Sheets must not be treated as a public database.

Required:

```text
Google OAuth
Role-based application permissions
Restricted workbook access
Restricted Drive access
Audit logging
```

Never store:

```text
Google OAuth client secrets
refresh tokens
bank passwords
OTP
card CVV
payment passwords
API secret keys
```

inside normal business sheets.

---

# 79. Migration From Current JSON Payload Storage

The current database should be migrated rather than simply abandoned.

Recommended migration:

```text
CURRENT JSON SHEET
        ↓
JSON parser
        ↓
Typed Dart model
        ↓
Field mapper
        ↓
Dedicated sheet rows
        ↓
Validation
        ↓
Reconciliation
        ↓
Old JSON data archived
```

## Migration sequence

### Step 1

Create all new sheets.

### Step 2

Create fixed header rows.

### Step 3

Import master data:

```text
COMPANY
USERS
SHAREHOLDERS
CHART_OF_ACCOUNTS
CUSTOMERS
SUPPLIERS
PRODUCTS
TAX_CODES
BANK_ACCOUNTS
CASH_ACCOUNTS
EMPLOYEES
```

### Step 4

Import transactional data:

```text
QUOTATIONS
QUOTATION_ITEMS
INVOICES
INVOICE_ITEMS
PAYMENTS
PAYMENT_ALLOCATIONS
EXPENSES
EXPENSE_ITEMS
CAPITAL_TRANSACTIONS
ASSETS
```

### Step 5

Rebuild accounting journals.

### Step 6

Validate:

```text
Invoice totals
Payment balances
Capital balances
Asset balances
Trial balance
Balance sheet
```

### Step 7

Compare old and new totals.

### Step 8

Only after reconciliation, switch the application to the new schema.

---

# 80. Migration Reconciliation

Before disabling the old JSON system, compare:

```text
Total sales
Total VAT
Total expenses
Total receipts
Total payments
Total capital
Total withdrawals
Total assets
Total depreciation
Total receivables
Total payables
Total payroll
```

The values should reconcile.

Example:

```text
Old JSON total sales = AED 250,000
New INVOICES total sales = AED 250,000
Difference = AED 0
```

Do not complete migration if material differences remain unexplained.

---

# 81. Recommended Sheet Header Generation

The Flutter application should have one schema definition per sheet.

Example:

```dart
class InvoiceSheetSchema {
  static const sheetName = 'INVOICES';

  static const columns = [
    'invoice_id',
    'invoice_no',
    'quotation_id',
    'customer_id',
    'invoice_date',
    'due_date',
    'currency_code',
    'subtotal',
    'discount_total',
    'taxable_amount',
    'vat_amount',
    'total_amount',
    'amount_paid',
    'balance_due',
    'notes',
    'terms',
    'status',
    'journal_entry_id',
    'created_at',
    'created_by',
    'updated_at',
    'updated_by',
  ];
}
```

The same pattern should exist for every sheet.

---

# 82. Final Database Principle

TPC Accounts should use this architecture:

```text
                 FLUTTER
                    │
          Strongly Typed Models
                    │
               Repository
                    │
             Sheet Mapper
                    │
          Google Sheets API
                    │
       ┌────────────┴────────────┐
       │                         │
  MASTER DATA              TRANSACTIONS
       │                         │
Customers                  Invoices
Suppliers                  Payments
Employees                  Expenses
Products                   Capital
Accounts                   Assets
Shareholders               Payroll
       │                         │
       └────────────┬────────────┘
                    │
             JOURNAL ENTRIES
                    │
              JOURNAL LINES
                    │
              ACCOUNTING
                    │
       ┌────────────┼────────────┐
       │            │            │
      P&L      Balance Sheet   Cash Flow
```

## Non-negotiable implementation rule

> **Do not store core TPC Accounts business data as JSON payloads in Google Sheets. Every important field must have its own dedicated column/cell, with stable primary keys and explicit foreign-key relationships.**

This schema is the database contract between Flutter and Google Sheets. Any future feature added to TPC Accounts must follow the same rule.
