import {setup,owner,other,assert} from './_fixture.ts';
Deno.test('country entities have separate books, scoped group access and idempotent creation',async()=>{
  const {db}=await setup();
  try{
    const g=await db.query<{result:{id:string}}>(`select public.create_business_group('Global business','group_create_0001') as result`);
    const group=g.rows[0].result.id;
    const create=async(name:string,country:string,currency:string,zone:string,key:string)=>(await db.query<{result:{companyId:string}}>(
      `select public.create_country_entity($1,$2,$3,$4,$5,'TAX-123',$6) as result`,[group,name,country,currency,zone,key])).rows[0].result;
    const uae=await create('Dubai entity','AE','AED','Asia/Dubai','entity_create_0001');
    const india=await create('India entity','IN','INR','Asia/Kolkata','entity_create_0002');
    assert(uae.companyId!==india.companyId);
    const profiles=await db.query<{company_id:string,payload:{currency:string,taxNumber:string}}>(`select company_id,payload from public.business_records where section='CompanyProfile' and company_id=any($1)`,[[uae.companyId,india.companyId]]);
    assert(profiles.rows.find(r=>r.company_id===uae.companyId)?.payload.currency==='AED');
    assert(profiles.rows.find(r=>r.company_id===india.companyId)?.payload.currency==='INR');
    assert(profiles.rows.every(r=>r.payload.taxNumber==='TAX-123'));
    assert((await create('India entity','IN','INR','Asia/Kolkata','entity_create_0002')).companyId===india.companyId);
    let blocked=false;try{await create('Changed','IN','INR','Asia/Kolkata','entity_create_0002');}catch{blocked=true;}assert(blocked);
    await db.query(`select set_config('request.jwt.claim.sub',$1,false)`,[other]);
    blocked=false;try{await create('Unauthorized','US','USD','America/New_York','entity_create_0003');}catch{blocked=true;}assert(blocked);
    await db.exec('set role authenticated');
    assert((await db.query('select * from public.business_groups')).rows.length===0);
    assert((await db.query('select * from public.companies')).rows.length===0);
    await db.exec('reset role');
    await db.query(`select set_config('request.jwt.claim.sub',$1,false)`,[owner]);
    assert((await db.query(`select * from public.companies where group_id=$1`,[group])).rows.length===2);
    const task='t'.repeat(43),employee='e'.repeat(43);
    await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Tasks',$2,2,1,jsonb_build_object('recordId',$2::text,'companyId',$1::text,'employeeId',$3::text,'title','India deadline','status','TODO','reminder','AT_DUE',
      'dueDate',to_char(now() at time zone 'Asia/Kolkata','YYYY-MM-DD'),'endTime',to_char(now() at time zone 'Asia/Kolkata','HH24:MI')))`,[india.companyId,task,employee]);
    await db.exec('select private.queue_task_reminders()');
    const reminders=await db.query<{body:string}>(`select body from public.notifications where type='task-due' and company_id=$1`,[india.companyId]);
    assert(reminders.rows.length===1&&reminders.rows[0].body.includes('Asia/Kolkata'));
    for(const [entity,currency,amount] of [[uae.companyId,'AED',100],[india.companyId,'INR',200]]){
      await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
        values($1,'Invoices',$2,2,1,jsonb_build_object('recordId',$2::text,'companyId',$1::text,'status','ISSUED','currency',$3::text,'balance',$4::numeric))`,[entity,'i'.repeat(43),currency,amount]);
    }
    const overview=await db.query<{result:{entities:any[],groups:any[]}}>(`select public.business_group_overview($1,null) as result`,[owner]);
    assert(overview.rows[0].result.entities.find(e=>e.companyId===uae.companyId).metrics.outstandingByCurrency.AED===100);
    assert(overview.rows[0].result.entities.find(e=>e.companyId===india.companyId).metrics.outstandingByCurrency.INR===200);
    const hidden=await db.query<{result:{entities:any[],groups:any[]}}>(`select public.business_group_overview($1,null) as result`,[other]);
    assert(hidden.rows[0].result.entities.length===0&&hidden.rows[0].result.groups.length===0);
  }finally{await db.close();}
});
