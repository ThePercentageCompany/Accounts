// deno-lint-ignore-file no-explicit-any
import {setup,assert,owner} from './_fixture.ts';
import {workspace} from '../_shared/workspace.ts';
import {companyDesign} from '../_shared/domain/document-design.js';

function client(pg:any){
  return {
    from(table:string){
      assert(/^[a-z_]+$/.test(table));
      let columns='*',single=false,offset=0,limit=1000,order='';const filters:string[]=[],args:any[]=[];
      const query:any={
        select(c='*'){assert(/^[a-z_,*]+$/.test(c));columns=c;return query;},
        eq(k:string,v:any){assert(/^[a-z_]+$/.test(k));args.push(v);filters.push(`${k}=$${args.length}`);return query;},
        gt(k:string,v:any){assert(/^[a-z_]+$/.test(k));args.push(v);filters.push(`${k}>$${args.length}`);return query;},
        is(k:string,v:any){assert(v===null);filters.push(`${k} is null`);return query;},
        order(k:string){order=`order by ${k}`;return query;},
        range(from:number,to:number){offset=from;limit=to-from+1;return query;},
        maybeSingle(){single=true;return query;},
        async then(resolve:any,reject:any){try{
          const result=await pg.query(`select ${columns} from public.${table} ${filters.length?'where '+filters.join(' and '):''} ${order} limit ${limit} offset ${offset}`,args);
          return resolve({data:single?result.rows[0]??null:result.rows,error:null});
        }catch(error){return reject(error);}},
      };return query;
    },
    async rpc(name:string,input:any){try{
      let result:any;
      if(name==='load_workspace_operations')result=await pg.query(`select public.load_workspace_operations($1,$2::text[]) as value`,[input.p_company,input.p_keys]);
      else if(name==='task_records_page') {
        const rows=await pg.query(`select * from public.task_records_page($1,$2,$3,$4,$5,$6)`,[input.p_company,input.p_section,input.p_after,input.p_limit,input.p_actor??null,input.p_task??null]);
        return {data:rows.rows,error:null};
      }
      else if(name==='commit_workspace')result=await pg.query(`select public.commit_workspace($1,$2,$3,$4::jsonb,$5::jsonb,$6::jsonb,$7::jsonb) as value`,
        [input.p_company,input.p_actor,input.p_revision,JSON.stringify(input.p_changes),JSON.stringify(input.p_configuration),JSON.stringify(input.p_operations),JSON.stringify(input.p_audit)]);
      else throw new Error(`Unknown RPC ${name}`);
      return {data:result.rows[0].value,error:null};
    }catch(error){return {data:null,error:{message:String(error)}};}},
  };
}

Deno.test('payroll CRUD persists notes through the service and database projections',async()=>{
  const {db:pg,company}=await setup();
  try {
    const employee='e'.repeat(43),db=client(pg),user={id:owner};
    await pg.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Employees',$2,2,1,jsonb_build_object('companyId',$1::text,'recordId',$2::text,
      'employmentStatus','ACTIVE','basicSalary',5000,'allowances',500,'currency','AED'))`,[company,employee]);
    let ctx=await workspace(db,user,company,['payroll_create_0001']);
    const created=await ctx.business.mutate('',company,'Payroll',null,'create',{expectedVersion:0,values:{
      employeeId:employee,month:'2026-10',currency:'AED',exchangeRate:1,bonus:200,deductions:100,
      notes:'  October salary  ',bonusNotes:'Performance',deductionNotes:'Advance repayment',
    }},'payroll_create_0001');
    await ctx.commit();
    ctx=await workspace(db,user,company);
    const saved=(await ctx.read('Payroll'))[0];
    assert(saved.notes==='October salary'&&saved.bonusNotes==='Performance'&&saved.netSalary===5600);
    const typed=await pg.query<{notes:string,bonus_notes:string,deduction_notes:string}>(
      `select notes,bonus_notes,deduction_notes from business.payroll where company_id=$1`,[company]);
    assert(typed.rows[0].notes==='October salary'&&typed.rows[0].deduction_notes==='Advance repayment');
    ctx=await workspace(db,user,company,['payroll_update_0001']);
    await ctx.business.mutate('',company,'Payroll',created.recordId,'update',{
      expectedVersion:1,values:{notes:'Updated salary notes',bonusNotes:''}},'payroll_update_0001');
    await ctx.commit();
    ctx=await workspace(db,user,company);
    const updated=(await ctx.read('Payroll'))[0];
    assert(updated.notes==='Updated salary notes'&&updated.bonusNotes===''&&updated.deductionNotes==='Advance repayment');
    ctx=await workspace(db,user,company,['payroll_delete_0001']);
    await ctx.business.mutate('',company,'Payroll',created.recordId,'delete',{expectedVersion:2},'payroll_delete_0001');
    await ctx.commit();
    ctx=await workspace(db,user,company);
    assert((await ctx.read('Payroll')).length===0);
    const deleted=await pg.query<{deleted:boolean}>(`select deleted from business.payroll where company_id=$1`,[company]);
    assert(deleted.rows[0].deleted);
  } finally {await pg.close();}
});

Deno.test('capital transaction reads resolve shareholder names and preserve posting status',async()=>{
  const {db:pg,company}=await setup();
  try {
    const shareholder='s'.repeat(43),transaction='t'.repeat(43);
    await pg.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Shareholders',$2,1,1,jsonb_build_object('companyId',$1::text,'recordId',$2::text,'name','Aisha'))`,[company,shareholder]);
    await pg.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'CapitalTransactions',$2,1,1,jsonb_build_object('companyId',$1::text,'recordId',$2::text,'shareholderId',$3::text,'status','DRAFT','amount',500))`,[company,transaction,shareholder]);
    const ctx=await workspace(client(pg),{id:owner},company);
    const rows=await ctx.read('CapitalTransactions');
    assert(rows.length===1&&rows[0].shareholderName==='Aisha'&&rows[0].status==='DRAFT');
    assert(!('_row' in rows[0]));
  } finally {await pg.close();}
});

Deno.test('RecordStore cursor traversal crosses pages without skipping sparse ordinals',async()=>{
  const {db:pg,company}=await setup();
  try{
    await pg.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      select $1,'Customers',lpad(i::text,43,'x'),i*10,1,jsonb_build_object('recordId',lpad(i::text,43,'x'),'name','Customer '||i) from generate_series(1,2005) i`,[company]);
    const ctx=await workspace(client(pg),{id:owner},company);
    const rows=(await ctx.records.read(company,['Customers'])).Customers;
    assert(rows.length===2005&&rows[0]._row===10&&rows[2004]._row===20050);
    assert(new Set(rows.map((r:any)=>r.recordId)).size===2005);
  }finally{await pg.close();}
});

