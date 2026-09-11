# TPC Accounts — Reports Module Specification

## 1. Purpose

The Reports module converts accounting, sales, expense, asset, capital, HR, and payroll records into clear management and statutory reports for The Percentage Company FZ LLC.

All financial reports must use double-entry ledger data as the source of truth. Dashboard totals must never be calculated independently from manually entered summary values.

## 2. Navigation

```text
Reports
├── Financial Overview
├── Profit & Loss
├── Balance Sheet
├── Cash Flow Statement
├── Trial Balance
├── General Ledger
├── Account Transactions
├── Receivables
│   ├── Customer Balances
│   └── Receivables Aging
├── Payables
│   ├── Supplier Balances
│   └── Payables Aging
├── Sales & VAT
│   ├── Sales by Customer
│   ├── Sales by Service
│   ├── VAT Summary
│   └── VAT Transaction Detail
├── Expenses
│   ├── Expenses by Category
│   └── Expenses by Supplier
├── Assets
│   ├── Asset Register
│   ├── Asset Valuation
│   ├── Depreciation Schedule
│   └── Asset Disposal
├── Capital & Equity
│   ├── Shareholder Capital
│   ├── Capital Transactions
│   ├── Shareholder Loans
│   └── Equity Statement
├── Bank & Cash
│   ├── Bank Movement
│   └── Cash Movement
└── HR & Payroll
    ├── Attendance Summary
    ├── Payroll Summary
    ├── Employee Salary Detail
    └── Leave & Overtime
```

## 3. Reports Landing Page

### 3.1 Summary cards

- Revenue
- Total Expenses
- Net Profit or Loss
- Cash and Bank Balance
- Accounts Receivable
- Accounts Payable
- Total Asset Book Value
- Total Shareholder Capital

### 3.2 Quick report cards

Each card must show:

- Report name and short explanation
- Current reporting period
- Last generated date and time
- `View Report` action
- `Export PDF` action
- `Export Excel/CSV` action where applicable

### 3.3 Common filters

All reports should use a shared responsive filter bar:

| Filter | Options |
|---|---|
| Date range | Today, This Week, This Month, This Quarter, This Year, Previous Month, Previous Year, Custom |
| Accounting basis | Accrual, Cash where supported |
| Account | All accounts or selected ledger account |
| Bank/Cash account | All, individual bank account, Cash in Hand |
| Customer | All or selected customer |
| Supplier | All or selected supplier |
| Status | Draft, Open, Partially Paid, Paid, Overdue, Cancelled |
| Comparison | None, Previous Period, Previous Year |
| Currency | AED by default |

Filters must remain applied when opening a transaction drill-down and returning to the report.

## 4. Financial Statements

### 4.1 Profit & Loss Report

Shows business performance for the selected period.

```text
Revenue
  Website Development Income
  E-commerce Management Income
  Graphic Design Income
  Digital Marketing Income
  Other Operating Income
                              Total Revenue

Cost of Sales / Direct Costs
                              Gross Profit

Operating Expenses
  Salaries and Wages
  Office Rent
  Utilities
  Advertising and Marketing
  Software and Subscriptions
  Travel and Transport
  Depreciation Expense
  Other Operating Expenses
                              Total Expenses

                              Net Profit / Loss
```

Calculation:

```text
Gross Profit = Revenue - Cost of Sales
Net Profit = Gross Profit + Other Income - Operating Expenses - Other Expenses
Net Margin % = Net Profit / Revenue × 100
```

Rules:

- Shareholder capital contributions must not appear as income.
- Shareholder loans must not appear as income.
- Fixed-asset purchases must not be fully shown as an expense.
- Only depreciation expense for the selected period appears in P&L.
- Loan principal payments do not appear as expenses; applicable interest does.
- Cancelled and draft transactions are excluded.

### 4.2 Balance Sheet

Shows the company's financial position on a selected date.

```text
ASSETS
  Current Assets
    Cash in Hand
    Bank Accounts
    Accounts Receivable
    Prepaid Expenses
  Fixed Assets
    Computers and IT Equipment
    Office Equipment
    Furniture and Fixtures
    Vehicles
    Other Fixed Assets
    Less: Accumulated Depreciation
                              Total Assets

LIABILITIES
  Accounts Payable
  VAT Payable / Recoverable
  Accrued Expenses
  External Loans
  Shareholder Loans
                              Total Liabilities

EQUITY
  Shareholder Capital
  Additional Capital
  Retained Earnings
  Current Year Profit / Loss
  Less: Capital Withdrawals
                              Total Equity

                              Total Liabilities + Equity
```

