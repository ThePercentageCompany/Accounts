# TPC Accounts — Change Request & New Module Specification

**Project:** The Percentage Company (TPC) — Business Accounts & Management System  
**Company:** The Percentage Company FZ LLC  
**Document Type:** Product / Development Change Specification  
**Version:** 1.0  
**Date:** 11 September 2026  

---

## 1. Purpose

This document defines new accounting functionality to be added to **TPC Accounts**.

The main changes are:

1. Add a complete **Capital & Equity** module.
2. Add a complete **Assets** module.
3. Separate shareholder capital from business income.
4. Connect capital contributions to Bank, Cash, Assets, and the Balance Sheet.
5. Support shareholder asset contributions.
6. Support shareholder loans separately from capital.
7. Add a basic double-entry accounting structure.
8. Add a Balance Sheet report.
9. Add automatic journal entries for accounting transactions.
10. Ensure Profit & Loss is not affected by capital contributions or normal fixed-asset purchases.

---

# 2. Updated Accounts Structure

TPC Accounts should use the following high-level accounting groups:

```text
ACCOUNTS

├── Assets
│   ├── Cash in Hand
│   ├── Bank Accounts
│   ├── Accounts Receivable
│   ├── Fixed Assets
│   │   ├── Computers & IT Equipment
│   │   ├── Office Equipment
│   │   ├── Furniture & Fixtures
│   │   ├── Vehicles
│   │   ├── Machinery
│   │   ├── Mobile Phones
│   │   ├── Cameras & Photography Equipment
│   │   ├── Software / Licences
│   │   ├── Leasehold Improvements
│   │   └── Other Fixed Assets
│   └── Other Assets
│
├── Liabilities
│   ├── Accounts Payable
│   ├── Supplier Bills Payable
│   ├── Loans
│   ├── Shareholder Loans
│   └── Other Liabilities
│
├── Equity
│   ├── Shareholder Capital
│   ├── Additional Capital
│   ├── Retained Earnings
│   ├── Current Year Profit / Loss
│   └── Equity Adjustments
│
├── Income
│   ├── Website Development
│   ├── E-commerce Management
│   ├── Graphic Design
│   ├── Digital Marketing
│   ├── Software Development
│   ├── Consulting
│   └── Other Income
│
└── Expenses
    ├── Rent
    ├── Salaries
    ├── Utilities
    ├── Software / SaaS
    ├── Marketing
    ├── Fuel / Travel
    ├── Office Expenses
    ├── Repairs & Maintenance
    ├── Depreciation
    └── Other Expenses
```

---

# 3. Core Accounting Rule

The system must always maintain the accounting equation:

```text
Assets = Liabilities + Equity
```

Every accounting transaction should generate balanced debit and credit entries.

Example:

```text
Debit Total = Credit Total
```

A transaction must not be posted if the journal entry is not balanced.

---

# 4. Capital & Equity Module

## 4.1 Module Location

Add the following menu:

```text
Accounts
└── Capital & Equity
    ├── Overview
    ├── Shareholders
    ├── Capital Contributions
    ├── Shareholder Loans
    └── Equity Ledger
```

---

## 4.2 Capital & Equity Dashboard

Display the following KPI cards:

- Company Agreed Capital
- Total Capital Invested
- Outstanding Capital
- Asset Contributions
- Shareholder Loans
- Current Company Equity

Example:

```text
Company Agreed Capital        AED 100,000
Total Capital Invested         AED 80,000
Outstanding Capital            AED 20,000
Asset Contributions            AED 15,000
Shareholder Loans               AED 5,000
Current Company Equity         AED 97,000
```

---

## 4.3 Shareholder Record

Each shareholder should support:

| Field | Type |
|---|---|
| Shareholder ID | Auto-generated |
| Full Name | Text |
| Ownership Percentage | Percentage |
| Agreed Capital | AED |
| Cash Invested | AED |
| Asset Contributions | AED |
| Total Capital Invested | Calculated |
| Outstanding Capital | Calculated |
| Shareholder Loan Balance | Calculated |
| Status | Active / Inactive |
| Notes | Text |

### Calculation

```text
Total Capital Invested =
Cash Contributions
+ Asset Contributions
+ Other Capital Contributions
```

```text
Outstanding Capital =
Agreed Capital - Total Capital Invested
```

