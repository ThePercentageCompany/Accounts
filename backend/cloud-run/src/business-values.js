import { requireThat } from './errors.js';

const NUMBERS = new Set(('unitPrice taxRate subtotal discount taxAmount total paidAmount balance lineNumber quantity lineTotal amount hours rate basicSalary allowances overtimeAmount bonus deductions grossSalary netSalary cost usefulLife residualValue accumulatedDepreciation netBookValue agreedCapital percentage principal interestRate repaidAmount outstandingBalance totalDebit totalCredit debit credit').split(' '));
const DATES = new Set(('issueDate dueDate paymentDate validUntil date paidDate purchaseDate investmentDate effectiveDate startDate endDate').split(' '));
const NONNEGATIVE = new Set(('unitPrice taxRate discount paidAmount quantity hours rate basicSalary allowances overtimeAmount bonus deductions cost usefulLife residualValue accumulatedDepreciation agreedCapital percentage principal interestRate repaidAmount debit credit').split(' '));

export function validateBusinessValues(values) {
  for (const [key, value] of Object.entries(values)) {
    if (NUMBERS.has(key)) {
      requireThat(typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= 1e12,
        400, 'INVALID_NUMBER', `${key} must be a finite number within supported limits.`);
      requireThat(!NONNEGATIVE.has(key) || value >= 0, 400, 'INVALID_NUMBER', `${key} cannot be negative.`);
      if (key === 'lineNumber') requireThat(Number.isSafeInteger(value) && value > 0, 400, 'INVALID_NUMBER', 'lineNumber must be a positive integer.');
      if (['taxRate', 'percentage'].includes(key)) requireThat(value >= 0 && value <= 100,
        400, 'INVALID_NUMBER', `${key} must be between 0 and 100.`);
      continue;
    }
    // All remaining fields in the normalized business schema are text, including
    // opaque relation IDs and status values. System metadata is validated elsewhere.
    requireThat(typeof value === 'string' && !/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(value),
      400, 'INVALID_TEXT', `${key} must be text without control characters.`);
    if (DATES.has(key) && value !== '') {
      const parsed = new Date(value);
      requireThat(/^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(parsed.getTime()) &&
        parsed.toISOString().slice(0, 10) === value, 400, 'INVALID_DATE', `${key} must be a valid YYYY-MM-DD date.`);
    }
    if (key === 'month' && value !== '') requireThat(/^\d{4}-(0[1-9]|1[0-2])$/.test(value),
      400, 'INVALID_DATE', 'month must use YYYY-MM.');
    if (key === 'currency' && value !== '') requireThat(/^[A-Z]{3}$/.test(value),
      400, 'INVALID_CURRENCY', 'currency must be a three-letter uppercase code.');
  }
}
