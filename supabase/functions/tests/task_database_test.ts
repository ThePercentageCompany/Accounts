import {setup,owner,other,assert} from './_fixture.ts';

Deno.test('workspace alerts reach the assigned employee, task editor, and payroll accountant', async () => {
 const {db,company}=await setup();
 const manager='00000000-0000-0000-0000-000000000003';
 const accountant='00000000-0000-0000-0000-000000000004';
 const staff='e'.repeat(43), managerEmployee='f'.repeat(43);
 const taskId='t'.repeat(43), payrollId='p'.repeat(43);
 const register=async (user:string,platform:string)=>db.query(
   `select public.task_notification_api($1,$2,'register',$3)`,
   [company,user,JSON.stringify({token:'token-'+user,installationId:'install-'+user,platform})]);
 const inbox=async (user:string,filter='all')=>(await db.query<{result:{unread:number;notifications:{type:string;taskId:string|null;body:string}[]}}>(
   `select public.task_notification_api($1,$2,'list',$3) result`,
   [company,user,JSON.stringify({filter})])).rows[0].result;
 try {
  await db.query(`insert into auth.users(id,email) values($1,'manager@test.example'),($2,'accountant@test.example')`,[manager,accountant]);
  for (const [ordinal,id] of [staff,managerEmployee].entries()) await db.query(
    `insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
     values($1,'Employees',$2,$3,1,jsonb_build_object('fullName','Employee'))`,[company,id,ordinal+1]);
  await db.query(`insert into public.company_memberships(company_id,user_id,employee_id,role)
    values($1,$2,$3,'Staff'),($1,$4,$5,'Manager'),($1,$6,null,'Accountant')`,
    [company,other,staff,manager,managerEmployee,accountant]);
  await db.query(`insert into public.section_permissions(company_id,user_id,section,scope,can_write)
    values($1,$2,'Tasks','COMPANY',true),($1,$3,'Payroll','COMPANY',true)`,[company,manager,accountant]);
  await register(other,'android');
  await register(manager,'ios');
  await register(accountant,'web');

  await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
    values($1,'Tasks',$2,1,1,jsonb_build_object('employeeId',$3::text,'title','Test task','status','TODO',
      'priority','MEDIUM','dueDate','2026-11-30','updatedBy',$4::text))`,[company,taskId,staff,owner]);
  assert((await inbox(other)).notifications.some(n=>n.type==='task-assigned'));
  assert((await inbox(accountant)).unread===0);

  await db.query(`update public.business_records set version=2,
    payload=payload||jsonb_build_object('status','IN_PROGRESS','updatedBy',$3::text)
    where company_id=$1 and section='Tasks' and record_id=$2`,[company,taskId,other]);
  assert((await inbox(manager)).notifications.some(n=>n.type==='task-status'));
  assert((await inbox(accountant)).unread===0);

  await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
    values($1,'Payroll',$2,1,1,jsonb_build_object('employeeId',$3::text,'status','APPROVED',
      'month',to_char((now() at time zone 'Asia/Dubai')-interval '1 month','YYYY-MM')))`,[company,payrollId,staff]);
  await db.exec('select private.queue_payroll_reminders(); select private.queue_payroll_reminders();');
  const reminders=(await inbox(accountant,'payroll')).notifications;
  assert(reminders.length===1 && reminders[0].type==='payroll-due' && reminders[0].taskId===null);
  const claim=async ()=>(await db.query<{jobs:{type:string;platform:string;canOpenTask:boolean}[]}>(
    'select public.claim_notification_push(50) jobs')).rows[0].jobs;
  const jobs=await claim();
  assert(jobs.some(j=>j.type==='task-assigned' && j.platform==='android' && !j.canOpenTask));
  assert(jobs.some(j=>j.type==='task-status' && j.platform==='ios' && j.canOpenTask));
  assert(jobs.some(j=>j.type==='payroll-due' && j.platform==='web'));

  await db.exec(await Deno.readTextFile(new URL('../../migrations/202611220002_push_test.sql',import.meta.url)));
  await db.query(`select public.task_notification_api($1,$2,'register',$3)`,[
    company,accountant,JSON.stringify({token:'second-token-'+accountant,installationId:'second-'+accountant,platform:'android'}),
  ]);
  const testPush=async (actor:string)=>(await db.query<{result:string}>(
    'select public.queue_notification_test($1,$2,$3) result',[company,actor,'install-'+accountant])).rows[0].result;
  assert(await testPush(other)==='NOT_REGISTERED');
  assert(await testPush(accountant)==='QUEUED');
  assert(await testPush(accountant)==='RATE_LIMITED');
  assert((await inbox(accountant)).notifications.some(n=>n.type==='push-test'));
  assert(!(await inbox(other)).notifications.some(n=>n.type==='push-test'));
  const testJobs=(await claim()).filter(j=>j.type==='push-test');
  assert(testJobs.length===1 && testJobs[0].platform==='web' && !testJobs[0].canOpenTask);

  await db.query(`update public.business_records set version=2,
    payload=payload||jsonb_build_object('status','PAID','paidDate','2026-11-30','netSalary',5000)
    where company_id=$1 and section='Payroll' and record_id=$2`,[company,payrollId]);
  const paid=(await inbox(other,'payroll')).notifications;
  assert(paid.length===1 && paid[0].type==='payroll-paid' && !paid[0].body.includes('5000'));
  assert((await inbox(manager,'payroll')).unread===1);
  assert((await inbox(manager,'payroll')).notifications.length===0);
  assert((await claim()).some(j=>j.type==='payroll-paid' && j.platform==='android'));
 } finally {
  await db.close();
 }
});

