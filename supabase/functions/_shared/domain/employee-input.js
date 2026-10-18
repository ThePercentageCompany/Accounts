import { requireThat } from './errors.js';
import {SECTIONS,WRITE_SECTIONS,ROLES,scopeFor} from './employee-policy.js';
import { validLedgerDate } from './financial-period-policy.js';
const profileFields = ['employeeCode', 'email', 'phone', 'department', 'designation', 'joinDate', 'lastEmploymentDate',
  'basicSalary', 'allowances', 'iban', 'address', 'bankName', 'emiratesId', 'passportNumber', 'visaExpiry', 'currency'];
export function delegatedEmployeeInput(old, input) {
  const editable=['fullName','email','phone','department','designation','expectedVersion'];
  requireThat(old&&input&&!Array.isArray(input)&&Object.keys(input).every(k=>editable.includes(k)),
    403,'EMPLOYEE_FIELDS_FORBIDDEN','Only admins can change employee access, employment or pay settings.');
  const fields=['fullName',...profileFields,'employmentStatus','role','allowedSections','writableSections'];
  return employeeInput({...Object.fromEntries(fields.filter(k=>Object.hasOwn(old,k)).map(k=>[k,old[k]])),...input});
}
export function employeeInput(input) {
    const allowed = ['fullName', ...profileFields, 'employmentStatus', 'role', 'allowedSections', 'writableSections', 'expectedVersion'];
    requireThat(input && !Array.isArray(input) && Object.keys(input).every(k => allowed.includes(k)), 400, 'INVALID_EMPLOYEE', 'Unsupported employee fields.');
    requireThat(typeof input.fullName === 'string' && input.fullName.trim().length > 0 && input.fullName.length <= 160 && !/[\x00-\x1f]/.test(input.fullName) &&
      ROLES.includes(input.role) && ['ACTIVE', 'INACTIVE'].includes(input.employmentStatus) &&
      Number.isSafeInteger(input.expectedVersion) && input.expectedVersion >= 0 &&
      Array.isArray(input.allowedSections) && input.allowedSections.every(s => SECTIONS.includes(s)) &&
      new Set(input.allowedSections).size === input.allowedSections.length,
    400, 'INVALID_EMPLOYEE', 'Supply a name, valid role/status, sections and expectedVersion.');
    const writableSections = input.writableSections ?? [];
    requireThat(Array.isArray(writableSections) && new Set(writableSections).size === writableSections.length && writableSections.every(s => WRITE_SECTIONS.includes(s) && input.allowedSections.includes(s) && scopeFor(input.role, s) === 'COMPANY'), 400, 'INVALID_EMPLOYEE', 'Edit access requires an assigned company-wide section.');
    const value = { writableSections, fullName: input.fullName.trim(), role: input.role, employmentStatus: input.employmentStatus,
      allowedSections: SECTIONS.filter(s => input.allowedSections.includes(s)), expectedVersion: input.expectedVersion };
    for (const key of profileFields.filter(k => !['basicSalary', 'allowances'].includes(k))) {
      if (!Object.hasOwn(input, key)) continue;
      const text = input[key];
      requireThat(typeof text === 'string' && text.length <= (key === 'address' ? 1000 : 200) && !/[\x00-\x1f]/.test(text), 400, 'INVALID_EMPLOYEE', 'Invalid employee details.');
      value[key] = text.trim();
    }
    requireThat(!value.email || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.email), 400, 'INVALID_EMPLOYEE', 'Invalid employee email.');
    if (value.currency) value.currency = value.currency.toUpperCase();
    requireThat(!value.currency || /^[A-Z]{3}$/.test(value.currency), 400, 'INVALID_EMPLOYEE', 'Salary currency must use a three-letter code.');
    for (const key of ['basicSalary', 'allowances']) {
      if (!Object.hasOwn(input, key)) continue;
      requireThat(typeof input[key] === 'number' && Number.isFinite(input[key]) && input[key] >= 0 && input[key] <= 1e12 &&
        /^\d+(\.\d{1,2})?$/.test(String(input[key])), 400, 'INVALID_EMPLOYEE', 'Salary and allowances must be nonnegative amounts with up to two decimals.');
      value[key] = input[key];
    }
    for (const key of ['joinDate', 'lastEmploymentDate', 'visaExpiry']) {
      requireThat(!value[key] || validLedgerDate(value[key]), 400, 'INVALID_EMPLOYEE', 'Enter valid employment and visa dates.');
    }
    requireThat(!value.joinDate || !value.lastEmploymentDate || value.lastEmploymentDate >= value.joinDate,
      400, 'INVALID_EMPLOYEE', 'Last employment date cannot precede joining date.');
    return value;
  }
