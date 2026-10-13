// deno-lint-ignore-file no-explicit-any
import {setup,assert,owner} from './_fixture.ts';
import {workspace} from '../_shared/workspace.ts';

function client(pg:any){
  return {
    from(table:string){
      assert(/^[a-z_]+$/.test(table));
      let columns='*',single=false,offset=0,limit=1000,order='';const filters:string[]=[],args:any[]=[];
      const query:any={
        select(c='*'){assert(/^[a-z_,*]+$/.test(c));columns=c;return query;},
        eq(k:string,v:any){assert(/^[a-z_]+$/.test(k));args.push(v);filters.push(`${k}=$${args.length}`);return query;},
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
      else if(name==='commit_workspace')result=await pg.query(`select public.commit_workspace($1,$2,$3,$4::jsonb,$5::jsonb,$6::jsonb,$7::jsonb) as value`,
        [input.p_company,input.p_actor,input.p_revision,JSON.stringify(input.p_changes),JSON.stringify(input.p_configuration),JSON.stringify(input.p_operations),JSON.stringify(input.p_audit)]);
      else throw new Error(`Unknown RPC ${name}`);
      return {data:result.rows[0].value,error:null};
    }catch(error){return {data:null,error:{message:String(error)}};}},
  };
}

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
