import {setup,owner,other,assert} from './_fixture.ts';

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
