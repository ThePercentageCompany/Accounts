# Payroll and financial calculation rules

These are configurable operational calculations, not inferred legal or employment-policy rules.

## Attendance

One row per employee/day. Statuses: present, absent, halfDay, paidLeave, unpaidLeave, sickLeave, off, holiday.

- Absent and unpaidLeave each deduct one day.
- HalfDay deducts half a day.
- Present, paidLeave and sickLeave do not deduct salary in this version.
- Off and holiday do not deduct salary and are excluded from scheduled-day counts.
- Other statuses count as one marked scheduled day, including halfDay.
- Check-in/check-out fields are informational. Overtime is entered separately as approved hours; clock differences do not automatically create payable overtime. Overnight shifts are not automatically calculated.
- The app does not infer a workweek, public-holiday calendar, roster or leave entitlement. Mark every required scheduled day explicitly. Approval requires the count of marked scheduled days to equal the entered expected scheduled days, but the administrator must also confirm that the correct dates were marked.

## Payroll formula

Let monthly salary = basic salary + monthly allowances.

| Component | Rule |
| --- | --- |
| Salary base | Round(monthly salary × entered base days ÷ entered divisor) |
| Absence deduction | Round(monthly salary × unpaid/half days ÷ divisor) |
| Overtime | Round(sum of entered overtime hours × entered hourly rate) |
| Bonus | Entered amount |
| Other deductions | Entered amount |
| Net salary | Salary base + overtime + bonus − absence deduction − other deductions |

Money is stored in integer fils. Rates accept two decimals. Divisor is an integer from 1 to 31. Base days accept half-day increments and cannot exceed the divisor. The defaults of 30 base/divisor and 22 scheduled days are editable form conveniences, not a statement of your company policy. For partial-month employees, enter the correct base days yourself; joining/leaving dates constrain the month but do not decide proration automatically.

Overtime rates, paid sick-leave treatment, deductions and allowances must be reviewed against the employment agreement/company policy before approval. WPS/SIF export, bank salary transfer initiation, end-of-service benefits, leave accrual, pensions, payroll taxes and paid-payroll reversal are not implemented.

A draft can be regenerated. Approval requires unchanged employee details and attendance since generation. Approved/paid payroll cannot be regenerated, and the attendance month is locked. Exactly one payroll record is kept per employee/month. Record a payment only after salary has actually been paid; retrying that payment does not create another salary record.

## Finance

The selected month's cash movement is:

**Invoice collections + other paid income − paid expenses − paid payroll.**

The report uses actual payment dates. Unpaid invoices are customer receivables; unpaid supplier bills are supplier payables; approved-but-unpaid payroll is payroll due. Outstanding balances include all dates and are labelled accordingly.

Bank/Cash totals are movements during the period, not reconciled bank balances. The application does not include opening bank balances, transfers, bank imports, accrual journals, double-entry accounting, balance sheets or statutory profit calculations.

Do not duplicate invoice receipts as manual income or paid payroll as an expense. Use manual entries for other transactions. Supplier bills settle in full in this version; partial supplier payments are not implemented. Posted entries are locked; unpaid bills can be edited or voided. Attach original bills/receipts in Drive for supporting evidence.