---

# 5. Capital Transaction Types

The system should support the following transaction types:

## 5.1 Capital Contribution

Used when a shareholder permanently invests money into the company.

Example:

```text
Partner A invests AED 10,000 into Company Bank.
```

Journal:

```text
Dr Bank Account                 AED 10,000
Cr Partner A Capital            AED 10,000
```

### Important

Capital contributions must **NOT** appear as business income.

They must not increase:

- Sales
- Revenue
- Gross Profit
- Net Profit

---

## 5.2 Cash Capital Contribution

Form fields:

```text
Transaction Type      Capital Contribution
Shareholder           Partner A
Amount                AED 10,000
Received Into         Bank / Cash
Date                  11 Sep 2026
Reference             Optional
Attachment            Optional
Notes                 Optional
```

If received in Bank:

```text
Dr Bank
Cr Shareholder Capital
```

If received in Cash:

```text
Dr Cash in Hand
Cr Shareholder Capital
```

---

## 5.3 Asset Capital Contribution

A shareholder may contribute an asset instead of cash.

Example:

```text
Partner A contributes a laptop valued at AED 6,000.
```

Journal:

```text
Dr Computer Equipment Asset     AED 6,000
Cr Partner A Capital            AED 6,000
```

No Bank or Cash movement occurs.

The transaction must appear in:

- Capital & Equity → Partner A
- Asset Register
- General Ledger
- Balance Sheet

It must not appear as income.

---

## 5.4 Additional Capital

Used when an existing shareholder injects additional permanent capital.

Journal:

```text
Dr Bank / Cash / Asset
Cr Shareholder Capital
```

---

## 5.5 Capital Withdrawal

Used only when approved capital is formally returned to the shareholder.

Example:

```text
Company returns AED 5,000 capital to Partner A.
```

Journal:

```text
Dr Partner A Capital             AED 5,000
Cr Bank                           AED 5,000
```

Capital withdrawal must not be treated as an expense.

---

# 6. Shareholder Loans

Shareholder loans must be separate from capital.

Use a shareholder loan when money is expected to be repaid to the shareholder.

Example:

```text
Partner A gives company AED 20,000 temporarily.
```

Journal:

```text
Dr Bank                           AED 20,000
Cr Shareholder Loan - Partner A  AED 20,000
```

This appears under:

```text
Liabilities
└── Shareholder Loans
```

It must not increase shareholder capital.

---

## 6.1 Loan Repayment

Example:

```text
Company repays AED 5,000.
```

Journal:

```text
Dr Shareholder Loan - Partner A   AED 5,000
Cr Bank                            AED 5,000
```

---

# 7. Assets Module

## 7.1 Module Location

Add:

```text
Accounts
└── Assets
    ├── Asset Overview
    ├── Asset Register
    ├── Add Asset
    ├── Depreciation
    ├── Maintenance
    └── Asset Disposal
```

---

# 8. Asset Dashboard

Show KPI cards:

- Total Original Cost
- Current Book Value
- Accumulated Depreciation
- Assets Added This Year
- Assets Under Maintenance
- Disposed Assets

Example:

```text
Original Asset Cost           AED 120,000
Current Book Value            AED 104,500
Accumulated Depreciation       AED 15,500
Assets Added This Year         AED 35,000
```

---

# 9. Asset Register

Table example:

| Asset | Category | Cost | Purchase Date | Book Value | Status |
|---|---|---:|---|---:|---|
| MacBook Pro | Computers | AED 7,500 | 10 Sep 2026 | AED 7,500 | Active |
| Office Printer | Equipment | AED 1,200 | 01 Aug 2026 | AED 1,150 | Active |
| Office Furniture | Furniture | AED 5,000 | 15 Jul 2026 | AED 4,750 | Active |
| Company Vehicle | Vehicles | AED 65,000 | 20 Jan 2026 | AED 58,000 | Active |

---

# 10. Add Asset Form

The Add Asset screen should include:

```text
Asset Name
Asset Category
Asset Code
Acquisition Type
Purchase / Contribution Date
Purchase Cost / Asset Value
VAT
Supplier
Payment Account
Shareholder
Asset Location
Assigned Employee
Serial Number
Warranty Expiry
Depreciation Method
Useful Life
Residual Value
Invoice / Receipt Attachment
Warranty Attachment
Notes
```

