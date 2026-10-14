// Disposable live integration check. Never print or persist private credentials.
import {createClient} from 'npm:@supabase/supabase-js@2.117.3';
const config=JSON.parse(await Deno.readTextFile('config/saas.production.json'));
const secret=Deno.env.get('TPC_VERIFY_SERVICE_KEY');
if(!secret)throw new Error('Set TPC_VERIFY_SERVICE_KEY locally for this operator check.');
const admin=createClient(config.SUPABASE_URL,secret,{auth:{persistSession:false,autoRefreshToken:false}});
const email=`tpc-realtime-check-${Date.now()}@example.com`,password=crypto.randomUUID()+crypto.randomUUID();
const {data:created,error:ce}=await admin.auth.admin.createUser({email,password,email_confirm:true});if(ce)throw ce;
const reader=createClient(config.SUPABASE_URL,config.SUPABASE_PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const writer=createClient(config.SUPABASE_URL,config.SUPABASE_PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const entities:string[]=[];let group:string|undefined;let channel:ReturnType<typeof reader.channel>|undefined;
const api=async(path:string,method='GET',body?:unknown)=>{
  const token=writer.auth.getSession().then(r=>r.data.session!.access_token);
  const response=await fetch(`${config.SUPABASE_URL}/functions/v1/api${path}`,{method,headers:{apikey:config.SUPABASE_PUBLISHABLE_KEY,
    Authorization:`Bearer ${await token}`,'Content-Type':'application/json','Idempotency-Key':crypto.randomUUID()},body:body?JSON.stringify(body):undefined});
  const text=await response.text();let value;try{value=JSON.parse(text);}catch{throw new Error(`Integration request failed at ${path}: HTTP ${response.status}, non-JSON response`);}
  if(!response.ok)throw new Error(`Integration request failed at ${path}: ${response.status} ${value.error?.code}`);return value;
};
try{
  for(const client of [reader,writer]){const {error}=await client.auth.signInWithPassword({email,password});if(error)throw error;}
  group=(await api('/v1/groups','POST',{name:'Temporary integration check'})).group.id;
  for(const [name,countryCode,currency,timeZone] of [['UAE check','AE','AED','Asia/Dubai'],['India check','IN','INR','Asia/Kolkata']]){
    entities.push((await api(`/v1/groups/${group}/entities`,'POST',{name,countryCode,currency,timeZone})).company.companyId);
  }
  const overview=await api('/v1/groups');
  if(overview.entities.length!==2||overview.entities.find((e:any)=>e.companyId===entities[1]).currency!=='INR')throw new Error('Country entity isolation failed');
  const employee=(await api(`/v1/companies/${entities[0]}/employees`,'POST',{fullName:'Temporary employee',role:'Staff',employmentStatus:'ACTIVE',expectedVersion:0,allowedSections:['Tasks'],writableSections:[]})).employeeId;
  let received:(value:unknown)=>void=()=>{};
  const event=new Promise(resolve=>{received=resolve;});
  channel=reader.channel('integration-'+crypto.randomUUID()).on('postgres_changes',{event:'INSERT',schema:'public',table:'company_changes',filter:`company_id=eq.${entities[0]}`},payload=>{
    if((payload.new.sections as string[]).includes('Tasks'))received(payload.new);
  });
  await new Promise<void>((resolve,reject)=>{
    const timer=setTimeout(()=>reject(new Error('Realtime subscribe timed out')),30000);
    channel!.subscribe(status=>{if(status==='SUBSCRIBED'){clearTimeout(timer);resolve();}else if(status==='CHANNEL_ERROR'||status==='TIMED_OUT'){clearTimeout(timer);reject(new Error('Realtime subscription failed'));}});
  });
  await api(`/v1/companies/${entities[0]}/records/Tasks`,'POST',{expectedVersion:0,values:{title:'Live task',employeeId:employee,
    status:'TODO',priority:'MEDIUM',dueDate:new Date().toISOString().slice(0,10),startDate:'',startTime:'',endTime:'',project:'',tags:'',reminder:'NONE',description:''}});
  await Promise.race([event,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Realtime task event timed out')),15000))]);
  console.log('PASS live country-entity creation and cross-session task Realtime delivery');
}finally{
  if(channel)await reader.removeChannel(channel);
  for(const id of entities)await api(`/v1/companies/${id}`,'DELETE');
  if(group){for(const table of ['group_memberships','business_groups']){
    const {error}=await admin.from(table).delete().eq(table==='business_groups'?'id':'group_id',group);if(error)throw error;
  }}
  await reader.auth.signOut();await writer.auth.signOut();
  const {error}=await admin.auth.admin.deleteUser(created.user!.id);if(error)throw error;
  console.log('Temporary integration accounts and entities removed');
}
Deno.exit(0);
