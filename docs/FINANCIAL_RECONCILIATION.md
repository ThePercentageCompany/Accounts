# Funds and liabilities

Available Funds is the signed closing Cash + Bank balance, including both
legacy (`cash_in_hand`, `bank_account`) and current (`cash`, `bank`) account IDs.
It includes opening funds and posted receipts, less posted payments. Unpaid
expenses and approved unpaid salary remain liabilities; they do not reduce
Cash/Bank until payment. Drafts have no ledger effect. Loan principal is a
liability rather than income; interest is an expense.

The dashboard now receives an exact decimal `availableFunds` value and separates
supplier payables, payroll/withholding, loans and other liabilities. The liability
categories reconcile to total liabilities, including signed corrections.

## Payroll deductions

Draft payroll accepts `deductionType`:

- `SALARY_REDUCTION`: deductions for unworked days/unpaid leave reduce earned
  salary expense. Only net salary becomes payable.
- `WITHHOLDING`: the gross salary remains expense, net salary is payable to the
  employee, and the withheld amount remains a separate liability.

The form requires a selection, defaulting new entries to salary reduction.
Existing records without a type retain their historical withholding treatment
until explicitly reviewed. Posted journals are never silently rewritten.
Payroll payment cannot precede its month-end accrual date.

Migration `202610270002_payroll_deduction_treatment.sql` extends the typed payroll
projection while preserving all existing table projections. It does not alter
historical monetary amounts or infer deduction types from free-text notes.

## Live reconciliation, 27 October 2026

The live AED company ledger was backed up to ignored local audit files and
checked against its income, expense, invoice, receipt and capital records.
All 17 paid expenses had matching balanced payment journals. The March payroll
was still DRAFT despite the owner confirming it had been paid. The owner
confirmed Cash, the entry creation date (23 October 2026), and that AED 1,400
was a salary reduction for days not worked.

The repair preserved the saved March compensation and original record creation
metadata, set the payroll to PAID with `SALARY_REDUCTION`, and added two posted
journals: AED 500 salary accrual and AED 500 Cash settlement. It used the normal
atomic workspace commit, with version and duplicate-ledger guards, an audit
event and cache invalidation. A transaction rolled back the first dry run;
the reviewed transaction was then committed. No existing posted journals or
other source records changed.

Verified closing balances after repair:

| Item | AED |
| --- | ---: |
| Cash | 1,703.34 |
| Bank | 11,695.86 |
| Available Funds | 13,399.20 |
| Total liabilities | 0.00 |

These are balances supported by entered transactions, rather than confirmation
against an external bank statement or a physical cash count.

The database migrations and Edge API version 20 were deployed. The production
web release was published to `accounts.thepercentagecompany.com`; its compiled
app and both service worker hashes match the verified local release build.