const employee='e'.repeat(43),second='f'.repeat(43),task='t'.repeat(43),comment='c'.repeat(43);
async function seed(db:any,company:string){
 for(const id of [employee,second])await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
  values($1,'Employees',$2,$3,1,jsonb_build_object('recordId',$2::text,'companyId',$1::text,'fullName','Employee'))`,[company,id,id===employee?1:2]);
 await db.query(`insert into public.company_memberships(company_id,user_id,employee_id,role) values($1,$2,$3,'Manager')`,[company,other,employee]);
 await db.query(`insert into public.section_permissions(company_id,user_id,section,scope,can_write) values($1,$2,'Tasks','COMPANY',false)`,[company,other]);
 await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
  select $1,'Tasks',case when i=1 then $2 else lpad(i::text,43,'x') end,i,1,
   jsonb_build_object('companyId',$1::text,'recordId',case when i=1 then $2 else lpad(i::text,43,'x') end,
    'employeeId',case when i=1 then $3 else $4 end,'title','Task '||i,'status','TODO','priority','MEDIUM',
    'dueDate','2026-10-20','updatedAt',i,'isDeleted',false,'recordVersion',1,'idempotencyKey','secret')
  from generate_series(1,125) i`,[company,task,employee,second]);
 await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
  values($1,'TaskComments',$2,1,1,jsonb_build_object('companyId',$1::text,'recordId',$2::text,'taskId',$3::text,'body','A comment'))`,[company,comment,task]);
}

Deno.test('task database pages filter assignments, preserve summaries and restrict child reads',async()=>{
 const {db,company}=await setup();
 try{
  await seed(db,company);
  const list=async(actor:string,q:unknown={})=>(await db.query<{value:any}>(`select public.task_list($1,$2,$3,'2026-10-19') value`,[company,actor,JSON.stringify(q)])).rows[0].value;
  let page=await list(owner,{offset:100,limit:20,sort:'updated'});
  assert(page.total===125&&page.records.length===20&&page.nextOffset===120&&page.summary.todo===125);
  assert(page.records[0].updatedAt===25&&!('idempotencyKey' in page.records[0]));
  page=await list(other);assert(page.total===1&&page.records[0].recordId===task&&page.summary.todo===1);
  assert(page.records[0].taskNumber===1,'Task list includes the permanent tracking number');
  assert((await list(owner,{search:'Task 125'})).total===1);
  await db.query(`update public.business_records set payload=payload||jsonb_build_object('createdAt',ordinal,'updatedAt',1000-ordinal) where company_id=$1 and section='Tasks'`,[company]);
  page=await list(owner,{sort:'newest',limit:2});
  assert(page.records[0].createdAt===125&&page.records[1].createdAt===124,'Newest sorts by creation, not most recent edit');
  page=await list(owner,{sort:'newest',offset:2,limit:2});
  assert(page.records[0].createdAt===123&&page.records[1].createdAt===122,'Newest ordering is applied before paging');
  assert((await list(owner,{status:'COMPLETED'})).total===0);
  const children=async(actor:string)=>(await db.query(`select * from public.task_records_page($1,'TaskComments',0,1000,$2,$3)`,[company,actor,task])).rows;
  assert((await children(other)).length===1);
  await db.query(`update public.business_records set payload=jsonb_set(payload,'{employeeId}',to_jsonb($2::text)),version=2 where company_id=$1 and section='Tasks' and record_id=$3`,[company,second,task]);
  assert((await list(other)).total===0&&(await children(other)).length===0);
  await db.query(`update public.section_permissions set can_write=true where company_id=$1 and user_id=$2`,[company,other]);
  assert((await list(other)).total===125&&(await children(other)).length===1);
  await db.query(`update public.company_memberships set status='REVOKED' where company_id=$1 and user_id=$2`,[company,other]);
  assert((await list(other)).total===0);
 }finally{await db.close();}
});

Deno.test('task tracking numbers are server-owned, stable and retained after deletion',async()=>{
 const {db,company}=await setup();
 try{
  await seed(db,company);
  const number=async()=>(await db.query<{payload:any}>(`select payload from public.task_records_page($1,'Tasks',0,1000,null,$2)`,[company,task])).rows[0].payload.taskNumber;
  assert(await number()===1);
  await db.query(`update public.business_records set payload=payload||'{"taskNumber":999,"title":"Renamed"}'::jsonb,version=2 where company_id=$1 and section='Tasks' and record_id=$2`,[company,task]);
  assert(await number()===1,'Editing cannot change the tracking number');
  await db.query(`update public.business_records set payload=payload||'{"isDeleted":true}'::jsonb,deleted=true,version=3 where company_id=$1 and section='Tasks' and record_id=$2`,[company,task]);
  assert(await number()===1,'Deleted tasks keep their number');
 }finally{await db.close();}
});

Deno.test('private task broadcasts reach editors and old/new assignees without task content',async()=>{
 const {db,company}=await setup();
 try{
  await seed(db,company);
  const events=async(user:string)=>(await db.query<{payload:any}>(`select payload from realtime.messages where topic=$1`,[`tasks:${company}:${user}`])).rows;
  assert((await events(owner)).length===126&&(await events(other)).length===2);
  assert((await events(other)).every(r=>r.payload.taskId===task&&!('title' in r.payload)));
  await db.query(`delete from realtime.messages`);
  await db.query(`update public.business_records set payload=jsonb_set(payload,'{employeeId}',to_jsonb($2::text)),version=2 where company_id=$1 and section='Tasks' and record_id=$3`,[company,second,task]);
  assert((await events(other)).length===1,'Previous assignee must refresh to remove the task');
  await db.query(`delete from realtime.messages`);
  await db.query(`update public.business_records set payload=jsonb_set(payload,'{title}','"Private title"'),version=3 where company_id=$1 and section='Tasks' and record_id=$2`,[company,task]);
  assert((await events(other)).length===0&&(await events(owner)).length===1);
  await db.exec(`grant usage on schema realtime to authenticated;set role authenticated;`);
  await db.query(`select set_config('request.jwt.claim.sub',$1,false),set_config('realtime.topic',$2,false)`,[other,`tasks:${company}:${owner}`]);
  assert((await db.query(`select * from realtime.messages`)).rows.length===0,'Cannot subscribe to another user topic');
  await db.query(`select set_config('realtime.topic',$1,false)`,[`tasks:${company}:${other}`]);
  assert((await db.query(`select * from realtime.messages`)).rows.length===0,'Own channel cannot disclose stored messages from another channel');
  let blocked=false;try{await db.query(`select public.task_list($1,$2,'{}','2026-10-19')`,[company,owner]);}catch{blocked=true;}
  assert(blocked,'Task query RPC is service-only');
 }finally{await db.close();}
});
