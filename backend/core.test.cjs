const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');
function backend(){
 const ctx=vm.createContext({console,Date,Math,JSON,Number,String,Array,RegExp,Error,Utilities:{formatDate:()=> '2026'}});
 vm.runInContext(fs.readFileSync(__dirname+'/apps-script/Core.gs','utf8')+'\n'+fs.readFileSync(__dirname+'/apps-script/Code.gs','utf8')+'\n'+fs.readFileSync(__dirname+'/apps-script/Office.gs','utf8'),ctx);
 const tables={Customers:[],Invoices:[],Settings:[],Employees:[],Attendance:[],Payroll:[],Finance:[]};
 ctx.all_=name=>structuredClone(tables[name]);ctx.get_=(name,id)=>structuredClone(tables[name].find(x=>x.id===id)||null);
 ctx.put_=(name,id,value)=>{const a=tables[name],idx=a.findIndex(x=>x.id===id);const v=structuredClone(value);if(idx<0)a.push(v);else a[idx]=v;return structuredClone(v);};
 ctx.updateRegisters_=()=>{};
 return ctx;
}
function customer(){return {id:'c',name:'Well-Tech',email:'',phone:'',address:'',trn:'',version:0};}
function draft(id='i'){return {id,version:0,date:'2026-09-05',customer:{id:'c'},items:[{description:'E-Commerce Management',quantity:'1',rate:'2500.00'},{description:'Amazon Ads',quantity:'1',rate:'227.00'},{description:'Review Products',quantity:'1',rate:'1413.75'},{description:'Server Cost',quantity:'1',rate:'62.76'}],discount:'500.00',taxRate:'0',dueDate:'',notes:'Thanks for your business.',terms:'Due on receipt'};}
function seeded(){const b=backend();b.dispatch_('saveCustomer',customer(),'uid');return b;}
test('sample PDF arithmetic matches AED 3703.51',()=>{const b=backend(),t=b.totals_(draft());assert.equal(t.subtotal,420351);assert.equal(t.balance,370351);});
test('integer line and tax rounding',()=>{const b=backend();assert.equal(b.totals_({...draft(),taxRate:'5'}).tax,18518);assert.equal(b.totals_({...draft(),discount:'0',items:[{description:'fraction',quantity:'0.125',rate:'0.04'}]}).total,1);});
test('reject negative, nonfinite, excess precision and exponential values',()=>{const b=backend();for(const x of ['-1','NaN','Infinity','1.001','1e2'])assert.throws(()=>b.scaled_(x,2));});
test('reject zero quantity, excessive discount and excessive tax',()=>{const b=backend();assert.throws(()=>b.totals_({...draft(),discount:'99999'}));assert.throws(()=>b.totals_({...draft(),taxRate:'101'}));assert.throws(()=>b.totals_({...draft(),items:[{description:'x',quantity:'0',rate:'1'}]}));});
test('reject invalid dates',()=>{const b=backend();for(const d of ['2026-02-30','2026-13-01','invalid'])assert.throws(()=>b.dateField_(d));});
test('draft receives no number; issue uses unique sequence',()=>{const b=seeded();let i=b.dispatch_('saveDraft',draft(),'uid');assert.equal(i.number,'');i=b.dispatch_('issue',i,'uid');assert.equal(i.number,'TPC-2026-000001');const j=b.dispatch_('saveDraft',draft('j'),'uid');assert.equal(b.dispatch_('issue',j,'uid').number,'TPC-2026-000002');});
test('issue retry after lost response reuses persisted number',()=>{const b=seeded();const d=b.dispatch_('saveDraft',draft(),'uid');assert.equal(b.dispatch_('issue',d,'uid').number,b.dispatch_('issue',d,'uid').number);assert.equal(b.all_('Invoices').length,1);});
test('issued invoice is immutable and retains customer/company snapshots',()=>{const b=seeded();let i=b.dispatch_('saveDraft',draft(),'uid');i=b.dispatch_('issue',i,'uid');assert.throws(()=>b.dispatch_('saveDraft',{...i,discount:'0'},'uid'));b.dispatch_('saveCustomer',{...customer(),name:'Changed',version:1},'uid');b.dispatch_('saveCompany',{...b.company_(),name:'Changed'},'uid');assert.equal(b.get_('Invoices','i').customer.name,'Well-Tech');assert.equal(b.get_('Invoices','i').company.name,'The Percentage FZ LLC');});
test('optimistic versions reject stale editing',()=>{const b=seeded();b.dispatch_('saveDraft',draft(),'uid');assert.throws(()=>b.dispatch_('saveDraft',draft(),'uid'),/another device/);});
test('payment retry is idempotent, overpayment blocked, paid invoice cannot be voided',()=>{const b=seeded();const i=b.dispatch_('issue',b.dispatch_('saveDraft',draft(),'uid'),'uid');const p={id:'p',cents:10000,date:'2026-09-09',reference:'cash'};const req={id:i.id,version:i.version,payment:p};const paid=b.dispatch_('pay',req,'uid');assert.equal(b.dispatch_('pay',req,'uid').payments.length,1);assert.equal(b.totals_(paid).balance,360351);assert.throws(()=>b.dispatch_('pay',{id:i.id,version:paid.version,payment:{...p,id:'q',cents:999999}},'uid'));assert.throws(()=>b.dispatch_('void',paid,'uid'));});
test('void numbers are not reused',()=>{const b=seeded();const i=b.dispatch_('issue',b.dispatch_('saveDraft',draft(),'uid'),'uid');b.dispatch_('void',i,'uid');assert.equal(b.dispatch_('issue',b.dispatch_('saveDraft',draft('j'),'uid'),'uid').number,'TPC-2026-000002');});
test('customer required; input cannot inject issued number or payments',()=>{const b=backend();assert.throws(()=>b.dispatch_('saveDraft',draft(),'uid'));b.dispatch_('saveCustomer',customer(),'uid');const i=b.dispatch_('saveDraft',{...draft(),number:'TPC-HACK',status:'issued',payments:[{id:'p',cents:1}]},'uid');assert.equal(i.number,'');assert.equal(i.status,'draft');assert.equal(i.payments.length,0);});
test('formula-like text is escaped in readable registers',()=>{const b=backend();assert.equal(b.safeCell_('=IMPORTXML(x)'),"'=IMPORTXML(x)");assert.equal(b.safeCell_('Well-Tech'),'Well-Tech');});
test('invoice arithmetic remains within safe integer range',()=>{const b=backend();assert.throws(()=>b.scaled_('1000.001',3));assert.throws(()=>b.totals_({...draft(),items:[{description:'x',quantity:'1000',rate:'1000000'}]}));});
test('unknown operation cannot alter an invoice',()=>{const b=seeded();const i=b.dispatch_('saveDraft',draft(),'uid');assert.throws(()=>b.dispatch_('delete',i,'uid'),/Unknown/);assert.equal(b.get_('Invoices','i').version,1);});
test('Drive invoice and receipt archive retries create one file per version',()=>{
 const b=seeded(),files=new Map();
 b.PropertiesService={getScriptProperties:()=>({getProperty:()=> 'folder'})};
 b.Utilities.base64Decode=s=>[...Buffer.from(s,'base64')];b.Utilities.newBlob=(bytes,mime,name)=>({bytes,mime,name});
 b.DriveApp={getFolderById:()=>({getFilesByName:name=>({hasNext:()=>files.has(name),next:()=>files.get(name)}),createFile:blob=>{const f={getUrl:()=> 'https://drive.google.com/file/d/'+blob.name};files.set(blob.name,f);return f;}})};
 let i=b.dispatch_('issue',b.dispatch_('saveDraft',draft(),'uid'),'uid');
 const pdf=Buffer.from('%PDF-test').toString('base64');
 b.dispatch_('archive',{id:i.id,version:i.version,pdf},'uid');b.dispatch_('archive',{id:i.id,version:i.version,pdf},'uid');assert.equal(files.size,1);
 i=b.dispatch_('pay',{id:i.id,version:i.version,payment:{id:'p',cents:100,date:'2026-09-09',reference:''}},'uid');
 b.dispatch_('archive',{id:i.id,version:i.version,pdf,paymentId:'p'},'uid');b.dispatch_('archive',{id:i.id,version:i.version,pdf,paymentId:'p'},'uid');assert.equal(files.size,2);
 assert.throws(()=>b.dispatch_('archive',{id:i.id,version:i.version,pdf,paymentId:'missing'},'uid'));
});
test('Google-only API rejects non-allowlisted accounts',()=>{
 const b=backend();b.PropertiesService={getScriptProperties:()=>({getProperty:()=> 'admin@example.com'})};b.Session={getActiveUser:()=>({getEmail:()=> 'intruder@example.com'})};
 const result=b.execute({action:'load'});assert.equal(result.ok,false);assert.match(result.error,/not authorised/);
});
function emp(){return {id:'e',code:'TPC001',name:'Employee',joinDate:'2026-09-01',endDate:'',basic:'3000',allowances:'600',version:0};}
function officeSeed(){const b=backend();b.officeDispatch_('employeeSave',emp(),'admin');return b;}
function mark(b,date,status='present',version=0){return b.officeDispatch_('attendanceSave',{employeeId:'e',date,status,overtimeHours:'2',version},'admin');}
function generation(){return {employeeId:'e',month:'2026-09',divisor:30,baseDays:30,scheduledDays:2,overtimeRate:'10',bonus:'100',deductions:'50',version:0};}
test('employee salary validation and unique codes',()=>{const b=officeSeed();assert.throws(()=>b.officeDispatch_('employeeSave',{...emp(),id:'other'},'admin'),/already exists/);assert.throws(()=>b.officeDispatch_('employeeSave',{...emp(),basic:'-2'},'admin'));});
test('one attendance record per employee/day and stale versions rejected',()=>{const b=officeSeed();mark(b,'2026-09-01');assert.throws(()=>mark(b,'2026-09-01'));mark(b,'2026-09-01','halfDay',1);assert.equal(b.all_('Attendance').length,1);assert.equal(b.get_('Attendance','e_2026-09-01').status,'halfDay');});
test('payroll includes absence, overtime, bonus and deductions',()=>{const b=officeSeed();mark(b,'2026-09-01');mark(b,'2026-09-02','absent');const p=b.officeDispatch_('payrollGenerate',generation(),'admin');assert.equal(p.baseCents,360000);assert.equal(p.absenceCents,12000);assert.equal(p.overtimeCents,4000);assert.equal(p.netCents,357000);});
test('missing attendance blocks approval',()=>{const b=officeSeed();mark(b,'2026-09-01');const p=b.officeDispatch_('payrollGenerate',generation(),'admin');assert.throws(()=>b.officeDispatch_('payrollApprove',p,'admin'),/scheduled days/);});
test('attendance changed after draft requires regeneration',()=>{const b=officeSeed();mark(b,'2026-09-01');mark(b,'2026-09-02');const p=b.officeDispatch_('payrollGenerate',generation(),'admin');mark(b,'2026-09-02','halfDay',1);assert.throws(()=>b.officeDispatch_('payrollApprove',p,'admin'),/Attendance changed/);});
test('approved payroll locks attendance and is unique per month',()=>{const b=officeSeed();mark(b,'2026-09-01');mark(b,'2026-09-02');const p=b.officeDispatch_('payrollGenerate',generation(),'admin');b.officeDispatch_('payrollApprove',p,'admin');assert.throws(()=>mark(b,'2026-09-01','absent',1),/locked/);assert.throws(()=>b.officeDispatch_('payrollGenerate',{...generation(),version:1},'admin'),/already approved/);});
test('salary payment retries do not create duplicate payroll',()=>{const b=officeSeed();mark(b,'2026-09-01');mark(b,'2026-09-02');let p=b.officeDispatch_('payrollGenerate',generation(),'admin');p=b.officeDispatch_('payrollApprove',p,'admin');const req={id:p.id,version:p.version,paidDate:'2026-09-30',account:'Bank',reference:'test'};b.officeDispatch_('payrollPay',req,'admin');b.officeDispatch_('payrollPay',req,'admin');assert.equal(b.all_('Payroll').length,1);assert.equal(b.get_('Payroll',p.id).status,'paid');});
test('unpaid supplier bills settle once and cannot be edited after posting',()=>{const b=backend();let e=b.officeDispatch_('financeSave',{id:'bill',version:0,kind:'expense',date:'2026-09-01',status:'unpaid',amount:'100',category:'Rent',account:'Bank'},'admin');const req={id:e.id,version:e.version,paidDate:'2026-09-09',account:'Bank'};e=b.officeDispatch_('financePay',req,'admin');assert.equal(b.officeDispatch_('financePay',req,'admin').version,e.version);assert.throws(()=>b.officeDispatch_('financeSave',e,'admin'),/unpaid/);assert.equal(b.all_('Finance').length,1);});
test('invalid payroll divisor and negative net are rejected',()=>{const b=officeSeed();mark(b,'2026-09-01');assert.throws(()=>b.officeDispatch_('payrollGenerate',{...generation(),divisor:0},'admin'));assert.throws(()=>b.officeDispatch_('payrollGenerate',{...generation(),deductions:'99999'},'admin'));});
