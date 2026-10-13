# Cash & Bank transfers

Open **Accounting → Cash & Bank → Cash / Bank transfers**. Create a draft,
select Cash → Bank for a deposit or Bank → Cash for a withdrawal, and post it.
Amounts use the company accounting currency, with two decimal places. These
are business money movements; personal withdrawals belong in an owner account.

Posting writes the transfer, journal and two Asset lines in one atomic Postgres
transaction. Deposits debit `bank_account` and credit `cash_in_hand`; withdrawals
swap the accounts. Profit is unaffected. Posted records cannot be edited or
deleted. Reverse a mistake with a date and reason, then create its replacement.
Posting and reversal reject closed financial periods. Versions and stable
idempotency keys protect against concurrent edits and duplicate retries.

## Postgres records

`MoneyTransfers` records are stored in Postgres under the company's identity.
Posting commits the transfer and balanced journal in one transaction.

Alongside standard system columns, the table contains `date`, `fromAccount`,
`toAccount`, `amount`, `description`, `reference`, `status`, `bankStatus`,
`statementDate`, `statementReference`, `reversalDate`, `reversalReason`.
Status follows DRAFT → POSTED → REVERSED. Bank status is PENDING or CLEARED.
Status and matching metadata cannot be set through draft CRUD.

## API

Owner routes use the existing session, origin/CSRF protection and business
authorization. Mutations require `Idempotency-Key` and `expectedVersion`.

| Method | Route under `/v1/companies/{companyId}` | Body |
| --- | --- | --- |
| GET | `/records/MoneyTransfers` | Optional `includeDeleted=true` query |
| POST | `/records/MoneyTransfers` | `expectedVersion: 0`, `values` containing draft fields |
| PATCH | `/records/MoneyTransfers/{id}` | `expectedVersion`, changed draft `values` |
| DELETE | `/records/MoneyTransfers/{id}` | `expectedVersion` (draft only) |
| POST | `/records/MoneyTransfers/{id}/post` | `expectedVersion` |
| POST | `/records/MoneyTransfers/{id}/reverse` | `expectedVersion`, `values: {reversalDate, reversalReason}` |
| POST | `/records/MoneyTransfers/{id}/match` | `expectedVersion`, `values: {bankStatus: "CLEARED", statementDate, statementReference}` |

To remove a match, use the match route with `values: {bankStatus: "PENDING"}`.
The Flutter durable write queue uses `/sync` with the `MoneyTransfers` table
and actions `create`, `update`, `delete`, `transferPost`, `transferReverse`,
`transferMatch`. Posting has no `values` field. All other actions follow the
existing sync contract. Employee sync/read uses the existing employee routes;
grant **Cash & Bank** read/write permission in employee administration.

## Statement matching scope

Match a posted transfer to a bank statement using its statement date and
reference. Pending transfers stay visible for follow-up. Matching does not
create another journal. Removing a match also leaves money unchanged. Reversal
preserves the original matching information for audit history.

This is manual statement matching for transfers, not a complete bank statement
reconciliation engine. Statement imports, unique statement-line allocation,
closing-balance reconciliation, multiple bank accounts, foreign-currency
transfers and bank-fee matching are outside this module. Record bank fees through
Expenses. Cash counting remains a separate physical check against the ledger.

Deploy the backend and Flutter build together to expose the module in production.
