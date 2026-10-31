import test from 'node:test';
import assert from 'node:assert/strict';
import { payrollDisplay } from '../../_shared/domain/payroll-display.js';

test('payroll cards receive only their employee display identity', () => {
  const rows = [{recordId:'payroll',employeeId:'e',netSalary:500}];
  const [result] = payrollDisplay(rows,[{recordId:'e',fullName:'Amina Ali',employeeCode:'EMP-000007',iban:'private'},
    {recordId:'other',fullName:'Another employee',employeeCode:'EMP-000008'}]);
  assert.equal(result.employeeName,'Amina Ali');
  assert.equal(result.employeeCode,'EMP-000007');
  assert.equal(result.iban,undefined);
  assert.equal(result.netSalary,500);
  assert.equal(rows[0].employeeName,undefined);
});

test('missing employees use saved identity and tombstones stay unchanged', () => {
  const tombstone = {recordId:'deleted',isDeleted:true};
  const result = payrollDisplay([{employeeId:'e',employeeName:'Saved name',employeeCode:'EMP-1'},tombstone],[]);
  assert.equal(result[0].employeeName,'Saved name');
  assert.equal(result[0].employeeCode,'EMP-1');
  assert.equal(result[1],tombstone);
});
