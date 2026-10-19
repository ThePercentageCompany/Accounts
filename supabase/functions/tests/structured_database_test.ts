import {setup,owner,other,assert} from './_fixture.ts';

Deno.test('structured tables mirror source values, preserve exact money and cascade deletes',async()=>{
  const {db,company}=await setup();
  try{
    const customer='c'.repeat(43),invoice='i'.repeat(43);
    await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Customers',$2,2,1,jsonb_build_object('name','Customer','email','customer@test.example'))`,[company,customer]);
    await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Invoices',$2,2,1,jsonb_build_object('customerId',$3::text,'total',123.45,'issueDate','2026-10-19','status','DRAFT'))`,[company,invoice,customer]);
    const typed=await db.query<{total:string,issue_date:string,customer_id:string}>(`select total::text,issue_date::text,customer_id from business.invoices where company_id=$1`,[company]);
    assert(typed.rows.length===1&&typed.rows[0].total==='123.45'&&typed.rows[0].issue_date==='2026-10-19'&&typed.rows[0].customer_id===customer);
    await db.query(`update public.business_records set payload=payload||' {"total":150.01,"status":"ISSUED"}'::jsonb,version=2 where company_id=$1 and record_id=$2`,[company,invoice]);
    assert((await db.query<{total:string}>(`select total::text from business.invoices where company_id=$1`,[company])).rows[0].total==='150.01');
    await db.query(`delete from public.business_records where company_id=$1 and record_id=$2`,[company,invoice]);
    assert((await db.query(`select * from business.invoices where company_id=$1`,[company])).rows.length===0);
    assert((await db.query<{value:string}>(`select private.structured_number('1e-8')::text as value`)).rows[0].value==='0.00000001');
  }finally{await db.close();}
});

Deno.test('structured pages are bounded, seek across large ordinal gaps and never mix tenants',async()=>{
  const {db,company}=await setup();
  try{
    const second=await db.query<{value:{companyId:string}}>(`select public.create_workspace('Other','other_company_test01') as value`);
    const otherCompany=second.rows[0].value.companyId;
    await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      select $1,'Customers',lpad(i::text,43,'x'),i*1000,1,jsonb_build_object('name','Customer '||i) from generate_series(1,3000) i`,[company]);
    await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Customers',repeat('z',43),1000,1,'{"name":"Other tenant"}')`,[otherCompany]);
    const page=await db.query<{value:any[]}>(`select public.structured_record_page($1,'Customers',2900000,100) as value`,[company]);
    assert(page.rows[0].value.length===100&&page.rows[0].value[0].ordinal===2901000);
    assert(page.rows[0].value.every(r=>r.company_id===company));
    const explain=await db.query(`explain (format json) select * from business.customers where company_id=$1 and not deleted and ordinal>2900000 order by ordinal limit 100`,[company]);
    const plan=JSON.stringify(explain.rows);
    assert(plan.includes('Index')&&!plan.includes('Seq Scan'));
    let bounded=false;try{await db.query(`select public.structured_record_page($1,'Customers',0,501)`,[company]);}catch{bounded=true;}assert(bounded);
    await db.exec('set role authenticated');
    for(const sql of [`select * from business.customers`,`select public.structured_record_page('${company}','Customers',0,10)`]){
      let denied=false;try{await db.query(sql);}catch{denied=true;}assert(denied);
    }
    await db.exec('reset role');
    await db.exec('set role service_role');
    const worker=await db.query<{value:any[]}>(`select public.structured_record_page($1,'Customers',2900000,100) as value`,[company]);
    assert(worker.rows[0].value.length===100);
    await db.exec('reset role');
  }finally{await db.close();}
});

Deno.test('reference and identity constraints reject cross-company links and mismatched payloads',async()=>{
  const {db,company}=await setup();
  try{
    const second=await db.query<{value:{companyId:string}}>(`select public.create_workspace('Other','other_company_test01') as value`);
    const otherCompany=second.rows[0].value.companyId,id='c'.repeat(43);
    await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload) values($1,'Customers',$2,2,1,'{"name":"Other"}')`,[otherCompany,id]);
    let denied=false;try{await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Invoices',repeat('i',43),2,1,jsonb_build_object('customerId',$2::text))`,[company,id]);}catch{denied=true;}assert(denied);
    denied=false;try{await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Customers',repeat('x',43),2,1,jsonb_build_object('companyId',$2::text))`,[company,otherCompany]);}catch{denied=true;}assert(denied);
    assert((await db.query(`select * from business.invoices where company_id=$1`,[company])).rows.length===0);
  }finally{await db.close();}
});

Deno.test('backfill catches malformed data and completes resumable batches without deleting source',async()=>{
  const {db,company}=await setup();
  try{
    await db.exec('alter table public.business_records disable trigger sync_structured_record');
    await db.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload) values
      ($1,'Income',repeat('a',43),2,1,'{"total":10.01}'),
      ($1,'Income',repeat('b',43),3,1,'{"total":"bad"}'),
      ($1,'Income',repeat('c',43),4,1,'{"total":20.02}')`,[company]);
    await db.exec('alter table public.business_records enable trigger sync_structured_record');
    const a=await db.query<{value:any}>(`select public.backfill_structured_records($1,'Income',0,2) as value`,[company]);
    assert(a.rows[0].value.processed===2&&a.rows[0].value.failed===1&&!a.rows[0].value.done);
    const b=await db.query<{value:any}>(`select public.backfill_structured_records($1,'Income',3,2) as value`,[company]);
    assert(b.rows[0].value.done&&b.rows[0].value.failed===0);
    assert((await db.query(`select * from business.income where company_id=$1`,[company])).rows.length===2);
    assert((await db.query(`select * from public.business_records where company_id=$1 and section='Income'`,[company])).rows.length===3);
  }finally{await db.close();}
});
