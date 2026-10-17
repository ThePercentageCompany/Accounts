import {authorizeDocument,canDeleteDocument,deleteDocument} from '../_shared/documents.ts';

function assert(value:unknown) { if(!value)throw new Error('Assertion failed'); }
function fixture(admin=false,user='uploader') {
  const doc:any={documentId:'doc',path:'company/doc',relatedSection:'Tasks',relatedRecordId:'task',status:'READY',uploadedBy:'uploader',uploadedByEmployeeId:'employee'};
  const row:any={recordId:'doc',_row:2,createdBy:'uploader',recordVersion:1};
  const state:any={companies:{company:{documents:{doc}}}};
  let removed=0;
  const ctx:any={admin,user:{id:user},member:{employee_id:user==='uploader'?'employee':'other'},
    company:{id:'company'},principal:{writableSections:[]},
    read:async()=>[{recordId:'task',isDeleted:false}],
    registry:{read:async()=>({state}),transact:async(fn:any)=>fn(state)},
    records:{read:async()=>({DocumentRegistry:[row]}),write:async(_c:any,_t:any,_r:any,value:any)=>Object.assign(row,value)},
    db:{storage:{from:()=>({remove:async()=>{removed++;return {error:null};}})}}};
  return {ctx,doc,row,state,removed:()=>removed};
}

Deno.test('employees can upload task documents without task edit permission',async()=>{
  const {ctx}=fixture();
  await authorizeDocument(ctx,'Tasks','task',true);
  ctx.read=async()=>[];
  let rejected=false;try{await authorizeDocument(ctx,'Tasks','task',true);}catch{rejected=true;}
  assert(rejected);
});

Deno.test('staff can attach files to visible records without section edit permission',async()=>{
  for(const section of ['Tasks','Employees','Invoices','Expenses','Payroll','Assets']) {
    const {ctx}=fixture();
    await authorizeDocument(ctx,section,'task',true);
    ctx.read=async()=>[];
    let rejected=false;try{await authorizeDocument(ctx,section,'task',true);}catch{rejected=true;}
    assert(rejected);
  }
});

Deno.test('only admins and the uploader can delete, including legacy uploads',async()=>{
  const own=fixture();assert(await canDeleteDocument(own.ctx,own.doc));
  const other=fixture(false,'another');assert(!await canDeleteDocument(other.ctx,other.doc));
  let rejected=false;try{await deleteDocument(other.ctx,'doc');}catch{rejected=true;}
  assert(rejected&&other.removed()===0);
  const admin=fixture(true,'admin');assert(await canDeleteDocument(admin.ctx,admin.doc));
  const legacy={...own.doc};delete legacy.uploadedBy;delete legacy.uploadedByEmployeeId;
  assert(await canDeleteDocument(own.ctx,legacy));
  assert(!await canDeleteDocument(other.ctx,legacy));
});

Deno.test('delete removes storage, tombstones metadata and safely repeats',async()=>{
  const {ctx,doc,row,removed}=fixture();
  await deleteDocument(ctx,'doc');
  assert(doc.status==='DELETED'&&row.isDeleted&&row.recordVersion===2&&removed()===1);
  await deleteDocument(ctx,'doc');assert(removed()===1);
});
