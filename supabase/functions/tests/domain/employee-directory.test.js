import test from 'node:test';
import assert from 'node:assert/strict';
import { recordsEndpointAllowed, visible, projectRecord } from '../../_shared/domain/employee-policy.js';

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