---

# 11. Acquisition Type

Add the following field:

```text
Acquisition Type
```

Options:

```text
Company Purchase
Shareholder Contribution
Opening Balance Asset
Transferred to Company
Other
```

The form must dynamically change based on acquisition type.

---

# 12. Company Purchase Asset

Example:

TPC buys a laptop for AED 5,000 from the company bank.

Journal:

```text
Dr Computer Equipment          AED 5,000
Cr Bank                        AED 5,000
```

The asset purchase must not immediately become a normal operating expense when classified as a fixed asset.

The value moves from one asset account to another:

```text
Bank ↓
Fixed Asset ↑
```

Total assets remain unchanged before considering VAT or other transaction effects.

---

# 13. Asset Purchased With Cash

Example:

```text
Laptop purchase: AED 5,000
Payment: Cash in Hand
```

Journal:

```text
Dr Computer Equipment          AED 5,000
Cr Cash in Hand                AED 5,000
```

---

# 14. Asset Purchased on Credit

Example:

TPC receives equipment worth AED 8,000 from a supplier but has not paid yet.

Journal:

```text
Dr Office Equipment            AED 8,000
Cr Accounts Payable            AED 8,000
```

When paid later:

```text
Dr Accounts Payable            AED 8,000
Cr Bank                        AED 8,000
```

---

# 15. Shareholder-Contributed Asset

Example:

Partner A contributes a company vehicle worth AED 40,000.

Journal:

```text
Dr Company Vehicle             AED 40,000
Cr Partner A Capital           AED 40,000
```

The system should automatically update:

```text
Asset Register
Partner A Capital
Total Invested Capital
Balance Sheet
General Ledger
```

No Income or Expense transaction should be created.

---

# 16. Depreciation

Support at minimum:

```text
Straight Line Depreciation
```

Future option:

```text
Reducing Balance
```

---

## 16.1 Straight Line Calculation

Formula:

```text
Depreciable Amount =
Original Cost - Residual Value
```

```text
Annual Depreciation =
Depreciable Amount / Useful Life
```

```text
Monthly Depreciation =
Annual Depreciation / 12
```

Example:

```text
Asset Cost             AED 5,000
Residual Value           AED 500
Useful Life              3 Years

Depreciable Amount      AED 4,500
Annual Depreciation     AED 1,500
Monthly Depreciation      AED 125
```

Journal each month:

```text
Dr Depreciation Expense            AED 125
Cr Accumulated Depreciation        AED 125
```

---

# 17. Asset Detail Screen

Example layout:

```text
MacBook Pro 14"

Asset ID: AST-2026-00001
Status: Active

Original Cost                  AED 7,500
Accumulated Depreciation         AED 625
Current Book Value             AED 6,875

Purchase Date                  10 Apr 2026
Acquisition Type               Company Purchase
Useful Life                    3 Years
Depreciation Method            Straight Line

Assigned To                    Employee Name
Location                       Main Office
Supplier                       Supplier Name
Serial Number                  XXXXX
Warranty Expiry                10 Apr 2027

Documents
- Purchase Invoice.pdf
- Warranty.pdf

Asset History
10 Apr 2026    Purchased                AED 7,500
30 Apr 2026    Depreciation               AED 208.33
31 May 2026    Depreciation               AED 208.33
30 Jun 2026    Depreciation               AED 208.34
```

---

# 18. Asset Actions

Support:

```text
Edit Asset
Assign to Employee
Transfer Location
Record Maintenance
Record Repair
Mark Damaged
Mark Lost
Sell Asset
Dispose Asset
Upload Document
View Ledger
```

---

# 19. Asset Disposal

When disposing of an asset, collect:

```text
Disposal Date
Disposal Type
Sale Price
Payment Account
Buyer
Reason
Attachment
Notes
```

Disposal types:

```text
Sold
Scrapped
Lost
Damaged
Donated
Other
```

The accounting system should calculate any gain or loss on disposal.

---

# 20. Balance Sheet

Add a new report:

```text
Reports
└── Balance Sheet
```

Suggested structure:

