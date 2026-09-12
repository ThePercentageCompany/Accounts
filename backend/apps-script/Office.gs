function employeeValue_(d) {
  const e={id:validId_(d.id),version:d.version||0,documents:[]};
  for(const k of ['code','name','department','title','email','phone','address','bank','iban','emiratesId','passport','visaExpiry','notes']) e[k]=textField_(d[k]||'',k==='notes'?1000:600,k==='name'||k==='code');
  e.joinDate=dateField_(d.joinDate); e.endDate=d.endDate?dateField_(d.endDate):'';
  requireValue_(!e.endDate||e.endDate>=e.joinDate,'End date precedes joining date');
  e.active=d.active!==false;
  e.basic=String(d.basic);e.allowances=String(d.allowances);scaled_(e.basic,2);scaled_(e.allowances,2);
  if(e.visaExpiry) dateField_(e.visaExpiry);
  return e;
}
function monthField_(v) {requireValue_(/^\d{4}-\d{2}$/.test(v),'Use YYYY-MM');dateField_(v+'-01');return v;}
function attendanceRows_(employeeId,month) {return all_('Attendance').filter(a=>a.employeeId===employeeId&&a.date.slice(0,7)===month).sort((a,b)=>a.date.localeCompare(b.date));}
function payrollCalc_(employee,rows,d) {
  const salary=scaled_(employee.basic,2)+scaled_(employee.allowances,2);
  const divisor=Number(d.divisor),baseDays=Number(d.baseDays),scheduled=Number(d.scheduledDays);
  requireValue_(Number.isInteger(divisor)&&divisor>=1&&divisor<=31,'Salary divisor must be 1-31');
  requireValue_(Number.isFinite(baseDays)&&baseDays>0&&baseDays<=divisor&&Number.isInteger(baseDays*2),'Base days must be positive half-days within the divisor');
  requireValue_(Number.isInteger(scheduled)&&scheduled>=1&&scheduled<=31,'Scheduled days must be 1-31');
  const counted=rows.filter(r=>!['off','holiday'].includes(r.status));
  const missing=scheduled-counted.length;
  const absent=rows.reduce((n,r)=>n+(['absent','unpaidLeave'].includes(r.status)?1:r.status==='halfDay'?.5:0),0);
  const baseCents=Math.round(salary*baseDays/divisor);
  const absenceCents=Math.round(salary*absent/divisor);
  const overtimeUnits=rows.reduce((n,r)=>n+scaled_(r.overtimeHours,2),0);
  const overtimeCents=Math.round(overtimeUnits*scaled_(String(d.overtimeRate),2)/100);
  const bonusCents=scaled_(String(d.bonus),2),deductionCents=scaled_(String(d.deductions),2);
  requireValue_(absent<=baseDays,'Unpaid days exceed salary base days');
  const netCents=baseCents+overtimeCents+bonusCents-absenceCents-deductionCents;
  requireValue_(Number.isSafeInteger(netCents)&&netCents>=0&&netCents<=1000000000,'Invalid net salary');
  return {baseCents,absenceCents,overtimeCents,bonusCents,deductionCents,netCents,absentDays:absent,markedDays:counted.length,missingDays:missing};
}
function officeDispatch_(action,d,actor) {
  if(action==='officeLoad')return {employees:all_('Employees'),attendance:all_('Attendance'),payroll:all_('Payroll'),entries:all_('Finance')};
  if(action==='employeeSave'){
    const e=employeeValue_(d),old=get_('Employees',e.id);checkVersion_(old,d.version);
    requireValue_(!all_('Employees').some(x=>x.id!==e.id&&x.code.toLowerCase()===e.code.toLowerCase()),'Employee code already exists');
    e.documents=old?old.documents:[];e.version++;return put_('Employees',e.id,e);
  }
  if(action==='attendanceSave'){
    const employee=get_('Employees',validId_(d.employeeId));requireValue_(!!employee,'Employee missing');
    const date=dateField_(d.date),id=employee.id+'_'+date;
    requireValue_(date>=employee.joinDate&&(!employee.endDate||date<=employee.endDate),'Attendance outside employment dates');
    requireValue_(!all_('Payroll').some(p=>p.employee.id===employee.id&&p.month===date.slice(0,7)&&p.status!=='draft'),'Attendance is locked by approved payroll');
    checkVersion_(get_('Attendance',id),d.version);
    requireValue_(['present','absent','halfDay','paidLeave','unpaidLeave','sickLeave','off','holiday'].includes(d.status),'Invalid attendance status');
    const overtimeHours=String(d.overtimeHours);requireValue_(scaled_(overtimeHours,2)<=2400,'Overtime must be 0-24 hours');
    const a={id,employeeId:employee.id,date,status:d.status,checkIn:textField_(d.checkIn||'',5),checkOut:textField_(d.checkOut||'',5),overtimeHours,notes:textField_(d.notes||'',500),version:d.version+1};
    for(const t of [a.checkIn,a.checkOut])if(t)requireValue_(/^([01]\d|2[0-3]):[0-5]\d$/.test(t),'Use HH:MM for clock times');
    return put_('Attendance',id,a);
  }
  if(action==='payrollGenerate'){
    const employee=get_('Employees',validId_(d.employeeId));requireValue_(!!employee,'Employee missing');
    const month=monthField_(d.month),id=employee.id+'_'+month;
    requireValue_(employee.joinDate.slice(0,7)<=month&&(!employee.endDate||employee.endDate.slice(0,7)>=month),'Month outside employment');
    const old=get_('Payroll',id);requireValue_(!old||old.status==='draft','Payroll already approved for this employee/month');checkVersion_(old,d.version);
    const rows=attendanceRows_(employee.id,month),calc=payrollCalc_(employee,rows,d);
    const p={id,month,employee,attendanceSnapshot:rows,company:company_(),divisor:Number(d.divisor),baseDays:Number(d.baseDays),scheduledDays:Number(d.scheduledDays),overtimeRate:String(d.overtimeRate),bonus:String(d.bonus),deductions:String(d.deductions),adjustmentNote:textField_(d.adjustmentNote||'',600),...calc,status:'draft',version:d.version+1,paidDate:'',account:'Bank',reference:'',driveUrl:'',archivedVersion:0};
    return put_('Payroll',id,p);
  }
  if(['payrollApprove','payrollPay','payrollArchive'].includes(action)){
    const p=get_('Payroll',validId_(d.id));requireValue_(!!p,'Payroll missing');
    if(action==='payrollApprove'&&p.status!=='draft')return p;
    if(action==='payrollPay'&&p.status==='paid')return p;
    checkVersion_(p,d.version);
    if(action==='payrollApprove'){
      requireValue_(p.missingDays===0,'Marked scheduled days must match expected scheduled days');
      requireValue_(get_('Employees',p.employee.id).version===p.employee.version,'Employee details changed. Regenerate draft.');
      requireValue_(JSON.stringify(attendanceRows_(p.employee.id,p.month))===JSON.stringify(p.attendanceSnapshot),'Attendance changed. Regenerate draft.');
      p.status='approved';p.version++;p.approvedBy=actor;p.approvedAt=new Date().toISOString();return put_('Payroll',p.id,p);
    }
    if(action==='payrollPay'){
      requireValue_(p.status==='approved','Approve payroll first');p.paidDate=dateField_(d.paidDate);p.account=accountField_(d.account);p.reference=textField_(d.reference||'',200);p.status='paid';p.version++;return put_('Payroll',p.id,p);
    }
    requireValue_(p.status!=='draft','Approve payroll before archive');
    const file=archiveBlob_(d.pdf,'Payslip-'+p.employee.code+'-'+p.month+'-v'+p.version+'.pdf','application/pdf','Payroll');
    p.driveUrl=file.getUrl();p.archivedVersion=p.version;put_('Payroll',p.id,p);return {url:p.driveUrl};
  }
  if(action==='financeSave'){
    const id=validId_(d.id),old=get_('Finance',id);checkVersion_(old,d.version);
    requireValue_(!old||old.status==='unpaid','Only unpaid bills may be edited');
    requireValue_(['income','expense'].includes(d.kind),'Invalid entry type');
    const amountCents=scaled_(String(d.amount),2);requireValue_(amountCents>0,'Amount must exceed zero');
    const status=d.kind==='income'?'paid':d.status;
    requireValue_(['paid','unpaid'].includes(status),'Invalid bill status');
    const entry={id,kind:d.kind,date:dateField_(d.date),dueDate:d.dueDate?dateField_(d.dueDate):'',paidDate:status==='paid'?dateField_(d.paidDate):'',status,amount:String(d.amount),amountCents,category:textField_(d.category,100,true),party:textField_(d.party||'',200),reference:textField_(d.reference||'',200),notes:textField_(d.notes||'',600),account:accountField_(d.account),version:d.version+1,documents:old?old.documents:[]};
    return put_('Finance',id,entry);
  }
  if(action==='financePay'||action==='financeVoid'){
    const e=get_('Finance',validId_(d.id));requireValue_(!!e,'Bill missing');
    if(action==='financePay'&&e.status==='paid')return e;
    if(action==='financeVoid'&&e.status==='void')return e;
    checkVersion_(e,d.version);requireValue_(e.kind==='expense'&&e.status==='unpaid','Only unpaid bills can change');
    if(action==='financePay'){e.paidDate=dateField_(d.paidDate);e.account=accountField_(d.account);e.status='paid';}else e.status='void';
    e.version++;return put_('Finance',e.id,e);
  }
  if(action==='documentUpload'){
    requireValue_(['Employees','Finance'].includes(d.table),'Invalid document parent');
    const parent=get_(d.table,validId_(d.id));requireValue_(!!parent,'Record missing');
    const documentId=validId_(d.documentId),previous=parent.documents.find(x=>x.id===documentId);if(previous)return previous;
    checkVersion_(parent,d.version);requireValue_(parent.documents.length<20,'Maximum 20 documents per record');
    const ext=String(d.extension).toLowerCase();requireValue_(['pdf','png','jpg','jpeg'].includes(ext),'Use PDF, PNG or JPEG');
    const name=textField_(d.name,150,true);
    const subfolder=d.table==='Employees'?'Payroll':'Assets';
    const file=archiveBlob_(d.bytes,d.table+'-'+parent.id+'-'+documentId+'.'+ext,ext==='pdf'?'application/pdf':ext==='png'?'image/png':'image/jpeg',subfolder);
    const doc={id:documentId,name,url:file.getUrl()};parent.documents.push(doc);parent.version++;put_(d.table,parent.id,parent);return doc;
  }
  if(action==='reportArchive'){
    monthField_(d.month);validId_(d.requestId);
    return {url:archiveBlob_(d.pdf,'Finance-'+d.month+'-'+d.requestId+'.pdf','application/pdf','Reports').getUrl()};
  }
  throw new Error('Unknown office action');
}
function accountField_(value){requireValue_(['Bank','Cash'].includes(value),'Select Bank or Cash');return value;}
function archiveBlob_(encoded,name,mime,subfolderName){
  authorize_();
  requireValue_(typeof encoded==='string'&&encoded.length<7000000,'File exceeds 5 MB');
  const bytes=Utilities.base64Decode(encoded);
  const u=n=>(bytes[n]+256)%256;
  requireValue_(bytes.length>8,'Empty or invalid file');
  if(mime==='application/pdf')requireValue_(u(0)===37&&u(1)===80&&u(2)===68&&u(3)===70&&u(4)===45,'Invalid PDF');
  if(mime==='image/png')requireValue_(u(0)===137&&u(1)===80&&u(2)===78&&u(3)===71,'Invalid PNG');
  if(mime==='image/jpeg')requireValue_(u(0)===255&&u(1)===216,'Invalid JPEG');
  const rootFolder=DriveApp.getFolderById(PropertiesService.getScriptProperties().getProperty('DRIVE_FOLDER_ID'));
  const folder=(subfolderName && rootFolder.getFoldersByName) ? (rootFolder.getFoldersByName(subfolderName).hasNext() ? rootFolder.getFoldersByName(subfolderName).next() : (rootFolder.createFolder ? rootFolder.createFolder(subfolderName) : rootFolder)) : rootFolder;
  const matches=folder.getFilesByName(name);return matches.hasNext()?matches.next():folder.createFile(Utilities.newBlob(bytes,mime,name));
}
