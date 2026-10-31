import { recordSyncScope,recordDelta } from '../_shared/record-sync.ts';
const assert=(value:unknown)=>{if(!value)throw new Error('Assertion failed');};
function fixture(){return {
 company:{id:'company'},user:{id:'actor'},member:{employee_id:'employee',role:'Staff',access_valid_after:'-infinity'},
 principal:{permissions:{Payroll:'SELF'},writableSections:[]},
 records:{table:()=>({})},canRead:()=>{},
 db:{rpc:async()=>({data:{changes:[{section:'Employees'}]},error:null})},
};}
Deno.test('existing payroll snapshots refresh once to include employee identity',async()=>{
 const ctx=fixture();
 assert(recordSyncScope(ctx,'Customers')===recordSyncScope(ctx));
 assert(recordSyncScope(ctx,'Payroll')!==recordSyncScope(ctx));
 const result=await recordDelta(ctx,'Payroll',new URLSearchParams({after:'1',scope:recordSyncScope(ctx)}));
 assert(result.reset===true);
});
Deno.test('an employee rename refreshes payroll display without changing payroll',async()=>{
 const ctx=fixture();
 const result=await recordDelta(ctx,'Payroll',new URLSearchParams({after:'1',scope:recordSyncScope(ctx,'Payroll')}));
 assert(result.reset===true);
});
