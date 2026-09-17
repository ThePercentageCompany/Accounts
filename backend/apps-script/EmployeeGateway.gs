// Deploy as an Apps Script web app, executing as the workspace owner.
// This gateway is independent of the legacy Google-only execute() API.
// EmployeeAccess is private authentication/audit storage, never a sync tab.
const EG_HEADERS_ = {
  Customers: ['Customer ID','Customer Name','Email Address','Phone Number','TRN / Tax Number','Company Address','Version'],
  Invoices: ['Invoice ID','Invoice Number','Issue Date','Due Date','Customer Name','Customer ID','Status','Tax Rate %','Discount AED','Subtotal AED','Tax Amount AED','Total Amount AED','Paid Amount AED','Balance Due AED','Items Summary','Payment Details','Notes','Payment Terms','Drive PDF Link','Issued At','Version'],
  Quotations: ['Quotation ID','Quotation Number','Issue Date','Valid Until','Customer Name','Customer ID','Status','Tax Rate %','Discount AED','Subtotal AED','Tax Amount AED','Total Amount AED','Items Summary','Notes','Payment Terms','Converted Invoice ID','Drive PDF Link','Issued At','Version'],
  Finance: ['Entry ID','Date','Transaction Kind','Category','Description','Amount AED','VAT %','VAT Amount AED','Total Amount AED','Payment Status','Paid Date','Due Date','Account / Method','Supplier / Payee','Reference / Doc #','Notes','Version','Attachment Drive Links'],
  Employees: ['Employee ID','Employee Code','Full Name','Role / Designation','Department','Join Date','Basic Salary AED','Allowances AED','Total Monthly Salary AED','Phone Number','Email Address','Employment Status','IBAN / Bank Account','Notes','Version','Attachment Drive Links','Address','Bank Name','Emirates ID','Passport Number','Visa Expiry','Last Employment Date','System Role','Allowed Sections','Google Email','Created By','Updated By'],
  Attendance: ['Attendance ID','Date','Employee ID','Employee Name','Attendance Status','Overtime Hours','Notes','Version'],
  Payroll: ['Payroll ID','Payroll Month','Employee ID','Employee Name','Basic Salary AED','Allowances AED','Overtime Amount AED','Bonus AED','Deductions AED','Gross Salary AED','Net Salary AED','Payment Status','Paid Date','Payment Account','Version','Drive Payslip Link','Unpaid Absence Deduction AED','Salary Daily Divisor','Base Paid Days','Scheduled Working Days','Marked Working Days','Unpaid Days','Overtime Rate AED','Adjustment Note','Payment Reference'],
  Shareholders: ['Shareholder ID','Shareholder Name','Role / Title','Equity Share %','Agreed Capital AED','Investment Date','Email Address','Phone Number','Status','Notes','Version'],
  CapitalTransactions: ['Transaction ID','Transaction Date','Shareholder ID','Shareholder Name','Transaction Type','Contribution Method','Capital Amount AED','Asset Name / Details','Destination Account','Status','Reference / Doc #','Notes','Version'],
  ShareholderLoans: ['Loan ID','Loan Date','Shareholder ID','Shareholder Name','Loan Action / Type','Principal Amount AED','Interest Rate %','Repaid Amount AED','Outstanding Balance AED','Due Date','Payment Account','Loan Status','Reference / Doc #','Notes','Version'],
  Assets: ['Asset ID','Asset Name','Asset Category','Purchase Date','Purchase Cost AED','Useful Life (Years)','Residual Value AED','Depreciation Method','Accumulated Depreciation AED','Net Book Value AED','Status','Notes','Version','Last Depreciation Month','Asset Code','Acquisition Type','Payment Account','Shareholder ID','Shareholder Name','Location','Assigned Employee ID','Assigned Employee Name','Serial Number','Acquisition Journal ID'],
  Journals: ['Journal ID','Entry Date','Entry Number / Ref','Description','Transaction Type','Debit Account','Credit Account','Amount AED','Notes','Version','Source Type','Source ID','Total Debit AED','Total Credit AED','Balanced','Status','Journal Lines (Account ID | Name | Group | Debit AED | Credit AED)'],
  Settings: ['Setting Key','Company Name','Email Address','Phone Number','TRN / Tax Number','Invoice Prefix','Company Address','Bank Name','Account Holder','Account Number','IBAN','Default Payment Terms','Default Notes','Version','Company Logo Drive Link']
};
const EG_SECTIONS_ = ['Dashboard','Invoices','Quotations','Income & Expenses','Capital & Equity','Fixed Assets','Balance Sheet','Customers','Employees','Payroll','Reports','Settings','Office & Attendance'];
const EG_ACCESS_HEADERS_ = ['Key','Kind','Employee ID','Digest','Salt','Expires At','Revoked At','Details'];