```text
BALANCE SHEET
As of 11 September 2026

ASSETS

Current Assets
  Cash in Hand                         AED 7,500
  Bank Accounts                       AED 51,000
  Accounts Receivable                 AED 12,000

Fixed Assets
  Computers & IT Equipment             AED 6,000
  Vehicles                            AED 40,000
  Less: Accumulated Depreciation      (AED 2,000)

TOTAL ASSETS                         AED 114,500


LIABILITIES

Accounts Payable                       AED 5,000
Shareholder Loans                      AED 2,500

TOTAL LIABILITIES                      AED 7,500


EQUITY

Partner A Capital                     AED 60,000
Partner B Capital                     AED 30,000
Retained Earnings                      AED 7,000
Current Year Profit                   AED 10,000

TOTAL EQUITY                         AED 107,000


TOTAL LIABILITIES + EQUITY           AED 114,500
```

The system must verify:

```text
Total Assets = Total Liabilities + Total Equity
```

If not balanced, display an accounting warning.

---

# 21. Profit & Loss Rules

Capital transactions must not appear in Profit & Loss.

Do not include:

```text
Shareholder Capital Contribution
Additional Capital
Shareholder Asset Contribution
Capital Withdrawal
Shareholder Loan
Shareholder Loan Repayment
Fixed Asset Purchase
```

Profit & Loss should contain only relevant income and expense accounts.

Example:

```text
INCOME

Website Development          AED 20,000
E-commerce Management        AED 10,000
Graphic Design                AED  5,000

TOTAL INCOME                  AED 35,000


EXPENSES

Rent                          AED  6,000
Salary                        AED  7,000
Marketing                     AED  2,000
Utilities                     AED  1,000
Depreciation                  AED    500

TOTAL EXPENSES                AED 16,500


NET PROFIT                    AED 18,500
```

---

# 22. Dashboard Changes

Update the Executive Dashboard.

Current financial KPI area should show:

```text
Business Income
Business Expenses
Net Profit

Cash & Bank
Accounts Receivable
Accounts Payable

Total Assets
Shareholder Capital
Shareholder Loans
Current Equity
```

Do not combine shareholder capital with business income.

---

# 23. Cash & Bank Behaviour

Cash and Bank balances should be derived from posted financial transactions.

Examples affecting Bank:

```text
Customer Payment                 +
Capital Contribution             +
Shareholder Loan                 +
Asset Sale                       +

Supplier Payment                 -
Expense Payment                  -
Fixed Asset Purchase             -
Capital Withdrawal               -
Shareholder Loan Repayment       -
```

---

# 24. General Ledger

Add a General Ledger capability.

Suggested menu:

```text
Accounts
└── General Ledger
```

Each account should contain:

```text
Date
Journal Number
Reference
Description
Debit
Credit
Running Balance
Source Module
Source Record ID
```

Example:

```text
BANK ACCOUNT

11 Sep 2026
JRN-2026-000045
Capital contribution - Partner A

Debit       AED 10,000
Credit      AED 0
Balance     AED 50,000
```

---

# 25. Journal Entry Model

Every posted accounting transaction should create a journal.

Example structure:

```text
Journal
- journalId
- journalNumber
- transactionDate
- sourceType
- sourceId
- description
- status
- createdBy
- createdAt
- updatedAt
```

Journal line:

```text
JournalLine
- lineId
- journalId
- accountId
- accountName
- debit
- credit
- shareholderId
- customerId
- supplierId
- assetId
- notes
```

Validation:

```text
SUM(debit) == SUM(credit)
```

---

# 26. Suggested Google Sheets Tabs

Add / update the Google Sheets database structure.

Recommended tabs:

```text
Accounts
Journals
JournalLines
Shareholders
CapitalTransactions
ShareholderLoans
Assets
AssetDepreciation
AssetMaintenance
AssetDisposals
BankTransactions
CashTransactions
Invoices
InvoicePayments
Customers
Suppliers
Expenses
Income
Employees
Attendance
Payroll
Settings
AuditLog
```

---

# 27. Accounts Sheet

Suggested fields:

```text
account_id
account_code
account_name
account_type
account_subtype
parent_account_id
currency
opening_balance
current_balance
is_system_account
is_active
created_at
updated_at
```

Account types:

```text
ASSET
LIABILITY
EQUITY
INCOME
EXPENSE
```

---

# 28. Shareholders Sheet

Suggested fields:

```text
shareholder_id
full_name
ownership_percentage
agreed_capital
cash_capital
asset_capital
total_capital
outstanding_capital
loan_balance
status
notes
created_at
updated_at
```