Deno.test('company HTML designs persist in Postgres across fresh workspace sessions',async()=>{
  const {db:pg,company}=await setup();
  try {
    for(const section of ['Invoices','Quotations']) {
      const source=`<h1>Company ${section}</h1>{{items}}<b>{{record.total}}</b>`;
      const first=await workspace(client(pg),{id:owner},company);
      await first.business.saveDocumentDesign('',company,section,{source,expectedVersion:0});
      await first.commit();
      const next=await workspace(client(pg),{id:owner},company);
      const saved=companyDesign(next.company.configuration,section);
      assert(saved.source===source && saved.version===1);
    }
  } finally { await pg.close(); }
});

Deno.test('task writes atomically commit valid activity IDs and Realtime invalidation',async()=>{
  const {db:pg,company}=await setup();const db=client(pg),user={id:owner,email:'admin@example.test'},employee='e'.repeat(43);
  try{
    await pg.query(`insert into public.business_records(company_id,section,record_id,ordinal,version,payload)
      values($1,'Employees',$2,2,1,jsonb_build_object('recordId',$2::text,'companyId',$1::text,'recordVersion',1,'isDeleted',false,'fullName','Employee','employmentStatus','ACTIVE'))`,[company,employee]);
    const ctx=await workspace(db,user,company,['task_create_0001']);
    await ctx.business.mutate('',company,'Tasks',null,'create',{expectedVersion:0,values:{title:'Live task',employeeId:employee,status:'TODO',priority:'MEDIUM',dueDate:'2026-10-14',startDate:'',startTime:'',endTime:'',project:'',tags:'',reminder:'NONE',description:''}},'task_create_0001');
    await ctx.commit();
    const activity=await pg.query<{record_id:string}>(`select record_id from public.business_records where company_id=$1 and section='TaskActivity'`,[company]);
    assert(activity.rows.length===1&&activity.rows[0].record_id.length===43);
    const changes=await pg.query<{sections:string[]}>(`select sections from public.company_changes where company_id=$1`,[company]);
    assert(changes.rows.length===1&&changes.rows[0].sections.includes('Tasks')&&changes.rows[0].sections.includes('TaskActivity'));
  }finally{await pg.close();}
});

Deno.test('invoice draft, issue, ledger and idempotent retry commit through the Postgres adapter',async()=>{
  const {db:pg,company}=await setup();const db=client(pg),user={id:owner,email:'admin@example.test'};
  try{
    let ctx=await workspace(db,user,company,['customer_create_0001']);
    const customer=await ctx.business.mutate('',company,'Customers',null,'create',{expectedVersion:0,values:{name:'Customer'}},'customer_create_0001');await ctx.commit();
    ctx=await workspace(db,user,company,['invoice_create_0001']);
    const invoice=await ctx.business.mutate('',company,'Invoices',null,'create',{expectedVersion:0,values:{customerId:customer.recordId,
      issueDate:'2026-10-13',dueDate:'2026-10-27',currency:'AED',notes:'',paymentTerms:'',
      items:[{description:'Service',quantity:1,unitPrice:100,discount:0,taxRate:5}]}},'invoice_create_0001');await ctx.commit();
    ctx=await workspace(db,user,company,['invoice_issue_0001']);
    await ctx.business.mutate('',company,'Invoices',invoice.recordId,'issue',{expectedVersion:1},'invoice_issue_0001');await ctx.commit();
    const rows=await pg.query<{payload:any}>(`select payload from public.business_records where company_id=$1 and section='Invoices'`,[company]);
    assert(rows.rows[0].payload.status==='ISSUED'&&rows.rows[0].payload.total===105);
    const journals=await pg.query<{payload:any}>(`select payload from public.business_records where company_id=$1 and section='Journals'`,[company]);
    assert(journals.rows.length===1&&journals.rows[0].payload.totalDebit===105&&journals.rows[0].payload.totalCredit===105);
    ctx=await workspace(db,user,company,['invoice_issue_0001']);
    const replay=await ctx.business.mutate('',company,'Invoices',invoice.recordId,'issue',{expectedVersion:1},'invoice_issue_0001');await ctx.commit();assert(replay.replayed);
    const count=await pg.query<{count:number}>(`select count(*)::int as count from public.business_records where section='Journals'`);assert(count.rows[0].count===1);
  }finally{await pg.close();}
});
