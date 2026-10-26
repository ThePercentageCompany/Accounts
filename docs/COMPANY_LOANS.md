# Company loans

Open **Accounting → Cash & Bank → Company loans**. Add the bank, private
institution or individual lender, receipt date, principal, annual rate, optional
planned monthly installment and maturity date, Cash/Bank account and reference.
All amounts use company accounting currency and two decimal places.

Save a draft, then **Post loan** when the funds have been received. Posting
debits Cash/Bank and credits `company_loan` (Company Loans liability). It does
not create income. Drafts can be edited/deleted; posted loans are locked.

Use **Record repayment / interest** for each payment. Enter principal and
interest separately using the lender statement, including interest-only
payments. Principal cannot exceed the outstanding balance. Principal debits
the loan liability; interest debits `loan_interest_expense`; the total credits
Cash/Bank. The loan becomes REPAID when outstanding principal reaches zero.
Include the final interest in the final principal payment. The annual rate and
planned installment are reference details; this module does not automatically
accrue interest, generate amortization schedules or calculate lender fees.

**Receipt / repayment history** shows the immutable journal movements. Reports,
Available Funds, balance sheet, profit and loss and general ledger use those
journals. Interest is an expense; borrowed principal and principal repayments
do not affect profit. Cash & Bank permissions control read/write access;
history reveals only movements belonging to an authorized loan.

Drafts and commands use the existing durable sync queue. Local financial
projections are provisional. The server validates period locks, record versions,
balances and stable operation IDs, and commits the loan and journal atomically.
Repeat a request with the same Idempotency-Key to confirm uncertain delivery.

## Endpoints

Routes are under `/v1/companies/{companyId}` (or the existing employee company
prefix). Mutations require an `Idempotency-Key` header and `expectedVersion`.

| Method | Route | Body |
| --- | --- | --- |
| GET | `/records/CompanyLoans` | None |
| POST | `/records/CompanyLoans` | `{expectedVersion:0, values:{lenderName,lenderType,date,principal,interestRate,installmentAmount,dueDate,paymentAccount,reference,notes}}` |
| PATCH | `/records/CompanyLoans/{id}` | `{expectedVersion,values:{...changed draft fields}}` |
| DELETE | `/records/CompanyLoans/{id}` | `{expectedVersion}` (draft only) |
| POST | `/records/CompanyLoans/{id}/post` | `{expectedVersion}` |
| POST | `/records/CompanyLoans/{id}/repay` | `{expectedVersion,values:{lastRepaymentDate,principalPayment,interestPayment,paymentAccount,paymentReference}}` |
| GET | `/records/CompanyLoans/{id}/history` | Returns `{journals:[{...journal,lines:[...]}]}` |

`lenderType` is BANK, INSTITUTION or INDIVIDUAL. `paymentAccount` is Cash or Bank.
The Flutter `/sync` contract uses table `CompanyLoans` and actions `create`,
`update`, `delete`, `loanPost`, `loanRepay`. `loanPost` has no values field.

## Deployment

Apply `supabase/migrations/202610270001_company_loans.sql` before deploying the
Edge API and updated Flutter client. This registers the new records section,
creates its indexed typed projection and preserves existing projections,
including payroll notes. The table has RLS and service-role-only reads; the
Edge API applies company membership and Cash & Bank permissions. No external
lender connection or automatic bank import is required.