---

# 29. Capital Transactions Sheet

Suggested fields:

```text
capital_transaction_id
shareholder_id
transaction_date
transaction_type
contribution_type
amount
asset_id
bank_account_id
cash_account_id
reference_number
attachment_drive_url
journal_id
notes
created_by
created_at
updated_at
```

Transaction types:

```text
CAPITAL_CONTRIBUTION
ADDITIONAL_CAPITAL
CAPITAL_WITHDRAWAL
EQUITY_ADJUSTMENT
```

Contribution types:

```text
CASH
BANK
ASSET
OTHER
```

---

# 30. Assets Sheet

Suggested fields:

```text
asset_id
asset_code
asset_name
category
acquisition_type
purchase_date
original_cost
vat_amount
supplier_id
payment_account_id
shareholder_id
location
assigned_employee_id
serial_number
warranty_expiry
depreciation_method
useful_life_months
residual_value
accumulated_depreciation
book_value
status
invoice_drive_url
warranty_drive_url
notes
journal_id
created_at
updated_at
```

---

# 31. Asset Status

Supported values:

```text
ACTIVE
UNDER_MAINTENANCE
DAMAGED
LOST
SOLD
DISPOSED
```

---

# 32. Shareholder Loan Sheet

Suggested fields:

```text
loan_id
shareholder_id
transaction_date
transaction_type
amount
payment_account_id
reference_number
attachment_drive_url
journal_id
notes
created_at
updated_at
```

Transaction types:

```text
LOAN_RECEIVED
LOAN_REPAYMENT
LOAN_ADJUSTMENT
```

---

# 33. Automated Transaction Rules

The accounting engine should automatically generate entries based on source actions.

## Invoice Created

If accrual accounting is enabled:

```text
Dr Accounts Receivable
Cr Sales / Service Income
Cr VAT Payable
```

## Customer Payment Received

```text
Dr Bank / Cash
Cr Accounts Receivable
```

## Normal Expense Paid

```text
Dr Expense
Cr Bank / Cash
```

## Supplier Bill Created

```text
Dr Expense / Asset
Cr Accounts Payable
```

## Supplier Bill Paid

```text
Dr Accounts Payable
Cr Bank / Cash
```

## Capital Contribution

```text
Dr Bank / Cash
Cr Shareholder Capital
```

## Asset Capital Contribution

```text
Dr Fixed Asset
Cr Shareholder Capital
```

## Shareholder Loan Received

```text
Dr Bank / Cash
Cr Shareholder Loan
```

## Fixed Asset Purchased

```text
Dr Fixed Asset
Cr Bank / Cash / Accounts Payable
```

## Depreciation

```text
Dr Depreciation Expense
Cr Accumulated Depreciation
```

---

# 34. User Interface Navigation

Recommended sidebar:

```text
Dashboard

Sales
├── Customers
├── Quotations
├── Invoices
└── Receipts

Purchases & Expenses
├── Suppliers
├── Supplier Bills
├── Expenses
└── Payments

Banking
├── Bank Accounts
├── Cash in Hand
└── Transfers

Accounts
├── Chart of Accounts
├── General Ledger
├── Assets
├── Capital & Equity
└── Journal Entries

HR & Payroll
├── Employees
├── Attendance
├── Payroll
└── Payslips

Reports
├── Profit & Loss
├── Balance Sheet
├── Cash Flow
├── Receivables
├── Payables
├── Capital Report
├── Asset Register
└── Depreciation Report

Settings
├── Company
├── Banking
├── Tax
├── Shareholders
└── Google Workspace
```

---

# 35. Capital & Equity UI Example

```text
Capital & Equity

[ Agreed Capital ] [ Invested Capital ] [ Outstanding ] [ Current Equity ]

AED 100,000         AED 80,000           AED 20,000      AED 97,000


SHAREHOLDERS

Partner A
Ownership                60%
Agreed Capital           AED 60,000
Cash Invested            AED 34,000
Asset Contribution       AED  6,000
Total Invested           AED 40,000
Outstanding              AED 20,000


Partner B
Ownership                40%
Agreed Capital           AED 40,000
Cash Invested            AED 40,000
Asset Contribution       AED      0
Total Invested           AED 40,000
Outstanding              AED      0


RECENT CAPITAL TRANSACTIONS

11 Sep 2026    Partner A    Cash Contribution     + AED 10,000
08 Sep 2026    Partner A    Asset Contribution    + AED  6,000
01 Sep 2026    Partner B    Bank Contribution     + AED 20,000
```

