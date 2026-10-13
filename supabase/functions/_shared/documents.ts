// deno-lint-ignore-file no-explicit-any
import { challenge, digest } from './domain/crypto.js';
import { requireThat } from './domain/errors.js';
import { databaseError } from './workspace.ts';

const sections=['Tasks','CompanyProfile','Invoices','CreditNotes','Receipts','Quotations','Income','Expenses','Employees','Payroll','Payslips','Assets'];
export async function authorizeDocument(ctx:any,section:string,id:string,write=false) {
  requireThat(sections.includes(section),400,'INVALID_DOCUMENT','Unsupported document section.');
  if(write)requireThat(ctx.admin||ctx.principal.writableSections.includes(({CompanyProfile:'Settings',Expenses:'Income & Expenses',Income:'Income & Expenses',Assets:'Fixed Assets',CreditNotes:'Invoices',Receipts:'Invoices',Payslips:'Payroll'} as any)[section]??section),403,'DOCUMENT_FORBIDDEN','Document upload access is not assigned.');
  const rows=await ctx.read(section);
  requireThat(rows.some((r:any)=>r.recordId===id && !r.isDeleted),403,'DOCUMENT_FORBIDDEN','Document record is unavailable.');
}
export async function uploadDocument(ctx:any,input:any,key:string) {
  requireThat(input && Object.keys(input).every(k=>['name','mimeType','section','relatedRecordId','data'].includes(k)) &&
    typeof input.name==='string'&&input.name.length>0&&input.name.length<=200 &&
    ['application/pdf','image/png','image/jpeg','text/html'].includes(input.mimeType)&&typeof input.data==='string' &&
    /^[A-Za-z0-9_-]{16,128}$/.test(key),400,'INVALID_DOCUMENT','Use a supported document and stable operation key.');
  await authorizeDocument(ctx,input.section,input.relatedRecordId,true);
  let bytes:Uint8Array;try{bytes=Uint8Array.from(atob(input.data),c=>c.charCodeAt(0));}catch{throw new Error('INVALID_DOCUMENT_BYTES');}
  requireThat(bytes.length>0&&bytes.length<=6291456,400,'DOCUMENT_SIZE','Documents must be between 1 byte and 6 MiB.');
  const signature=input.mimeType==='application/pdf'?new TextDecoder().decode(bytes.slice(0,5))==='%PDF-':input.mimeType==='image/png'?bytes[0]===137&&bytes[1]===80:input.mimeType==='image/jpeg'?bytes[0]===255&&bytes[1]===216:true;
  requireThat(signature,400,'DOCUMENT_TYPE','Document contents do not match the file type.');
  const id=challenge(`document:${ctx.company.id}:${key}`),path=`${ctx.company.id}/${id}`;
  const fingerprint=digest(JSON.stringify({name:input.name,mimeType:input.mimeType,section:input.section,relatedRecordId:input.relatedRecordId,data:input.data}));
  const state=(await ctx.registry.read()).state,old=state.companies[ctx.company.id].documents?.[id];
  if(old){requireThat(old.fingerprint===fingerprint,409,'IDEMPOTENCY_CONFLICT','This upload key was used for another document.');return {documentId:id,replayed:true};}
  const {error}=await ctx.db.storage.from('company-documents').upload(path,bytes,{contentType:input.mimeType,upsert:false});
  if(error){
    const {data:existing,error:de}=await ctx.db.storage.from('company-documents').download(path);
    if(de)databaseError(error);
    const saved=new Uint8Array(await existing.arrayBuffer());
    requireThat(saved.length===bytes.length&&saved.every((v,i)=>v===bytes[i]),409,'IDEMPOTENCY_CONFLICT','Stored upload differs.');
  }
  const descriptor={documentId:id,path,name:input.name,mimeType:input.mimeType,byteLength:bytes.length,
    relatedSection:input.section,relatedRecordId:input.relatedRecordId,fingerprint,status:'READY'};
  await ctx.registry.transact((next:any)=>{next.companies[ctx.company.id].documents??={};next.companies[ctx.company.id].documents[id]=descriptor;});
  const rows=(await ctx.records.read(ctx.company.id,['DocumentRegistry'])).DocumentRegistry;
  await ctx.records.write(ctx.company.id,'DocumentRegistry',Math.max(1,...rows.map((r:any)=>r._row))+1,
    {recordId:id,companyId:ctx.company.id,recordVersion:1,createdBy:ctx.user.id,updatedBy:ctx.user.id,createdAt:Date.now(),updatedAt:Date.now(),
      kind:input.section,name:input.name,mimeType:input.mimeType,byteLength:bytes.length,relatedSection:input.section,
      relatedRecordId:input.relatedRecordId,status:'READY',isDeleted:false});
  return {documentId:id};
}
export function publicDocument(d:any){return {documentId:d.documentId,name:d.name,mimeType:d.mimeType,byteLength:d.byteLength};}