Validation rule:

```text
Total Assets = Total Liabilities + Total Equity
```

If the difference is not zero, display a visible `Out of Balance` warning and block final report approval.

### 4.3 Cash Flow Statement

The report must group actual cash and bank movements into:

1. Operating activities
2. Investing activities
3. Financing activities

Examples:

| Transaction | Cash-flow group |
|---|---|
| Customer payment received | Operating inflow |
| Supplier or operating expense paid | Operating outflow |
| Fixed asset purchased | Investing outflow |
| Asset sold | Investing inflow |
| Shareholder cash contribution | Financing inflow |
| Capital withdrawal | Financing outflow |
| Shareholder loan received | Financing inflow |
| Shareholder loan principal repaid | Financing outflow |

```text
Opening Cash and Bank Balance
+ Net Operating Cash Flow
+ Net Investing Cash Flow
+ Net Financing Cash Flow
= Closing Cash and Bank Balance
```

### 4.4 Trial Balance

Required columns:

| Account Code | Account Name | Account Type | Opening Debit | Opening Credit | Period Debit | Period Credit | Closing Debit | Closing Credit |
|---|---|---|---:|---:|---:|---:|---:|---:|

Validation:

```text
Total Debits = Total Credits
```

### 4.5 General Ledger

Required fields:

- Transaction date
- Journal number
- Source document number
- Account code and account name
- Description
- Contact/customer/supplier/shareholder
- Debit
- Credit
- Running balance
- Created by
- Approval status

Clicking the source document must open the related invoice, payment, expense, asset, capital transaction, payroll entry, or journal.

## 5. Capital, Investment and Equity Reports

### 5.1 Shareholder Capital Summary

| Shareholder | Ownership % | Agreed Capital | Cash Contributed | Assets Contributed | Total Invested | Withdrawals | Net Capital | Pending Capital |
|---|---:|---:|---:|---:|---:|---:|---:|---:|

```text
Total Invested = Cash Contributed + Assets Contributed
Net Capital = Total Invested - Capital Withdrawals + Approved Equity Adjustments
Pending Capital = Agreed Capital - Net Capital
```

Capital investment affects the Balance Sheet and Cash Flow Statement but never the Profit & Loss report.

### 5.2 Capital Transaction Report

Required columns:

| Date | Reference | Shareholder | Transaction Type | Contribution Method | Asset/Account | Debit | Credit | Attachment | Status |
|---|---|---|---|---|---|---:|---:|---|---|

Transaction types:

- Cash capital contribution
- Bank capital contribution
- Asset contribution
- Additional capital
- Capital withdrawal
- Equity adjustment

### 5.3 Shareholder Loan Report

Shareholder loans must remain separate from capital.

| Shareholder | Opening Loan | Loans Received | Repayments | Interest | Closing Loan | Due Date |
|---|---:|---:|---:|---:|---:|---|

### 5.4 Statement of Changes in Equity

```text
Opening Shareholder Capital
+ New Cash Contributions
+ New Asset Contributions
- Capital Withdrawals
+/- Approved Capital Adjustments
= Closing Shareholder Capital

Opening Retained Earnings
+ Current Period Profit / Loss
- Approved Distributions
= Closing Retained Earnings

Closing Total Equity = Closing Shareholder Capital + Closing Retained Earnings
```

## 6. Asset Reports

### 6.1 Asset Register

| Asset Code | Asset Name | Category | Acquisition Type | Owner/Contributor | Purchase Date | Original Cost | Accumulated Depreciation | Current Book Value | Location | Assigned To | Status |
|---|---|---|---|---|---|---:|---:|---:|---|---|---|

Supported acquisition types:

- Company purchase
- Shareholder contribution
- Transfer to company
- Opening balance asset

### 6.2 Asset Valuation Report

```text
Current Book Value = Original Cost + Capital Improvements - Accumulated Depreciation - Impairment
```

Display totals by asset category and acquisition source.