---

# 36. Add Capital Transaction UI

```text
Add Capital Transaction

Transaction Type
[ Capital Contribution ▼ ]

Shareholder
[ Select Shareholder ▼ ]

Contribution Type
[ Bank ▼ ]

Amount
AED [ 10,000.00 ]

Received Into
[ Emirates NBD - Main Account ▼ ]

Transaction Date
[ 11 Sep 2026 ]

Reference Number
[ __________________ ]

Attachment
[ Upload Receipt ]

Notes
[ ____________________________ ]

[ Cancel ]                    [ Save & Post ]
```

If Contribution Type = Asset:

Hide:

```text
Received Into Bank/Cash
```

Show:

```text
Select Existing Asset
or
Create New Asset
```

---

# 37. Add Asset UI

```text
Add New Asset

Asset Name
[ MacBook Pro 14" ]

Category
[ Computers & IT Equipment ▼ ]

Acquisition Type
[ Company Purchase ▼ ]

Asset Code
[ Auto: AST-2026-00001 ]

Date
[ 11 Sep 2026 ]

Value / Cost
AED [ 7,500.00 ]

VAT
[ 5% ]

Supplier
[ Select Supplier ▼ ]

Payment From
[ Bank Account ▼ ]

Location
[ Main Office ▼ ]

Assigned To
[ Employee ▼ ]

Serial Number
[ _________________ ]

Warranty Expiry
[ _________________ ]

Depreciation Method
[ Straight Line ▼ ]

Useful Life
[ 36 Months ]

Residual Value
AED [ 500.00 ]

Attachments
[ Invoice ] [ Warranty ]

Notes
[ __________________________ ]

[ Cancel ]                    [ Save & Post ]
```

If Acquisition Type = Shareholder Contribution:

Hide:

```text
Supplier
Payment From
```

Show:

```text
Contributed By
[ Shareholder ▼ ]

Approved Asset Value
AED [ _________ ]
```

---

# 38. Permissions

Recommended role permissions:

## Admin

Full access.

## Accountant

Can:

- Create/edit/post accounting transactions
- Manage assets
- Manage capital entries
- Manage supplier bills
- Run financial reports

Cannot:

- Change ownership percentages without Admin approval

## HR

Can:

- Employees
- Attendance
- Payroll

Cannot:

- Capital
- Assets financial values
- General Ledger unless explicitly granted

## Employee

Limited self-service access.

---

# 39. Audit Trail

All sensitive accounting changes must be logged.

Track:

```text
User
Date / Time
Action
Module
Record ID
Old Value
New Value
Reason
IP / Device if available
```

Important actions:

```text
Capital added
Capital edited
Capital deleted / reversed
Asset added
Asset value changed
Asset disposed
Journal posted
Journal reversed
Ownership percentage changed
Opening balance changed
```

Posted accounting records should preferably be reversed instead of permanently deleted.

---

# 40. Recommended Posting Status

Financial documents should use:

```text
DRAFT
POSTED
REVERSED
VOID
```

Only `POSTED` records should affect accounting balances and reports.

---

# 41. Important Business Rules

1. Capital investment is not income.
2. Capital withdrawal is not an expense.
3. Shareholder loan is a liability, not equity.
4. Shareholder asset contribution increases both Assets and Equity.
5. Purchasing a fixed asset normally moves value from Bank/Cash to Fixed Assets.
6. Depreciation is recorded as an expense over time.
7. All posted transactions must create balanced journal entries.
8. Balance Sheet must always satisfy:

```text
Assets = Liabilities + Equity
```

9. Profit & Loss should contain only Income and Expenses.
10. Asset and capital transactions must be visible in their originating module and the General Ledger.

---

# 42. Reports to Add

Add these reports:

```text
Balance Sheet
General Ledger
Trial Balance
Capital & Equity Report
Shareholder Contribution Report
Shareholder Loan Report
Asset Register
Depreciation Schedule
Asset Disposal Report
```

---

# 43. Trial Balance

Recommended columns:

