// Google Apps Script API executable. Google OAuth only. One internal admin workspace.
function setup_() {
  const ss=book_();
  for(const name of ['Customers','Invoices','Settings','Employees','Attendance','Payroll','Finance']) {
    let s=ss.getSheetByName(name);
    if(!s) s=ss.insertSheet(name);
    if(s.getLastRow()===0) s.appendRow(['ID','JSON']);
    s.setFrozenRows(1);
  }
  let ledger=ss.getSheetByName('Invoice Register');
  if(!ledger) ledger=ss.insertSheet('Invoice Register');
  if(!ledger.getLastRow()) ledger.appendRow(['ID','Number','Date','Customer','Status','Total AED','Paid AED','Balance AED','PDF']);
  let payments=ss.getSheetByName('Payment Register');
  if(!payments) payments=ss.insertSheet('Payment Register');
  if(!payments.getLastRow()) payments.appendRow(['Payment ID','Invoice','Date','Amount AED','Reference']);
}
function authorize_() {
 const email=Session.getActiveUser().getEmail().toLowerCase();
 const allowed=(PropertiesService.getScriptProperties().getProperty('ALLOWED_EMAILS')||'').split(',').map(x=>x.trim().toLowerCase());
 requireValue_(email&&allowed.includes(email),'Account is not authorised for this company');return email;
}
function book_() { authorize_(); return SpreadsheetApp.openById(PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID')); }
function sheet_(name) { const s=book_().getSheetByName(name); requireValue_(!!s,'Run setup_() first'); return s; }
function all_(name) { const s=sheet_(name); return s.getLastRow()<2?[]:s.getRange(2,2,s.getLastRow()-1,1).getValues().map(r=>JSON.parse(r[0])); }
function get_(name,id) { return all_(name).find(x=>x.id===id)||null; }
function put_(name,id,value) {
  const s=sheet_(name), count=s.getLastRow();
  const ids=count<2?[]:s.getRange(2,1,count-1,1).getValues().map(r=>r[0]);
  const index=ids.indexOf(id), json=JSON.stringify(value);
  requireValue_(json.length<49000,'Record too large; shorten text or reduce logo size');
  s.getRange(index<0?count+1:index+2,1,1,2).setValues([[id,json]]);
  SpreadsheetApp.flush();
  return value;
}
function defaultCompany_() {
  return {name:'The Percentage FZ LLC',address:'Dubai U.A.E',phone:'+971 56 331 9030',email:'thepercentagecompany1@gmail.com',trn:'',prefix:'TPC',accountHolder:'The Percentage FZ LLC',bank:'Mashreq Bank',accountNumber:'019102062841',iban:'',notes:'Thanks for your business.',terms:'Due on Receipt',logo:'',version:0};
}
function company_() { const s=get_('Settings','company'); return s?s.value:defaultCompany_(); }
function execute(req) {
  let lock;
  try {
    const email=authorize_();
    lock=LockService.getScriptLock();lock.waitLock(25000);
    requireValue_(req&&typeof req.action==='string','Invalid request');
    const actions=['load','saveCustomer','saveCompany','saveDraft','issue','pay','void','archive'];
    const result=actions.includes(req.action)?dispatch_(req.action,req.data||{},email):officeDispatch_(req.action,req.data||{},email);
    return {ok:true,result};
  }catch(e){return {ok:false,error:String(e.message||e)};}
  finally{if(lock&&lock.hasLock())lock.releaseLock();}
}
function persistInvoice_(i,actor) {
  // Invoice register is a rebuildable view; JSON rows are authoritative.
  put_('Invoices',i.id,i);
  try { updateRegisters_(i); } catch(e) { console.error('Register update failed for '+i.id); }
  return i;
}
function safeCell_(v) { return /^[=+\-@]/.test(String(v))?"'"+v:v; }
function upsertRegister_(name,id,values) {
  const s=sheet_(name), n=s.getLastRow();
  const ids=n<2?[]:s.getRange(2,1,n-1,1).getValues().map(r=>r[0]);
  const at=ids.indexOf(id);
  s.getRange(at<0?n+1:at+2,1,1,values.length).setValues([values.map(safeCell)]);
}
function updateRegisters_(i) {
  const t=totals_(i);
  upsertRegister_('Invoice Register',i.id,[i.id,i.number,i.date,i.customer.name,i.status,t.total/100,t.paid/100,t.balance/100,i.driveUrl]);
  for(const p of i.payments) upsertRegister_('Payment Register',p.id,[p.id,i.number,p.date,p.cents/100,p.reference]);
}
// Run manually to rebuild human-readable register views after a quota failure.
function rebuildRegisters_() { const lock=LockService.getScriptLock(); lock.waitLock(25000); try { all_('Invoices').forEach(updateRegisters_); } finally {lock.releaseLock();} }
function dispatch_(action,d,actor) {
  if(action==='load') return {company:company_(),customers:all_('Customers'),invoices:all_('Invoices')};
  if(action==='saveCustomer') {
    const c=customerValue_(d); checkVersion_(get_('Customers',c.id),d.version); c.version++; return put_('Customers',c.id,c);
  }
  if(action==='saveCompany') {
    const c=companyValue_(d); checkVersion_(company_(),d.version); c.version++; put_('Settings','company',{id:'company',value:c}); return c;
  }
  if(action==='saveDraft') {
    validId_(d.id); const existing=get_('Invoices',d.id);
    requireValue_(!existing || existing.status==='draft','Only drafts can be edited');
    checkVersion_(existing,d.version);
    const customer=get_('Customers',validId_(d.customer.id)); requireValue_(!!customer,'Save the customer first');
    const i={id:d.id,date:dateField_(d.date),customer,company:company_(),items:d.items.map(x=>({description:textField_(x.description,500,true),quantity:String(x.quantity),rate:String(x.rate)})),discount:String(d.discount),taxRate:String(d.taxRate),number:'',status:'draft',dueDate:d.dueDate?dateField_(d.dueDate):'',notes:textField_(d.notes,1000),terms:textField_(d.terms,300),payments:[],version:d.version+1,driveUrl:'',archivedVersion:0,issuedAt:''};
    if(i.dueDate) requireValue_(i.dueDate>=i.date,'Due date cannot precede invoice date');
    totals_(i); return persistInvoice_(i,actor);
  }
  const i=get_('Invoices',validId_(d.id)); requireValue_(!!i,'Invoice not found');
  if(action==='issue' && i.number) return i; // Retrying a timed-out issue never consumes another number.
  if(action==='pay' && i.payments.some(p=>p.id===d.payment.id)) return i;
  if(action==='void' && i.status==='void') return i;
  checkVersion_(i,d.version);
  if(action==='issue') {
    requireValue_(i.status==='draft','Only drafts can be issued'); totals_(i);
    i.company=company_(); // Snapshot current identity at issue time.
    const year=Utilities.formatDate(new Date(),'Asia/Dubai','yyyy');
    // Derive from persisted invoices under the script lock: no counter/write split.
    const prefix=i.company.prefix+'-'+year+'-';
    const seq=all_('Invoices').reduce((max,x)=>x.number.startsWith(prefix)?Math.max(max,Number(x.number.slice(prefix.length))||0):max,0)+1;
    i.number=invoiceNumber_(i.company.prefix,year,seq); i.status='issued'; i.issuedAt=new Date().toISOString(); i.version++;
    return persistInvoice_(i,actor);
  }
  if(action==='pay') {
    requireValue_(i.status==='issued','Only issued invoices accept payment');
    const p=d.payment;
    requireValue_(i.payments.length<100,'Payment limit reached');
    i.payments.push({id:validId_(p.id),cents:p.cents,date:dateField_(p.date),reference:textField_(p.reference,200),account:accountField_(p.account||'Bank')});
    totals_(i); i.version++; return persistInvoice_(i,actor);
  }
  if(action==='void') {
    requireValue_(i.status==='issued' && i.payments.length===0,'Only unpaid issued invoices can be voided');
    i.status='void'; i.version++; return persistInvoice_(i,actor);
  }
  if(action==='archive') {
    requireValue_(i.status!=='draft','Issue the invoice before archiving');
    requireValue_(typeof d.pdf==='string' && d.pdf.length<7000000,'PDF exceeds 5 MB');
    const bytes=Utilities.base64Decode(d.pdf);
    requireValue_(bytes.length>5 && bytes[0]===37 && bytes[1]===80 && bytes[2]===68 && bytes[3]===70 && bytes[4]===45,'Invalid PDF');
    const rootFolder=DriveApp.getFolderById(PropertiesService.getScriptProperties().getProperty('DRIVE_FOLDER_ID'));
    const folder=rootFolder.getFoldersByName ? (rootFolder.getFoldersByName('Invoices').hasNext() ? rootFolder.getFoldersByName('Invoices').next() : (rootFolder.createFolder ? rootFolder.createFolder('Invoices') : rootFolder)) : rootFolder;
    if(d.paymentId) requireValue_(i.payments.some(p=>p.id===d.paymentId),'Payment not found');
    const name=i.number+(d.paymentId?'-receipt-'+validId_(d.paymentId):'')+'-v'+i.version+'.pdf';
    const matches=folder.getFilesByName(name);
    // Version filename also makes retries idempotent after a Drive-success/Sheets-failure.
    const file=matches.hasNext()?matches.next():folder.createFile(Utilities.newBlob(bytes,'application/pdf',name));
    if(d.paymentId) return {url:file.getUrl()};
    i.driveUrl=file.getUrl(); i.archivedVersion=i.version;
    persistInvoice_(i,actor); return {url:i.driveUrl};
  }
  throw new Error('Unknown action');
}
