# TPC Business — Google-only Flutter workspace

Flutter mobile/web source for invoicing, employee records, attendance, payroll and company cash-flow tracking. Uses Bloc/Cubit, Freezed and clean architecture. **No Firebase dependency, function or configuration remains.**

## Included modules

| Module | Implemented workflows |
| --- | --- |
| Invoices and billing | Saved customers, items/quantity/rates, AED totals, discounts, optional tax, draft editing, TPC numbering, locked issued snapshots, partial payments, receipts, void unpaid invoices, PDF print/share/archive |
| Company identity | Editable logo, name, address, contact details, bank details, TRN, default payment terms and notes |
| Employees | Employee code, name, department, role, employment dates, contact/address, basic salary/allowances, bank/IBAN, optional identity/visa details and expiry, private Drive document attachments |
| Attendance | One record per employee/day; present, absent, half day, paid leave, unpaid leave, sick leave, off day and holiday; check-in/out times, approved overtime hours and notes |
| Payroll | Employee/month draft, configurable salary divisor/base days, scheduled-day reconciliation, absence/OT/bonus/deductions, review and approval, locked attendance, salary payment recording, payslip PDFs and Drive archives |
| Finance | Supplier bills, unpaid/paid/void states, expense and other-income records, categories, Bank/Cash accounts, supporting documents, monthly collections/outgoings, customer/supplier/payroll outstanding and PDF cash movement reports |

Invoice collections and salary payments feed the finance summary automatically. Do not enter those amounts again as manual income or expense.

## Status at delivery

Source is implemented, but **not deployed or compiled**. This environment has no Flutter SDK, and its SDK download was blocked during the original build attempt. Freezed generation, Flutter analysis/tests, UI/PDF visual checks and device builds must run on your machine. **26 backend tests pass** using mocked Google services. Live Google OAuth, Apps Script, Sheets and Drive integration is untested until your accounts are configured.

## Start

```bash
bash scripts/bootstrap.sh
flutter run -d chrome
```

This opens a local demo. Click the **briefcase icon** in the billing app bar to open Employees / Attendance / Payroll / Finance. Google storage requires connected mode; see **SETUP.md**.

The bootstrap generates Android/iOS/web wrappers and Freezed/JSON outputs with your installed Flutter SDK, then formats, analyzes and tests the source. No APK is included.

## Architecture

| Layer | Implementation |
| --- | --- |
| Presentation | BillingCubit + OfficeCubit, Freezed states, responsive forms and screens |
| Domain | Billing entities, Freezed OfficeData snapshot, repository/document contracts, integer money and payroll/finance rules |
| Data | Local demo adapters; Google API repositories; invoice, payslip and finance PDF renderers |
| Identity | Google Sign-In / OAuth for web, Android and iOS |
| Server logic | Google Apps Script API executable: allowlisted Google accounts, validation, locking, numbering and file writes |
| Persistent records | Google Sheets JSON tabs; readable invoice/payment registers |
| Files | Private Google Drive folder for invoice PDFs, receipts, payslips, reports and attachments |

All project source lives under `lib/`. Google server source is under `backend/apps-script/`. Google OAuth app registration uses a standard Google Cloud project; it is not Firebase and requires no custom server or service-account secret in Flutter.

## Payroll rules in this version

Read **PAYROLL-AND-FINANCE.md** before running real payroll. Settings are deliberately explicit: the app does not infer employment contract rules, statutory overtime, leave entitlements, WPS/SIF, end-of-service benefits, pension or tax obligations.

## Operating boundaries

- One internal administration workspace for one company. All authorised users can access the full billing, HR and finance dataset. This is not an employee self-service portal or a granular-role system.
- Sheets/Drive permissions must match that full-access administrator model. Do not give general employees access to this HR spreadsheet.
- English/Latin PDF fonts; Arabic/RTL documents are not implemented.
- Finance is operational cash movement/outstanding tracking, not a double-entry ledger, bank reconciliation, balance sheet or statutory financial statements.
- No inventory, recurring billing, online payment gateway, credit-note/refund workflow, payroll reversal, recruitment or leave-request approval module.
- Current data loading fetches all records; paging and indexing are needed before large datasets. Service quotas and Google OAuth publishing/verification requirements apply.
- Logo up to 20 KB; documents up to 5 MB; 20 attachments per employee/finance entry. Invoice items up to 30; payments up to 100 per invoice.
- Demo data stays on one browser/device and does not migrate automatically to Google.
- Confirm the sample bank account details and your IBAN in Settings before billing. No separate company logo was supplied.

## Official implementation references

- [Apps Script API execution and shared Cloud project requirements](https://developers.google.com/apps-script/api/how-tos/execute)
- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)
- [Google Sign-In web button and authorization behavior](https://pub.dev/packages/google_sign_in_web)
- [Apps Script locking](https://developers.google.com/apps-script/reference/lock/lock-service)
- [Flutter PDF generation](https://pub.dev/packages/pdf)
