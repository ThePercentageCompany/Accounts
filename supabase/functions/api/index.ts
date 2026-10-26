import { notificationRequest } from '../_shared/notifications.ts';
import { notificationInput } from '../_shared/domain/notification-policy.js';
// deno-lint-ignore-file no-explicit-any
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { workspace,databaseError } from '../_shared/workspace.ts';
import { recordSyncAnchor,recordDelta } from '../_shared/record-sync.ts';
import { saveEmployee,employeeAccess } from '../_shared/employees.ts';
import { authorizeDocument,uploadDocument,publicDocument,deleteDocument,canDeleteDocument,embedCompanyLogo,authorizeDocumentDownload } from '../_shared/documents.ts';
import { ApiError,requireThat } from '../_shared/domain/errors.js';
import { TaskService } from '../_shared/domain/task-service.js';
import { previewPayroll } from '../_shared/domain/payroll-policy.js';
import { companyDesign,validateDesign,snapshotHtml,documentTables } from '../_shared/domain/document-design.js';
import { documentRoute } from '../_shared/domain/document-route.js';
import { SECTION_TABLES,recordsEndpointAllowed } from '../_shared/domain/employee-policy.js';
import { exchangeRate } from '../_shared/domain/foreign-currency.js';
import { groupOverview } from '../_shared/groups.ts';
import { employeeLoginPassword } from '../_shared/domain/employee-login.js';