### 6.3 Depreciation Schedule

| Asset | Cost | Residual Value | Method | Useful Life | Opening Accumulated Depreciation | Current Period Depreciation | Closing Accumulated Depreciation | Closing Book Value |
|---|---:|---:|---|---:|---:|---:|---:|---:|

For straight-line depreciation:

```text
Depreciable Amount = Cost - Residual Value
Annual Depreciation = Depreciable Amount / Useful Life in Years
Monthly Depreciation = Annual Depreciation / 12
```

Rounding differences must be adjusted in the final depreciation period so the asset never depreciates below its residual value.

### 6.4 Asset Disposal Report

| Asset | Disposal Date | Book Value | Sale Proceeds | Gain/Loss | Disposal Method | Customer/Recipient | Reference |
|---|---|---:|---:|---:|---|---|---|

```text
Gain or Loss on Disposal = Sale Proceeds - Book Value at Disposal Date
```

## 7. Receivables and Payables Reports

### 7.1 Receivables Aging

| Customer | Current | 1–30 Days | 31–60 Days | 61–90 Days | Over 90 Days | Total Outstanding |
|---|---:|---:|---:|---:|---:|---:|

### 7.2 Payables Aging

| Supplier | Current | 1–30 Days | 31–60 Days | 61–90 Days | Over 90 Days | Total Outstanding |
|---|---:|---:|---:|---:|---:|---:|

Aging days must be calculated from the due date. If no due date exists, use the document date and visibly label the fallback.

## 8. Sales, Expense and VAT Reports

### 8.1 Sales Reports

- Sales by customer
- Sales by service or item
- Invoice status summary
- Payments received
- Discounts given
- Credit notes

### 8.2 Expense Reports

- Expenses by category
- Expenses by supplier
- Expenses by employee
- Paid versus unpaid expenses
- Recurring expenses
- Expense attachment exceptions

### 8.3 UAE VAT Summary

| Section | Taxable Amount | VAT Amount |
|---|---:|---:|
| Standard-rated sales | AED | AED |
| Zero-rated sales | AED | AED 0.00 |
| Exempt sales | AED | AED 0.00 |
| Output VAT adjustments | AED | AED |
| Standard-rated purchases/expenses | AED | AED |
| Recoverable input VAT | AED | AED |
| Input VAT adjustments | AED | AED |
| Net VAT payable/recoverable |  | AED |

```text
Net VAT = Output VAT - Recoverable Input VAT
```

The VAT report must allow drill-down to the original invoice, credit note, supplier bill, expense, or asset purchase. Final VAT treatment should follow the company's tax adviser and current UAE FTA requirements.

## 9. Bank and Cash Reports

### 9.1 Account Movement Report

| Date | Reference | Description | Source Type | Money In | Money Out | Running Balance | Reconciled |
|---|---|---|---|---:|---:|---:|---|

### 9.2 Bank Reconciliation Summary

- Statement closing balance
- Book closing balance
- Unreconciled deposits
- Unreconciled withdrawals
- Reconciliation difference
- Last reconciled date

## 10. HR and Payroll Reports

### 10.1 Attendance Summary

| Employee | Working Days | Present | Absent | Half Day | Paid Leave | Unpaid Leave | Sick Leave | Overtime Hours |
|---|---:|---:|---:|---:|---:|---:|---:|---:|

### 10.2 Payroll Summary

| Employee | Basic Salary | Allowances | Overtime | Bonus | Absence Deduction | Other Deductions | Net Salary | Payment Status |
|---|---:|---:|---:|---:|---:|---:|---:|---|

Approved payroll must create a locked accounting journal. Changes after approval require reversal and regeneration instead of silent editing.

## 11. Report Interaction and UI Requirements

Each report screen must contain:

1. Report title and description
2. Date range and report-specific filters
3. Summary cards where helpful
4. Expandable grouped rows
5. Search and column sorting
6. Transaction drill-down
7. `Refresh` action
8. `Save View` action
9. `Export PDF` action
10. `Export Excel/CSV` action
11. `Print` action

Use green for positive values, red for negative or overdue values, amber for warnings, and neutral dark blue for headings. Colors must not be the only way status is communicated.

## 12. Export Requirements

### PDF