```text
Account Code
Account Name
Debit Balance
Credit Balance
```

Bottom validation:

```text
Total Debits = Total Credits
```

If they do not match, display:

```text
Accounting imbalance detected.
Please review posted journal entries.
```

---

# 44. Updated Dashboard Logic

Dashboard financial cards should be calculated from the accounting ledger rather than independent manually stored totals wherever practical.

Recommended cards:

```text
Total Income
Total Expenses
Net Profit
Cash & Bank
Receivables
Payables
Total Assets
Total Liabilities
Shareholder Capital
Current Equity
```

---

# 45. Future-Ready Requirements

Design the accounting core so future modules can be added without changing the core ledger.

Possible future modules:

```text
UAE VAT Return
Corporate Tax Support
Bank Reconciliation
Purchase Orders
Inventory
Recurring Invoices
Recurring Expenses
Multi-currency
Project Profitability
Cost Centres
Departments
Budgets
Director / Shareholder Current Accounts
```

---

# 46. Suggested Flutter Feature Structure

```text
lib/
└── features/
    ├── accounting/
    │   ├── domain/
    │   │   ├── account.dart
    │   │   ├── journal.dart
    │   │   ├── journal_line.dart
    │   │   └── accounting_engine.dart
    │   ├── data/
    │   │   ├── accounting_repository.dart
    │   │   └── google_sheets_accounting_repository.dart
    │   └── presentation/
    │       ├── chart_of_accounts/
    │       ├── general_ledger/
    │       ├── journal_entries/
    │       └── balance_sheet/
    │
    ├── capital/
    │   ├── domain/
    │   ├── data/
    │   └── presentation/
    │       ├── capital_dashboard/
    │       ├── shareholder_detail/
    │       └── capital_transaction_form/
    │
    └── assets/
        ├── domain/
        │   ├── asset.dart
        │   ├── depreciation.dart
        │   └── asset_disposal.dart
        ├── data/
        │   └── asset_repository.dart
        └── presentation/
            ├── asset_dashboard/
            ├── asset_register/
            ├── asset_form/
            └── asset_detail/
```

---

# 47. Acceptance Criteria

The implementation is complete when all of the following work:

- [ ] Admin can add shareholders.
- [ ] Admin can set ownership percentages and agreed capital.
- [ ] Capital contribution can be received into Bank.
- [ ] Capital contribution can be received into Cash.
- [ ] Shareholder can contribute an Asset.
- [ ] Asset contribution automatically increases shareholder capital.
- [ ] Shareholder loan can be recorded separately.
- [ ] Loan repayment decreases shareholder loan liability.
- [ ] Asset can be purchased from Bank.
- [ ] Asset can be purchased from Cash.
- [ ] Asset can be purchased on supplier credit.
- [ ] Asset register shows book value.
- [ ] Straight-line depreciation works.
- [ ] Depreciation creates an expense journal.
- [ ] Capital never appears as business income.
- [ ] Capital withdrawal never appears as business expense.
- [ ] Fixed asset purchase does not immediately reduce profit.
- [ ] Balance Sheet is generated correctly.
- [ ] General Ledger shows all posted accounting entries.
- [ ] Trial Balance debit and credit totals match.
- [ ] Dashboard displays Total Assets and Shareholder Capital.
- [ ] All posted journal entries are balanced.
- [ ] Attachments can be stored in Google Drive.
- [ ] Google Sheets data stays synchronized with local storage.
- [ ] Accounting changes are stored in the Audit Log.

---

# 48. Final Accounting Example

Assume:

```text
Partner A invests cash                    AED 50,000
Partner A contributes a laptop            AED  6,000
Company earns service income              AED 10,000
Company pays operating expenses           AED  3,000
```

Before depreciation, simplified totals:

```text
Business Income                  AED 10,000
Business Expenses                AED  3,000
Net Profit                       AED  7,000

Shareholder Capital              AED 56,000
```

Capital does not change the AED 7,000 business profit.

The system should always keep these concepts separate:

```text
Company Revenue
Company Expenses
Company Profit

Company Assets
Company Liabilities

Shareholder Capital
Shareholder Loans
Company Equity
```

---

## End of Specification

This document should be used as the implementation specification for adding **Assets, Capital & Equity, Balance Sheet, General Ledger, and accounting integration** to the TPC Accounts project.
