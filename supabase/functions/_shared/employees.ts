// deno-lint-ignore-file no-explicit-any
import { employeeInput } from './domain/employee-input.js';
import { opaque, digest } from './domain/crypto.js';
import { requireThat } from './domain/errors.js';
import { databaseError } from './workspace.ts';
import { employeeLoginCode, employeeLoginPassword } from './domain/employee-login.js';

export async function saveEmployee(ctx: any,id: string|null,input: any,key: string) {
  requireThat(ctx.admin,403,'ADMIN_REQUIRED','Only company admins can manage employees.');
  requireThat(/^[A-Za-z0-9_-]{16,128}$/.test(key),400,'IDEMPOTENCY_KEY_REQUIRED','Use a stable operation key.');
  const values:any=employeeInput(input),opKey=digest(`business:${ctx.company.id}:${key}`);
  const fingerprint=digest(JSON.stringify({id,input}));
  const state=(await ctx.registry.read()).state;
  const previous=state.companies[ctx.company.id].businessOps[opKey];
  if(previous) {
    requireThat(previous.fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','This key was already used.');
    return {employeeId:previous.recordId,recordId:previous.recordId,version:previous.resultVersion,replayed:true};
  }
  const all=(await ctx.records.read(ctx.company.id,['Employees'])).Employees;
  const old=all.find((r:any)=>r.recordId===id);
  requireThat((old?.recordVersion??0)===values.expectedVersion && (id ? old && !old.isDeleted : values.expectedVersion===0),409,'VERSION_CONFLICT','Employee changed. Refresh before saving.');
  const employeeId=id??opaque(),now=Date.now();
  const sequence=Math.max(0,...all.map((r:any)=>/^EMP-(\d+)$/.test(r.employeeCode??'')?Number(r.employeeCode.slice(4)):0))+1;
  const employeeCode=values.employeeCode||old?.employeeCode||`EMP-${String(sequence).padStart(6,'0')}`;
  requireThat(!all.some((r:any)=>r.recordId!==employeeId && !r.isDeleted && r.employeeCode===employeeCode),409,'INVALID_EMPLOYEE','Employee code is already used.');
  const payload={basicSalary:0,allowances:0,currency:ctx.company.base_currency??'AED',...old,...values,employeeCode,recordId:employeeId,
    companyId:ctx.company.id,recordVersion:values.expectedVersion+1,createdAt:old?.createdAt??now,createdBy:old?.createdBy??ctx.user.id,
    updatedAt:now,updatedBy:ctx.user.id,isDeleted:false,syncStatus:'SYNCED'};
  delete payload.expectedVersion;delete payload._row;
  await ctx.records.write(ctx.company.id,'Employees',old?._row??Math.max(1,...all.map((r:any)=>r._row))+1,payload);
  await ctx.registry.transact((next:any)=>{next.companies[ctx.company.id].businessOps[opKey]={fingerprint,
    recordId:employeeId,resultVersion:payload.recordVersion,completed:true};});
  return {employeeId,recordId:employeeId,version:payload.recordVersion};
}

export async function employeeAccess(db:any,user:any,companyId:string,employeeId:string,action:string,key:string,appOrigin:string) {
  requireThat(/^[A-Za-z0-9_-]{16,128}$/.test(key),400,'IDEMPOTENCY_KEY_REQUIRED','Use a stable operation key.');
  const email=`employee-${digest(companyId+employeeId).slice(0,32)}@accounts.thepercentagecompany.com`;
  const {data:op,error}=await db.rpc('prepare_employee_access',{p_company:companyId,p_actor:user.id,p_employee:employeeId,
    p_action:action,p_key:key,p_invite:opaque(),p_email:email});
  if(error) databaseError(error);
  if(action==='revoke')return {revoked:true};
  const secret=Deno.env.get('EMPLOYEE_INVITE_KEY');
  requireThat(secret && secret.length>=32,503,'INVITE_CONFIGURATION','Employee invitation signing is not configured.');
  const privateCode=employeeLoginCode(secret,companyId,employeeId,key);
  const password=employeeLoginPassword(secret,op.invite_id,privateCode);
  if(op.status!=='COMPLETED') {
    const {data:existing,error:ie}=await db.rpc('employee_auth_identity',{p_email:op.auth_email});if(ie)databaseError(ie);
    let authUserId=existing;
    if(authUserId) {
      const {error:ue}=await db.auth.admin.updateUserById(authUserId,{password,email_confirm:true});
      if(ue)databaseError(ue);
    } else {
      const {data:created,error:ae}=await db.auth.admin.createUser({email:op.auth_email,password,email_confirm:true,
        app_metadata:{kind:'employee'}});
      if(ae)databaseError(ae);authUserId=created.user.id;
    }
    const {error:ce}=await db.rpc('complete_employee_access',{p_company:companyId,p_actor:user.id,p_key:key,p_user:authUserId});
    if(ce)databaseError(ce);
  }
  const inviteLink=`${appOrigin}/#employee-invite=${op.invite_id}`;
  return {inviteId:op.invite_id,inviteLink,qrPayload:inviteLink,privateCode};
}