const appOrigin=Deno.env.get('APP_ORIGIN')??'https://accounts.thepercentagecompany.com';
const supabaseUrl=Deno.env.get('SUPABASE_URL')!;
const publicKey=Deno.env.get('SUPABASE_ANON_KEY')!;
const db=createClient(supabaseUrl,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
const companyView=(c:any)=>({companyId:c.id,name:c.name,stage:'READY',version:Number(c.revision)+1,
  createdAt:Date.parse(c.created_at),updatedAt:Date.parse(c.updated_at),employeeInvitationsEnabled:true,nextAction:null,errorCode:null,
  groupId:c.group_id,countryCode:c.country_code,currency:c.base_currency,timeZone:c.time_zone});
const employeeView=(ctx:any)=>({companyId:ctx.company.id,employeeId:ctx.member.employee_id,name:ctx.principal.name,
  role:ctx.member.role,allowedSections:ctx.principal.allowedSections,writableSections:ctx.principal.writableSections,timeZone:ctx.company.time_zone});
const keyOf=(request:Request)=>request.headers.get('Idempotency-Key')??'';
const blocked=['DocumentRegistry','NumberSequences','Employees'];

async function processRequest(request:Request,guard:{context?:any}):Promise<Response> {
  const origin=request.headers.get('Origin');
  const allowed=[appOrigin,...(Deno.env.get('DEV_ORIGINS')??'').split(',').filter(Boolean)];
  const headers:Record<string,string>={'Cache-Control':'no-store','Content-Type':'application/json','Vary':'Origin'};
  if(origin&&allowed.includes(origin))headers['Access-Control-Allow-Origin']=origin;
  const json=(status:number,value:any)=>new Response(JSON.stringify(value),{status,headers});
  try {
    requireThat(!origin||allowed.includes(origin),403,'ORIGIN_DENIED','This app origin is not allowed.');
    if(request.method==='OPTIONS')return new Response(null,{status:204,headers:{...headers,
      'Access-Control-Allow-Headers':'authorization,apikey,content-type,idempotency-key,x-client-info,x-tpc-csrf,x-tpc-company,x-tpc-employee',
      'Access-Control-Allow-Methods':'GET,POST,PUT,PATCH,DELETE,OPTIONS'}});
    const url=new URL(request.url),path=url.pathname.replace(/^.*?\/api(?=\/|$)/,'');
    if(request.method==='GET'&&['/health','/healthz'].includes(path))return json(200,{status:'ok',phase:4,
      capabilities:['supabase-auth','supabase-postgres','supabase-storage','supabase-realtime','browser-html-pdf','shared-html-document-designs','extended-document-designs','embedded-company-logo','complete-document-drafts','invoice-item-returns','report-configuration','multi-currency','cash-bank-transfers','company-loans','task-management','task-calendar','task-attachments']});
    const raw=request.method==='GET'?'':await request.text();
    requireThat(new TextEncoder().encode(raw).length<=9*1024*1024,413,'BODY_TOO_LARGE','Request is too large.');
    let input:any={};if(raw){try{input=JSON.parse(raw);}catch{throw new ApiError(400,'INVALID_JSON','Use valid JSON.');}}
    if(path==='/v1/employee/login'&&request.method==='POST') {
      requireThat(/^[A-Za-z0-9_-]{43}$/.test(input.inviteId??'')&&typeof input.privateCode==='string'&&input.privateCode.length<=128,
        400,'INVALID_EMPLOYEE_LOGIN','Supply an employee invitation and private code.');
      const {data:invite,error}=await db.rpc('employee_invitation',{p_invite:input.inviteId});if(error)databaseError(error);
      requireThat(invite,401,'EMPLOYEE_ACCESS_DENIED','The invitation or private code is invalid.');
      const secret=Deno.env.get('EMPLOYEE_INVITE_KEY');
      if (/^[A-Za-z0-9]{4}$/.test(input.privateCode.trim())) {
        requireThat(secret && secret.length>=32,503,'INVITE_CONFIGURATION','Employee invitation signing is not configured.');
      }
      const password=employeeLoginPassword(secret??'',input.inviteId,input.privateCode);
      const auth=createClient(supabaseUrl,publicKey,{auth:{persistSession:false,autoRefreshToken:false}});
      const {data,error:ae}=await auth.auth.signInWithPassword({email:invite.auth_email,password});
      requireThat(!ae&&data.user?.id===invite.user_id&&data.session,401,'EMPLOYEE_ACCESS_DENIED','The invitation or private code is invalid.');
      const ctx=await workspace(db,{...data.user,sessionCreatedAt:new Date().toISOString()},invite.company_id);
      ctx.principal.name=(await ctx.records.read(invite.company_id,['Employees'])).Employees.find((r:any)=>r.recordId===invite.employee_id)?.fullName??'';
      return json(200,{employee:employeeView(ctx),expiresAt:data.session!.expires_at!*1000,
        session:{access_token:data.session!.access_token,refresh_token:data.session!.refresh_token}});
    }
    if(['/v1/auth/logout','/v1/employee/logout'].includes(path))return json(200,{});
    const token=request.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');
    requireThat(token,401,'UNAUTHORIZED','Sign in to continue.');
    const auth=createClient(supabaseUrl,publicKey,{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false,autoRefreshToken:false}});
    const {data:identity,error:ae}=await auth.auth.getUser(token);
    requireThat(!ae&&identity.user,401,'UNAUTHORIZED','Your session ended. Sign in again.');
    const user:any={...identity.user};
    const claims=JSON.parse(atob(token!.split('.')[1].replaceAll('-','+').replaceAll('_','/')));
    if(claims.session_id) {
      const {data,error}=await db.rpc('auth_session_created_at',{p_user:user.id,p_session:claims.session_id});if(error)databaseError(error);user.sessionCreatedAt=data;
    }
    if(path==='/v1/push-installation'&&request.method==='DELETE') {
      notificationInput('unregister',input);
      const {error}=await db.rpc('deactivate_push_installation',{p_actor:user.id,p_installation:input.installationId});if(error)databaseError(error);
      return json(200,{unregistered:true});
    }
    if(path==='/v1/me') {
      requireThat(user.app_metadata?.kind!=='employee',401,'UNAUTHORIZED','Use employee login for this account.');
      return json(200,{owner:{ownerId:user.id,email:user.email,name:user.user_metadata?.full_name??user.email}});
    }
    if(path==='/v1/groups'&&request.method==='GET') {
      requireThat(user.app_metadata?.kind!=='employee',403,'ADMIN_REQUIRED','Group access requires an admin account.');
      return json(200,await groupOverview(db,user.id));
    }
    if(path==='/v1/groups'&&request.method==='POST') {
      const {data,error}=await auth.rpc('create_business_group',{p_name:input.name,p_key:keyOf(request)});if(error)databaseError(error);
      return json(201,{group:data});
    }
    const countryEntity=/^\/v1\/groups\/([A-Za-z0-9_-]{43})\/entities$/.exec(path);
    const deletingGroup=/^\/v1\/groups\/([A-Za-z0-9_-]{43})$/.exec(path);
    if(deletingGroup&&request.method==='DELETE') {
      requireThat(user.app_metadata?.kind!=='employee',403,'ADMIN_REQUIRED','Only admins can delete business groups.');
      const {error}=await db.rpc('delete_business_group',{p_group:deletingGroup[1],p_actor:user.id});
      if(error?.message?.includes('GROUP_NOT_EMPTY'))throw new ApiError(409,'GROUP_NOT_EMPTY','Delete the group’s entities before deleting the business group.');
      if(error)databaseError(error);
      return json(200,{deleted:true});
    }
    if(countryEntity&&request.method==='POST'){
      const {data,error}=await auth.rpc('create_country_entity',{p_group:countryEntity[1],p_name:input.name,p_country:input.countryCode,
        p_currency:input.currency,p_zone:input.timeZone,p_tax:input.taxRegistration??'',p_key:keyOf(request)});if(error)databaseError(error);
      return json(201,{company:data});
    }
    if(path==='/v1/companies'&&request.method==='GET') {
      const {data,error}=await db.from('company_memberships').select('companies(*)').eq('user_id',user.id).eq('role','ADMIN').eq('status','ACTIVE');
      if(error)databaseError(error);return json(200,{companies:data.map((r:any)=>r.companies).filter((c:any)=>c&&!c.deleted_at).map(companyView)});
    }
    if(path==='/v1/companies'&&request.method==='POST') {
      requireThat(user.app_metadata?.kind!=='employee',403,'ADMIN_REQUIRED','Employees cannot register companies.');
      const {data,error}=await auth.rpc('create_workspace',{p_name:input.name,p_operation_key:keyOf(request)});
      if(error)databaseError(error);return json(201,{company:data,replayed:data.replayed});
    }
    const deleting=/^\/v1\/companies\/([A-Za-z0-9_-]{43})$/.exec(path);
    if(deleting&&request.method==='DELETE') {
      const {data:member,error:me}=await db.from('company_memberships').select('*').eq('company_id',deleting[1]).eq('user_id',user.id).eq('role','ADMIN').maybeSingle();if(me)databaseError(me);
      requireThat(member,403,'ADMIN_REQUIRED','Only company admins can delete a workspace.');
      const {data:company,error:ce}=await db.from('companies').select('deleted_at').eq('id',deleting[1]).maybeSingle();if(ce)databaseError(ce);
      if(!company)return json(200,{deleted:true});
      if(!company.deleted_at){const {error}=await db.rpc('begin_workspace_deletion',{p_company:deleting[1],p_actor:user.id});if(error)databaseError(error);}
      for(;;){const {data:files,error}=await db.storage.from('company-documents').list(deleting[1],{limit:100});if(error)databaseError(error);
        if(!files.length)break;const {error:de}=await db.storage.from('company-documents').remove(files.map(f=>`${deleting[1]}/${f.name}`));if(de)databaseError(de);}
      const {error}=await db.rpc('complete_workspace_deletion',{p_company:deleting[1],p_actor:user.id});if(error)databaseError(error);
      return json(200,{deleted:true});
    }
    const companyMatch=/^\/v1\/(?:employee\/)?companies\/([A-Za-z0-9_-]{43})(?:\/|$)/.exec(path);
    let companyId=companyMatch?.[1]??request.headers.get('X-TPC-Company');
    if(!companyId&&path.startsWith('/v1/employee/')) {
      const {data,error}=await db.from('company_memberships').select('company_id').eq('user_id',user.id).eq('status','ACTIVE').not('employee_id','is',null).limit(1);
      if(error)databaseError(error);companyId=data[0]?.company_id;
    }
    requireThat(companyId,401,'EMPLOYEE_SESSION_INVALID','Company access is unavailable.');
    const keys=input.operations?.map((op:any)=>op.operationId)??[keyOf(request)].filter(Boolean);
    const ctx=await workspace(db,user,companyId!,keys);
    guard.context=ctx;
    const employeeMode=path.startsWith('/v1/employee/');
    requireThat(employeeMode||ctx.admin,403,'ADMIN_REQUIRED','This action requires company admin access.');
    requireThat(!request.headers.get('X-TPC-Company')||request.headers.get('X-TPC-Company')===companyId,403,'WORKSPACE_CHANGED','Workspace changed.');
    requireThat(!request.headers.get('X-TPC-Employee')||request.headers.get('X-TPC-Employee')===ctx.member.employee_id,403,'WORKSPACE_CHANGED','Employee identity changed.');
    if(employeeMode) {
      requireThat(ctx.member.employee_id,401,'EMPLOYEE_SESSION_INVALID','Employee access is unavailable.');
      ctx.principal.name=(await ctx.records.read(companyId!,['Employees'])).Employees.find((r:any)=>r.recordId===ctx.member.employee_id)?.fullName??'';
    }
    if(['/v1/employee/me','/v1/employee/refresh'].includes(path))return json(200,{employee:employeeView(ctx),expiresAt:claims.exp*1000});
    const finish=async(value:any,status=200)=>{await ctx.commit();return json(status,value);};
    const tail=companyMatch?path.slice(companyMatch[0].length- (companyMatch[0].endsWith('/')?1:0)) : path.replace('/v1/employee','');
    if(tail==='/overview'&&request.method==='GET'){
      requireThat(ctx.admin,403,'ADMIN_REQUIRED','Entity overview requires admin access.');
      const overview=await groupOverview(db,user.id,companyId!);return json(200,{entity:overview.entities[0]});
    }
    if(tail==='/setup'||tail==='/setup/retry')return json(200,{company:companyView(ctx.company)});
    if(tail==='/employees'&&request.method==='GET') {
      const employees=await ctx.read('Employees');
      const {data:members,error}=await db.from('company_memberships').select('employee_id,status').eq('company_id',companyId);if(error)databaseError(error);
      return json(200,{employees:employees.map((e:any)=>({...e,accessStatus:members.find((m:any)=>m.employee_id===e.recordId)?.status??'NOT_ISSUED'}))});
    }
    const employee=/^\/employees(?:\/([A-Za-z0-9_-]{43}))?$/.exec(tail);
    if(employee&&['POST','PATCH'].includes(request.method))return finish(await saveEmployee(ctx,employee[1]??null,input,keyOf(request)),request.method==='POST'?201:200);
    const access=/^\/employees\/([A-Za-z0-9_-]{43})\/access\/(issue|reset|revoke)$/.exec(tail);
    if(access&&request.method==='POST') {
      requireThat(ctx.admin,403,'ADMIN_REQUIRED','Only company admins can manage access.');
      return json(200,await employeeAccess(db,user,companyId!,access[1],access[2],keyOf(request),appOrigin));
    }
    const loanHistory=/^\/records\/CompanyLoans\/([A-Za-z0-9_-]{43})\/history$/.exec(tail);
    if(loanHistory&&request.method==='GET') {
      requireThat((await ctx.read('CompanyLoans')).some((r:any)=>r.recordId===loanHistory[1]),403,'RECORD_FORBIDDEN','Loan is unavailable.');
      const data=await ctx.records.read(companyId!,['Journals','JournalLines']);
      const journals=data.Journals.filter((j:any)=>j.sourceId===loanHistory[1]&&['CompanyLoanReceipt','CompanyLoanRepayment'].includes(j.sourceType)&&!j.isDeleted);
      return json(200,{journals:journals.sort((a:any,b:any)=>a.date.localeCompare(b.date)||a.recordId.localeCompare(b.recordId)).map((j:any)=>({...j,
        lines:data.JournalLines.filter((l:any)=>l.journalId===j.recordId&&!l.isDeleted)}))});
    }
    const loan=/^\/records\/CompanyLoans\/([A-Za-z0-9_-]{43})\/(post|repay)$/.exec(tail);
    if(loan&&request.method==='POST')return finish(await ctx.business.mutate('',companyId!,'CompanyLoans',loan[1],
      loan[2]==='post'?'loanPost':'loanRepay',input,keyOf(request)));
    const transfer=/^\/records\/MoneyTransfers\/([A-Za-z0-9_-]{43})\/(post|reverse|match)$/.exec(tail);
    if(transfer&&request.method==='POST')return finish(await ctx.business.mutate('',companyId!,'MoneyTransfers',transfer[1],
      ({post:'transferPost',reverse:'transferReverse',match:'transferMatch'} as any)[transfer[2]],input,keyOf(request)));
    if(tail==='/sync'&&request.method==='POST') {
      requireThat(Array.isArray(input.operations)&&input.operations.length>0&&input.operations.length<=50,400,'INVALID_BATCH','Supply up to 50 operations.');
      const results=[];let stopped=false;
      for(const op of input.operations) {
        if(stopped){results.push({operationId:op.operationId,status:'NOT_ATTEMPTED'});continue;}
        try {
          let result:any;
          if(op.table==='Employees')result=await saveEmployee(ctx,op.recordId??null,{...op.values,expectedVersion:op.expectedVersion},op.operationId);
          else if(op.table==='ReportSettings'){
            requireThat(ctx.admin,403,'ADMIN_REQUIRED','Only admins can change report settings.');
            result=await ctx.business.saveReportSettings('',companyId!,{...op.values,expectedVersion:op.expectedVersion});
          }
          else {
            requireThat(!blocked.includes(op.table),403,'TABLE_FORBIDDEN','This section is not writable through records.');
            const noValues=['delete','post','issue','send','convert','approve','capitalize','capitalPost','loanPost','transferPost'].includes(op.action);
            result=await ctx.business.mutate('',companyId!,op.table,op.recordId??null,op.action,{expectedVersion:op.expectedVersion,...(noValues?{}:{values:op.values})},op.operationId);
          }
          results.push({operationId:op.operationId,status:'APPLIED',...result});
        }catch(e){if(!(e instanceof ApiError))throw e;results.push({operationId:op.operationId,status:'FAILED',error:{code:e.code,message:e.message,status:e.status}});stopped=true;}
      }
      return finish({results});
    }
    const delta=/^\/record-changes\/([A-Za-z]+)$/.exec(tail);
    if(delta&&request.method==='GET') {
      requireThat(recordsEndpointAllowed(delta[1],'GET',false),403,'TABLE_FORBIDDEN','This section is unavailable through records.');
      return json(200,await recordDelta(ctx,delta[1],url.searchParams));
    }
    const record=/^\/records\/([A-Za-z]+)(?:\/([A-Za-z0-9_-]{43}|company))?$/.exec(tail);
    const structured=/^\/structured-records\/([A-Za-z]+)$/.exec(tail);
    if(structured&&request.method==='GET') {
      requireThat(ctx.admin,403,'ADMIN_REQUIRED','Structured records require admin access.');
      ctx.records.table(structured[1]);
      const after=Number(url.searchParams.get('after')??0),limit=Number(url.searchParams.get('limit')??100);
      requireThat(Number.isSafeInteger(after)&&after>=0&&Number.isSafeInteger(limit)&&limit>=1&&limit<=500,
        400,'INVALID_PAGE','Use a positive cursor and a page size between 1 and 500.');
      const {data,error}=await db.rpc('structured_record_page',{p_company:companyId,p_section:structured[1],p_after:after,p_limit:limit});
      if(error)databaseError(error);
      return json(200,{records:data,nextCursor:data.length===limit?data[data.length-1].ordinal:null});
    }
    if(record) {
      requireThat(recordsEndpointAllowed(record[1],request.method,!!record[2]),403,'TABLE_FORBIDDEN','This section is unavailable through records.');
      if(request.method==='GET'&&!record[2]) {
        const anchor=await recordSyncAnchor(ctx);
        return json(200,{records:await ctx.read(record[1],url.searchParams.get('includeDeleted')==='true'),...anchor});
      }
      const action=({POST:'create',PATCH:'update',DELETE:'delete'} as any)[request.method];
      if(action)return finish(await ctx.business.mutate('',companyId!,record[1],record[2]??null,action,input,keyOf(request)),action==='create'?201:200);
    }
    const documentEndpoint=documentRoute(tail);
    if(documentEndpoint?.kind==='document-designs') {
      const section=documentEndpoint.section;
      ctx.canRead(['Receipts','CreditNotes'].includes(section)?'Invoices':section);
      if(request.method==='GET')return json(200,companyDesign(ctx.company.configuration,section));
      requireThat(ctx.admin&&request.method==='PUT',403,'ADMIN_REQUIRED','Only admins can save designs.');
      return finish(await ctx.business.saveDocumentDesign('',companyId!,section,input));
    }
    if(documentEndpoint?.kind==='record-html') {
      const section=documentEndpoint.section,id=documentEndpoint.recordId!;
      requireThat((await ctx.read(section)).some((r:any)=>r.recordId===id),403,'DOCUMENT_FORBIDDEN','Document is unavailable.');
      requireThat(request.method==='GET'||request.method==='POST'&&ctx.admin,403,'ADMIN_REQUIRED','Only admins can preview unsaved designs.');
      const source=request.method==='POST'?input.source:companyDesign(ctx.company.configuration,section).source;validateDesign(source);
      const rows=await ctx.records.read(companyId!,documentTables(section));
      await embedCompanyLogo(ctx,rows);
      return new Response(snapshotHtml(source,section,id,rows),{headers:{...headers,'Content-Type':'text/html; charset=utf-8'}});
    }
    if(tail==='/payroll/preview'&&request.method==='POST') {
      requireThat(ctx.admin||ctx.principal.writableSections.includes('Payroll'),403,'WRITE_FORBIDDEN','Payroll edit access is required.');
      return json(200,{totals:await previewPayroll(ctx.records,companyId!,input)});
    }
    const reference=/^\/references\/(CompanyProfile|Customers|Projects|Employees|Shareholders)$/.exec(tail);
    if(reference) {
      const section=url.searchParams.get('section')??'';
        const editorSections:Record<string,string[]>={CompanyProfile:['Invoices','Quotations','Payroll'],Customers:['Invoices','Quotations'],Projects:['Tasks'],Employees:['Payroll'],Shareholders:['Capital & Equity']};
        requireThat(ctx.admin||reference[1]==='Projects'&&ctx.principal.permissions.Tasks||editorSections[reference[1]].includes(section)&&ctx.principal.writableSections.includes(section),403,'REFERENCE_FORBIDDEN','Editor access is required.');
        const permitted=({CompanyProfile:['recordId','name','address','email','phone','taxNumber','currency','invoicePrefix','quotationPrefix','logoDocumentId'],Customers:['recordId','name','email','phone','taxNumber','address','preferredCurrency'],Projects:['recordId','name','status'],Employees:['recordId','employeeCode','fullName','employmentStatus','basicSalary','allowances','currency'],Shareholders:['recordId','name','status']} as any)[reference[1]];
      const rows=(await ctx.records.read(companyId!,[reference[1]]))[reference[1]];
      return json(200,{records:rows.filter((r:any)=>!r.isDeleted).map((r:any)=>Object.fromEntries(permitted.map((k:string)=>[k,r[k]??''])))});
    }
    const report=/^\/reports\/(dashboard|general-ledger|trial-balance|profit-and-loss|balance-sheet|settings)$/.exec(tail);
    if(report) {
      ctx.canRead('Reports');
      requireThat(ctx.admin||ctx.principal.permissions.Reports==='COMPANY',403,'SECTION_FORBIDDEN','Company-wide reports are not assigned.');
      if(report[1]==='settings') {
        if(request.method==='GET')return json(200,await ctx.business.reportSettings('',companyId!));
        requireThat(ctx.admin,403,'ADMIN_REQUIRED','Only admins can change report settings.');return finish(await ctx.business.saveReportSettings('',companyId!,input));
      }
      const from=url.searchParams.get('from'),asOf=url.searchParams.get('asOf');
      const options={compareFrom:url.searchParams.get('compareFrom'),compareAsOf:url.searchParams.get('compareAsOf')};
      return json(200,await ctx.business.financialReport('',companyId!,report[1],from,asOf,options));
    }
    const tasks=/^\/tasks(?:\/(assignees|[A-Za-z0-9_-]{43}))?$/.exec(tail);
    if(tasks) {
      ctx.canRead('Tasks');
      const employees:any={principal:async()=>ctx.principal,verifyContext:()=>{},records:async(_t:any,table:string)=>ctx.read(table)};
      const service=new TaskService({business:ctx.business,employees});
      const value=tasks[1]==='assignees'?await service.assignees('',companyId!,employeeMode,{},url.searchParams)
        :tasks[1]?await service.detail('',companyId!,tasks[1],employeeMode,{}):await service.list('',companyId!,url.searchParams,employeeMode,{timeZone:ctx.company.time_zone});
      return json(200,value);
    }
    const documents=/^\/documents(?:\/([A-Za-z0-9_-]{43}))?$/.exec(tail);
    if(documents) {
      if(request.method==='DELETE'&&documents[1])return finish(await deleteDocument(ctx,documents[1]));
      if(request.method==='POST'&&!documents[1])return finish(await uploadDocument(ctx,input,keyOf(request)),201);
      const descriptors=Object.values(ctx.company.configuration.documents??{}) as any[];
      if(documents[1]) {
        const doc=descriptors.find(d=>d.documentId===documents[1]&&d.status!=='DELETED');requireThat(doc,404,'DOCUMENT_UNAVAILABLE','Document is unavailable.');
        await authorizeDocumentDownload(ctx,doc);
        const {data,error}=await db.storage.from('company-documents').download(doc.path);if(error)databaseError(error);
        return new Response(data,{headers:{...headers,'Content-Type':doc.mimeType,'Content-Disposition':`attachment; filename*=UTF-8''${encodeURIComponent(doc.name)}`}});
      }
      const section=url.searchParams.get('section')??'',recordId=url.searchParams.get('recordId')??'';
      await authorizeDocument(ctx,section,recordId);
      return json(200,{documents:await Promise.all(descriptors.filter(d=>d.status!=='DELETED'&&d.relatedSection===section&&d.relatedRecordId===recordId)
        .map(async d=>({...publicDocument(d),canDelete:await canDeleteDocument(ctx,d)})))});
    }
    if(tail==='/notifications'&&request.method==='GET')return json(200,await notificationRequest(ctx,'list',Object.fromEntries(url.searchParams)));
    if(tail==='/notifications/read'&&request.method==='POST')return json(200,await notificationRequest(ctx,'read',input));
    if(tail==='/notifications/settings') {
      if(request.method==='GET')return json(200,await notificationRequest(ctx,'list',{limit:1}));
      if(request.method==='PUT')return json(200,await notificationRequest(ctx,'settings',input));
    }
    if(tail==='/notifications/preferences'&&request.method==='PUT')return json(200,await notificationRequest(ctx,'preferences',input));
    if(tail==='/notifications/subscription'&&['POST','DELETE'].includes(request.method))
      return json(200,await notificationRequest(ctx,request.method==='POST'?'register':'unregister',input));
    if(tail==='/exchange-rate') {
      requireThat(ctx.admin||['Settings','Invoices','Quotations','Payroll','Income & Expenses'].some(s=>ctx.principal.permissions[s]),403,'SECTION_FORBIDDEN','Financial record access is required.');
      const currency=url.searchParams.get('currency'),date=url.searchParams.get('date');
      const profile=(await ctx.records.read(companyId!,['CompanyProfile'])).CompanyProfile.find((r:any)=>r.recordId==='company');
      return json(200,await exchangeRate(currency,profile?.currency,date));
    }
    throw new ApiError(404,'NOT_FOUND','Endpoint not found.');
  }catch(error) {
    if(error instanceof ApiError)return json(error.status,{error:{code:error.code,message:error.message}});
    return json(503,{error:{code:'SERVICE_UNAVAILABLE',message:'Could not complete this request. Retry without discarding changes.'}});
  }
}
export async function handler(request:Request):Promise<Response> {
  const access:{context?:any}={};
  const response=await processRequest(request,access);
  if(response.ok&&access.context) {
    try{await access.context.assertAccess();}
    catch(error){const e=error instanceof ApiError?error:new ApiError(503,'SERVICE_UNAVAILABLE','Could not verify access. Retry.');
      return new Response(JSON.stringify({error:{code:e.code,message:e.message}}),{status:e.status,headers:{
        'Content-Type':'application/json','Cache-Control':'no-store',...(response.headers.get('Access-Control-Allow-Origin')?{'Access-Control-Allow-Origin':response.headers.get('Access-Control-Allow-Origin')!}:{})}});
    }
  }
  return response;
}
if(import.meta.main)Deno.serve(handler);