function egFail_(message, code) { const e = new Error(message); e.egCode = code || 'INVALID_REQUEST'; throw e; }
function egRequire_(condition, message, code) { if (!condition) egFail_(message, code); }
function egText_(value) { return value === undefined || value === null ? '' : String(value); }
function egId_(value) { const s = egText_(value); egRequire_(/^[a-zA-Z0-9_-]{1,160}$/.test(s), 'Invalid record identifier.'); return s; }
function egRandom_() { return Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, ''); }
function egHash_(value) { return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, value, Utilities.Charset.UTF_8).map(b => ('0' + ((b + 256) % 256).toString(16)).slice(-2)).join(''); }
function egEqual_(a,b) { a=egText_(a); b=egText_(b); let diff=a.length ^ b.length; for(let i=0;i<Math.max(a.length,b.length);i++) diff|=(a.charCodeAt(i)||0)^(b.charCodeAt(i)||0); return diff===0; }
function egNormalizeCode_(value) { return egText_(value).replace(/[\s-]/g, '').toUpperCase(); }
function egConfig_() {
  const props=PropertiesService.getScriptProperties();
  const spreadsheetId=props.getProperty('SPREADSHEET_ID');
  const driveFolderId=props.getProperty('DRIVE_FOLDER_ID')||props.getProperty('ROOT_FOLDER_ID');
  const effective=egText_(Session.getEffectiveUser().getEmail()).trim().toLowerCase();
  const ownerEmail=egText_(props.getProperty('OWNER_EMAIL')||effective).trim().toLowerCase();
  egRequire_(spreadsheetId&&driveFolderId&&ownerEmail&&ownerEmail===effective, 'Gateway owner configuration is incomplete.', 'CONFIGURATION');
  let pepper=props.getProperty('EMPLOYEE_AUTH_PEPPER');
  if(!pepper) { pepper=egRandom_(); props.setProperty('EMPLOYEE_AUTH_PEPPER',pepper); }
  return {spreadsheetId,driveFolderId,ownerEmail,pepper};
}
function egBook_(config) { return SpreadsheetApp.openById(config.spreadsheetId); }
function egStorage_(config) {
  const book=egBook_(config); let sheet=book.getSheetByName('EmployeeAccess');
  if(!sheet) { sheet=book.insertSheet('EmployeeAccess'); sheet.getRange(1,1,1,EG_ACCESS_HEADERS_.length).setValues([EG_ACCESS_HEADERS_]); sheet.setFrozenRows(1); sheet.hideSheet(); }
  const rows=sheet.getDataRange().getValues();
  egRequire_(JSON.stringify(rows[0])===JSON.stringify(EG_ACCESS_HEADERS_), 'EmployeeAccess headers were changed.', 'CONFIGURATION');
  return {sheet,rows};
}
function egPrivateGet_(config,key) { const store=egStorage_(config); const row=store.rows.find((r,i)=>i>0&&r[0]===key); return row ? {key:row[0],kind:row[1],employeeId:row[2],digest:row[3],salt:row[4],expiresAt:Number(row[5])||0,revokedAt:row[6],details:JSON.parse(row[7]||'{}')} : null; }
function egPrivatePut_(config,value) {
  const store=egStorage_(config), index=store.rows.findIndex(r=>r[0]===value.key);
  const row=[value.key,value.kind,value.employeeId||'',value.digest||'',value.salt||'',value.expiresAt||0,value.revokedAt||'',JSON.stringify(value.details||{})];
  store.sheet.getRange(index<0?store.rows.length+1:index+1,1,1,row.length).setValues([row]);
}
// Read by header name, preserving canonical client order even if the owner moved columns.
function egTable_(config,tab) {
  egRequire_(Object.prototype.hasOwnProperty.call(EG_HEADERS_,tab), 'This data table is not available.', 'FORBIDDEN');
  const sheet=egBook_(config).getSheetByName(tab), headers=EG_HEADERS_[tab];
  if(!sheet||sheet.getLastRow()===0) return {sheet,headers:headers.slice(),rawHeaders:headers.slice(),rows:[],rawRows:[]};
  const raw=sheet.getDataRange().getValues(), rawHeaders=raw[0].map(egText_);
  egRequire_(headers.every(h=>rawHeaders.includes(h)), 'Workspace schema needs updating: '+tab, 'CONFIGURATION');
  const rows=raw.slice(1).map(r=>headers.map(h=>{const v=r[rawHeaders.indexOf(h)]; return v instanceof Date ? Utilities.formatDate(v,'UTC','yyyy-MM-dd') : v===undefined?'':v;}));
  return {sheet,headers,rawHeaders,rows,rawRows:raw.slice(1)};
}
function egEmployee_(config,id) {
  const table=egTable_(config,'Employees'), row=table.rows.find(r=>egText_(r[0])===id);
  egRequire_(row, 'Employee access is no longer available.', 'UNAUTHORIZED');
  const get=h=>row[table.headers.indexOf(h)];
  const status=egText_(get('Employment Status')).toLowerCase();
  egRequire_(status==='active'&&(!get('Last Employment Date')||egText_(get('Last Employment Date'))>=Utilities.formatDate(new Date(),'UTC','yyyy-MM-dd')), 'Employee access is disabled.', 'UNAUTHORIZED');
  const sections=egText_(get('Allowed Sections')).split(',').map(s=>s.trim()).filter(s=>EG_SECTIONS_.includes(s));
  return {id,code:egText_(get('Employee Code')),name:egText_(get('Full Name')),role:egText_(get('System Role'))||'Staff',sections:sections.length?sections:['Dashboard'],row};
}
function egHas_(employee,sections) { return sections.some(s=>employee.sections.includes(s)); }
function egWorkspace_(config,employee) {
  const company=egTable_(config,'Settings').rows.find(r=>r[0]==='company');
  return {spreadsheetId:config.spreadsheetId,driveFolderId:config.driveFolderId,companyName:company?egText_(company[1]):'Company',isEmployee:true,employeeId:employee.id,employeeName:employee.name,employeeCode:employee.code,employeeRole:employee.role,allowedSections:employee.sections};
}
function egOwner_(config,token) {
  egRequire_(typeof token==='string'&&token.length>=20&&token.length<4096, 'Owner Google sign-in is required.', 'UNAUTHORIZED');
  const response=UrlFetchApp.fetch('https://www.googleapis.com/oauth2/v3/userinfo',{headers:{Authorization:'Bearer '+token},muteHttpExceptions:true});
  egRequire_(response.getResponseCode()===200, 'Owner Google session expired.', 'UNAUTHORIZED');
  let identity; try {identity=JSON.parse(response.getContentText());} catch(_) {egFail_('Owner identity could not be verified.','UNAUTHORIZED');}
  egRequire_(identity.email_verified===true&&egText_(identity.email).trim().toLowerCase()===config.ownerEmail, 'Only the workspace owner can manage employee access.', 'FORBIDDEN');
}
function egProvision_(config,data,token) {
  egOwner_(config,token);
  egRequire_(data.spreadsheetId===config.spreadsheetId&&data.driveFolderId===config.driveFolderId,
    'Employee gateway belongs to another workspace. Check the app configuration.', 'CONFIGURATION');
  const id=egId_(data.employeeId); egEmployee_(config,id);
  const key='credential:'+id, existing=egPrivateGet_(config,key);
  if(existing&&!existing.revokedAt&&!data.reset) return {employeeId:id,exists:true};
  const raw=egRandom_().slice(0,20).toUpperCase(), salt=egRandom_();
  egPrivatePut_(config,{key,kind:'credential',employeeId:id,salt,digest:egHash_(config.pepper+':'+salt+':'+raw),details:{generation:egRandom_(),createdAt:new Date().toISOString()}});
  return {employeeId:id,exists:true,loginCode:raw.match(/.{1,4}/g).join('-')};
}
function egRate_(key,limit,seconds) { const cache=CacheService.getScriptCache(), value=Number(cache.get(key)||0)+1; cache.put(key,String(value),seconds); egRequire_(value<=limit,'Too many sign-in attempts. Try again later.','RATE_LIMITED'); }
function egLogin_(config,data) {
  egRate_('eg:login:global',120,900);
  const id=egId_(data.employeeId); egRate_('eg:login:'+egHash_(id),8,900);
  const credential=egPrivateGet_(config,'credential:'+id), code=egNormalizeCode_(data.loginCode);
  egRequire_(credential&&!credential.revokedAt&&/^[A-Z0-9]{20}$/.test(code)&&egEqual_(credential.digest,egHash_(config.pepper+':'+credential.salt+':'+code)), 'Employee code is incorrect or has been reset.', 'UNAUTHORIZED');
  const employee=egEmployee_(config,id), token=egRandom_(), digest=egHash_(token), expiresAt=Date.now()+12*60*60*1000;
  egPrivatePut_(config,{key:'session:'+digest,kind:'session',employeeId:id,digest,expiresAt,details:{generation:credential.details.generation}});
  CacheService.getScriptCache().remove('eg:login:'+egHash_(id));
  return {sessionToken:token,expiresAt:new Date(expiresAt).toISOString(),workspace:egWorkspace_(config,employee)};
}
function egAuthenticate_(config,token) {
  egRequire_(typeof token==='string'&&/^[a-f0-9]{64}$/.test(token),'Employee sign-in is required.','UNAUTHORIZED');
  const session=egPrivateGet_(config,'session:'+egHash_(token));
  egRequire_(session&&!session.revokedAt&&session.expiresAt>Date.now(),'Employee session expired. Scan the QR and sign in again.','UNAUTHORIZED');
  const credential=egPrivateGet_(config,'credential:'+session.employeeId);
  egRequire_(credential&&!credential.revokedAt&&credential.details.generation===session.details.generation,'Employee access was reset or revoked.','UNAUTHORIZED');
  return {session,employee:egEmployee_(config,session.employeeId)};
}
function egCanRead_(e,tab) {
  if(tab==='Settings'||tab==='Employees') return true;
  const mapping={Customers:['Customers','Invoices','Quotations'],Invoices:['Invoices','Balance Sheet','Reports'],Quotations:['Quotations','Reports'],Finance:['Income & Expenses','Balance Sheet','Reports'],Attendance:['Office & Attendance','Employees','Payroll'],Payroll:['Payroll'],Shareholders:['Capital & Equity','Balance Sheet','Reports'],CapitalTransactions:['Capital & Equity','Balance Sheet','Reports'],ShareholderLoans:['Capital & Equity','Balance Sheet','Reports'],Assets:['Fixed Assets','Balance Sheet','Reports'],Journals:['Income & Expenses','Capital & Equity','Fixed Assets','Balance Sheet','Reports']};
  return mapping[tab]&&egHas_(e,mapping[tab]);
}
function egVisibleRows_(e,tab,rows) {
  if(!egCanRead_(e,tab)) return [];
  if(tab==='Settings') return rows.filter(r=>r[0]==='company');
  if(tab==='Employees'&&!egHas_(e,['Employees'])) return rows.filter(r=>r[0]===e.id).map(r=>r.map((v,i)=>[0,1,2,3,4,5,11,14,21,22,23].includes(i)?v:''));
  if(tab==='Attendance'&&!egHas_(e,['Employees','Payroll'])) return rows.filter(r=>r[2]===e.id);
  return rows;
}
function egCanWrite_(e,tab,row) {
  const mapping={Customers:['Customers'],Invoices:['Invoices'],Quotations:['Quotations'],Finance:['Income & Expenses'],Employees:['Employees'],Attendance:['Office & Attendance','Employees'],Payroll:['Payroll'],Shareholders:['Capital & Equity'],CapitalTransactions:['Capital & Equity'],ShareholderLoans:['Capital & Equity'],Assets:['Fixed Assets'],Journals:['Income & Expenses','Capital & Equity','Fixed Assets','Balance Sheet']};
  if(!mapping[tab]||!egHas_(e,mapping[tab])) return false;
  return tab!=='Attendance'||egHas_(e,['Employees'])||row[2]===e.id;
}
function egCheckEmployeeEdit_(oldRow,row) {
  // Salary/HR permission never permits granting accounts access or altering login identity.
  const security=[1,10,11,21,22,23,24];
  if(oldRow) security.forEach(i=>egRequire_(egText_(oldRow[i])===egText_(row[i]),'Only the owner can change employee login, status or permissions.','FORBIDDEN'));
  else egRequire_(!row[23]&&(!row[22]||row[22]==='Staff')&&egText_(row[11]).toLowerCase()==='active','Only the owner can grant employee access.','FORBIDDEN');
}
function egSafeCell_(value) { if(typeof value==='number'||typeof value==='boolean') return value; const s=egText_(value); egRequire_(s.length<48000,'A field exceeds the spreadsheet cell limit.'); return /^[=+@]/.test(s)||(/^\-/.test(s)&&!/^\-\d+(\.\d+)?$/.test(s))?"'"+s:s; }
function egWriteRow_(config,tab,table,index,row,actor,operationId) {
  const book=egBook_(config); let sheet=table.sheet;
  if(!sheet) {sheet=book.insertSheet(tab);sheet.getRange(1,1,1,table.rawHeaders.length).setValues([table.rawHeaders]);sheet.setFrozenRows(1);}
  const headers=table.rawHeaders.slice();
  ['Created By','Updated By','Last Employee Operation'].forEach(h=>{if(!headers.includes(h))headers.push(h);});
  if(headers.length!==table.rawHeaders.length) sheet.getRange(1,1,1,headers.length).setValues([headers]);
  const values=index>=0?table.rawRows[index].slice():[];
  while(values.length<headers.length) values.push('');
  table.headers.forEach((h,i)=>values[headers.indexOf(h)]=egSafeCell_(row[i]));
  if(!values[headers.indexOf('Created By')]) values[headers.indexOf('Created By')]=actor;
  values[headers.indexOf('Updated By')]=actor;
  values[headers.indexOf('Last Employee Operation')]=operationId;
  sheet.getRange(index<0?table.rows.length+2:index+2,1,1,headers.length).setValues([values]);
}
function egOperation_(config,e,op) {
  egRequire_(op&&typeof op==='object','Invalid pending change.');
  const id=egId_(op.id), tab=egText_(op.tabName), recordId=egId_(op.recordId);
  egRequire_(!op.spreadsheetId||op.spreadsheetId===config.spreadsheetId,'This change belongs to another workspace.','FORBIDDEN');
  egRequire_(Object.prototype.hasOwnProperty.call(EG_HEADERS_,tab)&&tab!=='Settings','This data table cannot be changed.','FORBIDDEN');
  egRequire_(op.action==='upsert'||op.action==='delete','Unsupported pending change.');
  const digest=egHash_(JSON.stringify({tab,recordId,action:op.action,row:op.row||null,expectedVersion:op.expectedVersion})), key='operation:'+e.id+':'+id;
  const previous=egPrivateGet_(config,key);
  if(previous) {egRequire_(previous.digest===digest,'Operation identifier was reused for a different change.','CONFLICT');return;}
  const table=egTable_(config,tab), index=table.rows.findIndex(r=>egText_(r[0])===recordId), oldRow=index>=0?table.rows[index]:null;
  let row=op.action==='upsert'?op.row:oldRow;
  egRequire_(row&&Array.isArray(row),'The record no longer exists or has no row data.','CONFLICT');
  egRequire_(row.length===table.headers.length&&egText_(row[0])===recordId,'Pending row does not match the table schema.');
  row.forEach(v=>egRequire_(v===null||['string','number','boolean'].includes(typeof v),'Only scalar spreadsheet cells are supported.'));
  egRequire_(egCanWrite_(e,tab,row)&&(!oldRow||egCanWrite_(e,tab,oldRow)),'Your current role does not allow this change.','FORBIDDEN');
  const lastOperation=table.rawHeaders.indexOf('Last Employee Operation');
  if(oldRow&&lastOperation>=0&&table.rawRows[index][lastOperation]===e.id+':'+id) {
    egPrivatePut_(config,{key,kind:'operation',employeeId:e.id,digest,details:{tab,recordId}});return;
  }
  const vi=table.headers.indexOf('Version'), current=oldRow?Number(oldRow[vi])||0:0;
  const expected=op.expectedVersion===undefined?(op.action==='upsert'?Number(row[vi])-1:NaN):Number(op.expectedVersion);
  egRequire_(Number.isSafeInteger(expected)&&expected>=0&&expected===current,'Record changed on another device. Refresh and resolve this pending change.','CONFLICT');
  if(op.action==='delete') {
    egRequire_(tab!=='Employees','Only the owner can delete an employee.','FORBIDDEN');
    egPrivatePut_(config,{key,kind:'operationIntent',employeeId:e.id,digest,details:{tab,recordId,delete:true}});
    table.sheet.deleteRow(index+2);
  } else {
    egRequire_(Number.isSafeInteger(Number(row[vi]))&&Number(row[vi])>current,'New record version must increase.','CONFLICT');
    if(op.data) egRequire_(egText_(op.data.id)===recordId&&Number(op.data.version)===Number(row[vi]),'Record and row identifiers or versions differ.');
    if(tab==='Employees') egCheckEmployeeEdit_(oldRow,row);
    if(tab==='Attendance') {
      egRequire_(/^\d{4}-\d{2}-\d{2}$/.test(row[1])&&recordId===row[2]+'_'+row[1],'Invalid attendance date or identifier.');
      egRequire_(['PRESENT','ABSENT','HALFDAY','LEAVE','HOLIDAY','WEEKEND','PAIDLEAVE','UNPAIDLEAVE'].includes(egText_(row[4]).toUpperCase()),'Invalid attendance status.');
      egRequire_(Number(row[5])>=0&&Number(row[5])<=24,'Invalid overtime hours.');
      const payroll=egTable_(config,'Payroll').rows;
      egRequire_(!payroll.some(p=>p[2]===row[2]&&p[1]===row[1].slice(0,7)&&egText_(p[11]).toLowerCase()!=='draft'),'Attendance is locked by approved payroll.','CONFLICT');
    }
    egValidateLinks_(config,e,tab,recordId,oldRow,row);
    egWriteRow_(config,tab,table,index,row,'employee:'+e.id,e.id+':'+id);
  }
  egPrivatePut_(config,{key,kind:'operation',employeeId:e.id,digest,details:{tab,recordId,at:new Date().toISOString()}});
}
function egSync_(config,e,data) {
  const operations=data.operations||[]; egRequire_(Array.isArray(operations)&&operations.length<=100,'Sync up to 100 pending changes at a time.');
  const acknowledged=[],rejected=[];
  operations.forEach(op=>{try {egOperation_(config,e,op);acknowledged.push(op.id);}catch(error){rejected.push({id:egText_(op&&op.id),message:error.message,code:error.egCode||'INVALID_REQUEST'});}});
  const tabs={}; Object.keys(EG_HEADERS_).forEach(tab=>{const table=egCanRead_(e,tab)?egTable_(config,tab):{headers:EG_HEADERS_[tab],rows:[]};tabs[tab]=[table.headers].concat(egVisibleRows_(e,tab,table.rows));});
  return {workspace:egWorkspace_(config,e),acknowledged,rejected,tabs};
}
function egFileId_(url) {
  const match=egText_(url).match(/^https:\/\/(?:drive\.google\.com|docs\.google\.com)\/(?:file\/d\/([a-zA-Z0-9_-]+)|(?:open|uc)\?(?:[^#]*&)?id=([a-zA-Z0-9_-]+))/);
  egRequire_(match,'Invalid company Drive file link.'); return match[1]||match[2];
}
function egLinks_(tab,row) { const headers=EG_HEADERS_[tab]; return headers.reduce((a,h,i)=>/Drive.*Link|Drive Payslip Link/.test(h)?a.concat(egText_(row[i]).split(/[\n,]/).filter(Boolean)):a,[]); }
function egInsideRoot_(file,rootId) {
  let parents=file.getParents(), frontier=[]; while(parents.hasNext())frontier.push(parents.next());
  const seen={}; let checked=0;
  while(frontier.length&&checked++<64) {const folder=frontier.shift(),id=folder.getId();if(id===rootId)return true;if(seen[id])continue;seen[id]=true;parents=folder.getParents();while(parents.hasNext())frontier.push(parents.next());}
  return false;
}
function egFilePermission_(config,e,url,write) {
  const id=egFileId_(url), tracked=egPrivateGet_(config,'file:'+id); let permitted=false;
  if(tracked) {
    const d=tracked.details;
    if(d.tab==='Reports') permitted=egHas_(e,['Reports'])&&tracked.employeeId===e.id;
    else {const table=egTable_(config,d.tab),row=table.rows.find(r=>r[0]===d.recordId);permitted=!!row&&(write?egCanWrite_(e,d.tab,row):egVisibleRows_(e,d.tab,[row]).length>0)&&(tracked.employeeId===e.id||egLinks_(d.tab,row).some(link=>egFileId_(link)===id));}
  }
  if(!permitted) Object.keys(EG_HEADERS_).some(tab=>{if(!egCanRead_(e,tab))return false; const rows=egVisibleRows_(e,tab,egTable_(config,tab).rows);permitted=rows.some(row=>(!write||egCanWrite_(e,tab,row))&&egLinks_(tab,row).some(link=>{try{return egFileId_(link)===id;}catch(_){return false;}}));return permitted;});
  egRequire_(permitted,'This file is not attached to a record you can access.','FORBIDDEN');
  const file=DriveApp.getFileById(id); egRequire_(egInsideRoot_(file,config.driveFolderId),'File is outside the company Drive folder.','FORBIDDEN'); return file;
}
function egValidateLinks_(config,e,tab,recordId,oldRow,row) {
  const old=oldRow?egLinks_(tab,oldRow):[];
  egLinks_(tab,row).filter(link=>!old.includes(link)).forEach(link=>{
    const id=egFileId_(link),tracked=egPrivateGet_(config,'file:'+id);
    egRequire_(tracked&&tracked.employeeId===e.id&&tracked.details.tab===tab&&tracked.details.recordId===recordId,'Upload this file to its record before attaching it.','FORBIDDEN');
    egFilePermission_(config,e,link,true);
  });
}
function egUpload_(config,e,data) {
  const tab=egText_(data.tabName),recordId=egId_(data.recordId);
  if(tab==='Reports') egRequire_(egHas_(e,['Reports']),'Reports permission is required.','FORBIDDEN');
  else {const row=egTable_(config,tab).rows.find(r=>r[0]===recordId);egRequire_(row&&egCanWrite_(e,tab,row),'Sync the permitted parent record before uploading its file.','FORBIDDEN');}
  egRequire_(typeof data.base64==='string'&&data.base64.length<=7000000&&/^[A-Za-z0-9+/]*={0,2}$/.test(data.base64),'Invalid file or file exceeds 5 MB.');
  const mime=egText_(data.mimeType),name=egText_(data.name).replace(/[\\/\x00-\x1f]/g,'_').slice(0,180);
  egRequire_(name&&['application/pdf','image/png','image/jpeg','image/webp','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/csv'].includes(mime),'Unsupported file type.');
  const digest=egHash_(e.id+':'+tab+':'+recordId+':'+name+':'+mime+':'+data.base64),existing=egPrivateGet_(config,'upload:'+digest);
  if(existing) {const file=egFilePermission_(config,e,existing.details.url,true);if(!file.isTrashed())return {url:file.getUrl()};}
  const bytes=Utilities.base64Decode(data.base64);egRequire_(bytes.length>0&&bytes.length<=5*1024*1024,'File exceeds 5 MB.');
  const root=DriveApp.getFolderById(config.driveFolderId),folderName={Invoices:'Invoices',Quotations:'Quotations',Payroll:'Payroll',Employees:'Employees',Reports:'Reports'}[tab]||'Attachments';
  const folders=root.getFoldersByName(folderName),folder=folders.hasNext()?folders.next():root.createFolder(folderName);
  const file=folder.createFile(Utilities.newBlob(bytes,mime,name)),url=file.getUrl();
  // Never change sharing: files inherit only the configured private company folder.
  egPrivatePut_(config,{key:'file:'+file.getId(),kind:'file',employeeId:e.id,details:{tab,recordId,url}});
  egPrivatePut_(config,{key:'upload:'+digest,kind:'upload',employeeId:e.id,details:{url}});
  return {url};
}
function egHandle_(request) {
  egRequire_(request&&typeof request==='object','Invalid request.'); const config=egConfig_(),data=request.data||{};
  if(request.action==='provisionEmployee') return egProvision_(config,data,request.ownerAccessToken);
  if(request.action==='revokeEmployee') {egOwner_(config,request.ownerAccessToken);const access=egPrivateGet_(config,'credential:'+egId_(data.employeeId));if(access){access.revokedAt=new Date().toISOString();egPrivatePut_(config,access);}return {revoked:true};}
  if(request.action==='login') return egLogin_(config,data);
  const auth=egAuthenticate_(config,request.sessionToken),e=auth.employee;
  if(request.action==='logout'){auth.session.revokedAt=new Date().toISOString();egPrivatePut_(config,auth.session);return {};}
  if(request.action==='sync')return egSync_(config,e,data);
  if(request.action==='upload')return egUpload_(config,e,data);
  if(request.action==='download'){const file=egFilePermission_(config,e,data.url,false);egRequire_(file.getSize()<=5*1024*1024,'File exceeds 5 MB.');const blob=file.getBlob();return {base64:Utilities.base64Encode(blob.getBytes()),mimeType:blob.getContentType(),name:file.getName()};}
  if(request.action==='deleteFile'){egFilePermission_(config,e,data.url,true).setTrashed(true);return {deleted:true};}
  egFail_('Unknown employee gateway action.');
}
function doPost(event) {
  let lock; let response;
  try {
    const body=event&&event.postData&&event.postData.contents;
    egRequire_(typeof body==='string'&&body.length<=8000000,'Invalid request size.');
    const request=JSON.parse(body);
    lock=LockService.getScriptLock();lock.waitLock(25000);
    response={ok:true,result:egHandle_(request)};
  } catch(error) {response={ok:false,error:error.egCode?error.message:'Employee service could not complete this request.',code:error.egCode||'SERVER_ERROR'};}
  finally {if(lock&&lock.hasLock())lock.releaseLock();}
  return ContentService.createTextOutput(JSON.stringify(response)).setMimeType(ContentService.MimeType.JSON);
}
