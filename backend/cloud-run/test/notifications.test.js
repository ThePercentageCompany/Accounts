import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { opaque } from '../src/crypto.js';
import { NotificationService } from '../src/notification-service.js';
import { principalFromRows } from '../src/employee-policy.js';

async function setup() {
  const f = fixture(), token = await f.login();
  const companyId = (await f.service.createCompany(token, {name:'Notifications'}, 'notification_company_01')).company.companyId;
  const employeeId = opaque(), roleId = opaque(), taskId = opaque();
  let time = Date.parse('2026-10-08T10:00:00+04:00');
  const rows = {Employees:[{recordId:employeeId,companyId,roleId,employmentStatus:'ACTIVE',fullName:'Alex'}],
    Roles:[{recordId:roleId,companyId,roleName:'Staff'}],
    RolePermissions:[{companyId,roleId,section:'Tasks',action:'read',fieldName:'*',recordScope:'SELF'}],
    Tasks:[{recordId:taskId,companyId,employeeId,title:'Prepare report',recordVersion:1,status:'TODO',
      dueDate:'2026-10-08',endTime:'12:00',reminder:'2_HOURS'}]};
  await f.registry.transact(s => {
    s.companies[companyId].stage = 'READY';
    s.companies[companyId].employeeAccess = {[employeeId]:{status:'ACTIVE'}};
  });
  const sheets = {read:async (_id,names) => Object.fromEntries(names.map(name => [name,structuredClone(rows[name])]))};
  const employees = {sheets, principal:async () => principalFromRows(companyId,employeeId,rows,time),
    verifyContext:(p,c) => {assert.equal(p.companyId,c.companyId);}};
  const business = {sheets,owner:(s,t,id) => ({owner:f.service.companyOwner(s,t,id)})};
  const sent = [];
  const notifications = new NotificationService({accounts:f.service,employees,business,
    config:{pushPublicKey:'public-key'},now:()=>time,sendPush:async (_,payload) => sent.push(payload)});
  const subscription = {endpoint:'https://fcm.googleapis.com/fcm/send/device',
    keys:{p256dh:Buffer.alloc(65,1).toString('base64url'),auth:Buffer.alloc(16,2).toString('base64url')}};
  return {...f,token,companyId,employeeId,taskId,rows,notifications,sent,subscription,
    advance:ms=>{time+=ms;}};
}
test('assignment and server deadline events persist once and push once per device', async () => {
  const f = await setup();
  await f.notifications.subscribe('employee',f.companyId,{subscription:f.subscription},true,{});
  await Promise.all([f.notifications.scanCompany(f.companyId),f.notifications.scanCompany(f.companyId)]);
  assert.equal(f.sent.length,2);
  const history = await f.notifications.list('employee',f.companyId,true,{});
  assert.equal(history.unread,2);
  assert.equal(history.notifications[0].taskId,f.taskId);
  assert.equal('user' in history.notifications[0],false);
  await f.notifications.read('employee',f.companyId,{id:'all',read:true},true,{});
  assert.equal((await f.notifications.list('employee',f.companyId,true,{})).unread,0);
  await f.notifications.scanCompany(f.companyId);
  assert.equal(f.sent.length,2);
});
test('permission revocation hides history and suppresses push; unsafe endpoints are rejected', async () => {
  const f = await setup();
  await assert.rejects(f.notifications.subscribe('employee',f.companyId,
    {subscription:{...f.subscription,endpoint:'https://localhost/private'}},true,{}), e=>e.code==='INVALID_PUSH_SUBSCRIPTION');
  await f.notifications.scanCompany(f.companyId);
  f.rows.RolePermissions = [];
  assert.equal((await f.notifications.list('employee',f.companyId,true,{})).notifications.length,0);
  await f.notifications.scanCompany(f.companyId);
  assert.equal(f.sent.length,0);
  await assert.rejects(f.notifications.list(await f.login('other-owner'),f.companyId,false,{}));
});
test('changed deadlines get a new reminder while completed tasks do not', async () => {
  const f = await setup();
  await f.notifications.scanCompany(f.companyId);
  f.rows.Tasks[0].endTime='13:00';
  f.advance(3600000);
  await f.notifications.scanCompany(f.companyId);
  assert.equal((await f.notifications.list('employee',f.companyId,true,{})).notifications.length,3);
  f.rows.Tasks[0].status='COMPLETED';
  f.rows.Tasks[0].endTime='14:00';
  f.advance(3600000);
  await f.notifications.scanCompany(f.companyId);
  assert.equal((await f.notifications.list('employee',f.companyId,true,{})).notifications.length,3);
});

test('disable targets this browser without disabling other devices and reports subscription state', async () => {
  const f = await setup();
  const second = {...f.subscription, endpoint: f.subscription.endpoint + '-second'};
  await f.notifications.subscribe('employee', f.companyId, {subscription:f.subscription}, true, {});
  await f.notifications.subscribe('employee', f.companyId, {subscription:second}, true, {});
  await f.notifications.subscribe('employee', f.companyId, {subscription:second}, true, {});
  assert.equal((await f.notifications.list('employee',f.companyId,true,{})).subscriptionCount, 2);
  await f.notifications.unsubscribe('employee', f.companyId, {endpoint:f.subscription.endpoint}, true, {});
  const list = await f.notifications.list('employee',f.companyId,true,{});
  assert.deepEqual(list.pushEndpoints, [second.endpoint]);
  await assert.rejects(f.notifications.unsubscribe('employee',f.companyId,{endpoint:42},true,{}), {code:'INVALID_PUSH_SUBSCRIPTION'});
});
test('reassigned tasks hide previous recipient history and read alerts are not delivered to newly enabled devices', async () => {
  const f = await setup();
  await f.notifications.scanCompany(f.companyId);
  await f.notifications.read('employee',f.companyId,{id:'all',read:true},true,{});
  await f.notifications.subscribe('employee',f.companyId,{subscription:f.subscription},true,{});
  await f.notifications.scanCompany(f.companyId);
  assert.equal(f.sent.length, 0);
  f.rows.Tasks[0].employeeId = opaque();
  assert.equal((await f.notifications.list('employee',f.companyId,true,{})).unread, 0);
});

 test('in-app list generates assignments and reminders without push or scheduler', async () => {
  const f = await setup();
  f.notifications.sendPush = undefined;
  const history = await f.notifications.list('employee', f.companyId, true, {});
  assert.equal(history.unread, 2);
  assert.equal(history.pushAvailable, false);
  assert.equal(history.nativePushAvailable, false);
  assert.equal(f.sent.length, 0);
  await f.notifications.read('employee', f.companyId, {id: 'all', read: true}, true, {});
  assert.equal((await f.notifications.list('employee', f.companyId, true, {})).unread, 0);
  f.rows.Tasks[0].endTime = '13:00';
  f.advance(3600000);
  const refreshed = await f.notifications.list('employee', f.companyId, true, {});
  assert.equal(refreshed.notifications.length, 3);
  assert.equal(refreshed.unread, 1);
});
