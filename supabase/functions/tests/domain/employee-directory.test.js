import test from 'node:test';
import assert from 'node:assert/strict';
import { recordsEndpointAllowed, visible, projectRecord } from '../../_shared/domain/employee-policy.js';
import {employeeInput,delegatedEmployeeInput} from '../../_shared/domain/employee-input.js';

test('admins can grant employee edit permission and delegated edits preserve protected settings',()=>{
  const old={fullName:'Employee',role:'Manager',employmentStatus:'ACTIVE',allowedSections:['Employees'],
    writableSections:['Employees'],expectedVersion:1,basicSalary:5000,allowances:100};
  assert.deepEqual(employeeInput(old).writableSections,['Employees']);
  const updated=delegatedEmployeeInput(old,{fullName:'Updated name',department:'Sales',expectedVersion:1});
  assert.equal(updated.fullName,'Updated name');
  assert.equal(updated.basicSalary,5000);
  assert.deepEqual(updated.writableSections,['Employees']);
  for(const field of ['role','allowedSections','writableSections','basicSalary','employmentStatus','employeeCode']) {
    assert.throws(()=>delegatedEmployeeInput(old,{[field]:'forged',expectedVersion:1}),e=>e.code==='EMPLOYEE_FIELDS_FORBIDDEN');
  }
  assert.throws(()=>employeeInput({...old,role:'Staff'}),e=>e.code==='INVALID_EMPLOYEE');
});

test('records permits employee directory reads but never employee management or private tables', () => {
  assert.equal(recordsEndpointAllowed('Employees','GET'),true);
  for(const method of ['POST','PATCH','PUT','DELETE'])assert.equal(recordsEndpointAllowed('Employees',method),false);
  assert.equal(recordsEndpointAllowed('Employees','GET',true),false);
  for(const table of ['DocumentRegistry','NumberSequences'])assert.equal(recordsEndpointAllowed(table,'GET'),false);
});

test('directory keeps manager access, staff self access and private field protection', () => {
  const self={recordId:'self',companyId:'company',fullName:'Self'};
  const colleague={recordId:'other',companyId:'company',fullName:'Colleague',basicSalary:5000,
    allowances:100,iban:'private',passportNumber:'private',roleId:'private'};
  const manager={companyId:'company',employeeId:'self',role:'Manager',permissions:{Employees:'COMPANY'}};
  const staff={...manager,role:'Staff',permissions:{Employees:'SELF'}};
  assert.equal(visible(manager,'Employees',colleague),true);
  assert.equal(visible(staff,'Employees',self),true);
  assert.equal(visible(staff,'Employees',colleague),false);
  assert.equal(visible({...manager,permissions:{}},'Employees',colleague),false);
  const projected=projectRecord(manager,'Employees',colleague);
  assert.equal(projected.fullName,'Colleague');
  for(const key of ['basicSalary','allowances','iban','passportNumber','roleId'])assert.equal(key in projected,false);
});
