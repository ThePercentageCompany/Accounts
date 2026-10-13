import {setup,assert,owner,other} from './_fixture.ts';

Deno.test('tenant RLS, atomic writes, stale versions and idempotent registration',async()=>{
  const {db,company}=await setup();
  try{
    assert(/^[A-Za-z0-9_-]{43}$/.test(company));
    const replay=await db.query<{result:{companyId:string,replayed:boolean}}>(`select public.create_workspace('Company','company_create_0001') as result`);
    assert(replay.rows[0].result.companyId===company&&replay.rows[0].result.replayed);
    const id='c'.repeat(43);
    const changes=[{section:'Customers',recordId:id,ordinal:2,version:1,expectedVersion:0,payload:{companyId:company,recordId:id,recordVersion:1,name:'Customer',isDeleted:false}}];
    await db.query(`select public.commit_workspace($1,$2,0,$3::jsonb,'{}','{}','[]')`,[company,owner,JSON.stringify(changes)]);
    let stale=false;try{await db.query(`select public.commit_workspace($1,$2,0,'[]','{}','{}','[]')`,[company,owner]);}catch(e){stale=String(e).includes('VERSION_CONFLICT');}assert(stale);
    const broken=[{...changes[0],recordId:'d'.repeat(43),payload:{...changes[0].payload,recordId:'d'.repeat(43)}},{...changes[0],expectedVersion:99}];
    let rolledBack=false;try{await db.query(`select public.commit_workspace($1,$2,1,$3::jsonb,'{}','{}','[]')`,[company,owner,JSON.stringify(broken)]);}catch{rolledBack=true;}assert(rolledBack);
    const count=await db.query<{count:number}>(`select count(*)::int as count from public.business_records where section='Customers'`);assert(count.rows[0].count===1);
    await db.exec('set role authenticated');
    const own=await db.query(`select id from public.companies`);assert(own.rows.length===1);
    await db.query(`select set_config('request.jwt.claim.sub',$1,false)`,[other]);
    const denied=await db.query(`select id from public.companies`);assert(denied.rows.length===0);
    let rawDenied=false;try{await db.query(`select * from public.business_records`);}catch{rawDenied=true;}assert(rawDenied);
    let rpcDenied=false;try{await db.query(`select public.commit_workspace($1,$2,1,'[]','{}','{}','[]')`,[company,other]);}catch{rpcDenied=true;}assert(rpcDenied);
  }finally{await db.close();}
});

Deno.test('employee permissions clamp SELF scope and revoked membership blocks commits',async()=>{
  const {db,company}=await setup();
  try{
    const id='e'.repeat(43),payload={companyId:company,recordId:id,recordVersion:1,role:'Staff',fullName:'Staff',employmentStatus:'ACTIVE',allowedSections:['Tasks','Payroll'],writableSections:['Tasks','Payroll'],isDeleted:false};
    await db.query(`insert into public.business_records values($1,'Employees',$2,2,1,$3::jsonb,false,now())`,[company,id,JSON.stringify(payload)]);
    await db.query(`insert into public.company_memberships(company_id,user_id,employee_id,role) values($1,$2,$3,'Staff')`,[company,other,id]);
    await db.query(`select private.refresh_employee_permissions($1,$2,$3)`,[company,other,id]);
    const grants=await db.query<{scope:string,can_write:boolean}>(`select scope,can_write from public.section_permissions where user_id=$1`,[other]);
    assert(grants.rows.length===2&&grants.rows.every(r=>r.scope==='SELF'&&!r.can_write));
    await db.query(`update public.company_memberships set status='REVOKED' where user_id=$1`,[other]);
    let denied=false;try{await db.query(`select public.commit_workspace($1,$2,0,'[]','{}','{}','[]')`,[company,other]);}catch(e){denied=String(e).includes('WORKSPACE_CHANGED');}assert(denied);
  }finally{await db.close();}
});