- A4 portrait for standard statements
- A4 landscape for wide tables
- TPC logo and legal company name
- Report name and reporting period
- Generated date/time and user
- Page number
- AED currency formatting
- Applied filters
- `Draft` watermark for unapproved reports

### Excel/CSV

- Preserve raw numeric values
- Use one header row
- Export currently applied filters
- Include a summary sheet for XLSX exports
- Include a transaction-detail sheet when the user selects `Include Details`

## 13. Data and Accounting Rules

- Posted journal entries are the source for financial statements.
- Draft, voided, rejected, and deleted records are excluded unless specifically requested by a filter.
- Every report row must be traceable to source transactions.
- Date and time are stored in UTC and displayed in Asia/Dubai timezone.
- Currency is AED with two decimal places.
- Financial rounding is performed at transaction-line level and totals are the sum of rounded lines.
- Opening balances must be represented by approved opening-balance journals.
- Closed accounting periods cannot be changed without an authorized unlock.
- Reports must display the last synchronization time and whether pending offline records are excluded.

## 14. Suggested Google Sheets Tabs

```text
chart_of_accounts
journal_entries
journal_lines
fiscal_periods
report_saved_views
report_export_log
assets
asset_depreciation
asset_disposals
shareholders
capital_transactions
shareholder_loans
invoices
invoice_items
payments
expenses
supplier_bills
vat_transactions
employees
attendance
payroll_runs
payroll_items
```

The application should fetch detailed rows only when required. Summary reports should use locally indexed journal data or a cached report snapshot to avoid repeatedly scanning full Google Sheets tabs.

## 15. Flutter Feature Structure

```text
lib/features/reports/
├── domain/
│   ├── entities/
│   ├── repositories/
│   ├── services/
│   └── value_objects/
├── data/
│   ├── datasources/
│   ├── models/
│   ├── repositories/
│   └── exporters/
└── presentation/
    ├── bloc/
    ├── pages/
    └── widgets/
```

Recommended reusable components:

- `ReportFilterBar`
- `ReportSummaryCard`
- `FinancialStatementTable`
- `ExpandableAccountRow`
- `TransactionDrillDownDrawer`
- `ReportExportMenu`
- `OutOfBalanceWarning`
- `SyncStatusBadge`

## 16. Permissions

| Role | Access |
|---|---|
| Owner/Admin | View, export, approve, configure, unlock periods |
| Accountant | View, export, reconcile, prepare reports |
| HR Manager | HR, attendance and payroll reports only |
| Employee | Own payslips and attendance only |
| Viewer/Auditor | Read-only access to approved reports and source documents |

Sensitive reports must be protected from unauthorized export and must be recorded in the audit log.

## 17. Acceptance Criteria

- [ ] Profit & Loss excludes capital contributions, loan principal, and fixed-asset purchase cost.
- [ ] Balance Sheet always validates Assets = Liabilities + Equity.
- [ ] Capital contributions appear in Equity and financing cash flow.
- [ ] Shareholder asset contributions appear in both Fixed Assets and Shareholder Capital without bank movement.
- [ ] Shareholder loans appear under Liabilities, not Equity or Income.
- [ ] Asset depreciation appears as a P&L expense and accumulated depreciation on the Balance Sheet.
- [ ] Every total can be drilled down to journal lines and source documents.
- [ ] Receivable and payable aging uses due dates correctly.
- [ ] VAT totals reconcile to detailed VAT transactions.
- [ ] Approved payroll totals reconcile to payroll journal entries.
- [ ] PDF and spreadsheet exports match the active filters and displayed totals.
- [ ] Offline or unsynced records are clearly identified.
- [ ] Role permissions are enforced for viewing and exporting sensitive reports.
- [ ] Report calculations pass unit tests for empty data, negative values, partial payments, credit notes, asset disposal, capital withdrawal, and fiscal-year opening balances.

## 18. Recommended Implementation Priority

1. Chart of Accounts, journal entries, and journal lines
2. Trial Balance and General Ledger
3. Profit & Loss and Balance Sheet
4. Cash Flow Statement
5. Receivables and Payables Aging
6. Capital and Equity reports
7. Asset and Depreciation reports
8. VAT reports
9. Payroll and Attendance reports
10. PDF/XLSX export, saved views, approvals, and audit log

