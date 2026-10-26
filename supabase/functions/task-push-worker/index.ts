// deno-lint-ignore-file no-explicit-any
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { pushOutcome } from '../_shared/domain/notification-policy.js';

let cached:{token:string,expires:number}|null=null;
const bytes=(value:string)=>new TextEncoder().encode(value);
const b64=(value:Uint8Array)=>btoa(String.fromCharCode(...value)).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'');
async function accessToken(account:any) {
  if(cached&&cached.expires>Date.now()+60000)return cached.token;
  const now=Math.floor(Date.now()/1000);
  const unsigned=b64(bytes(JSON.stringify({alg:'RS256',typ:'JWT'})))+'.'+b64(bytes(JSON.stringify({iss:account.client_email,
    scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})));
  const pem=account.private_key.replace(/-----[^-]+-----|\s/g,'');
  const key=await crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(pem),(c:string)=>c.charCodeAt(0)),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
  const assertion=unsigned+'.'+b64(new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,bytes(unsigned))));
  const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),signal:AbortSignal.timeout(10000)});
  if(!response.ok)throw Error('FCM_AUTH_FAILED');
  const result=await response.json();cached={token:result.access_token,expires:Date.now()+result.expires_in*1000};return cached.token;
}
Deno.serve(async request=>{
  const secret=Deno.env.get('TASK_PUSH_WORKER_SECRET');
  const supplied=request.headers.get('X-Task-Worker-Secret')??'';
  const digest=async(s:string)=>new Uint8Array(await crypto.subtle.digest('SHA-256',bytes(s)));
  const expected=await digest(secret??''),actual=await digest(supplied);
  let difference=0;for(let i=0;i<expected.length;i++)difference|=expected[i]^actual[i];
  if(request.method!=='POST'||!secret||difference)return new Response('Unauthorized',{status:401});
  const raw=Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  if(!raw)return Response.json({configured:false},{status:503});
  try {
    const account=JSON.parse(raw),token=await accessToken(account);
    const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
    const {data:jobs,error}=await db.rpc('claim_notification_push',{p_limit:50});if(error)throw Error('PUSH_QUEUE_UNAVAILABLE');
    let delivered=0;
    // Bounded batches avoid task-write latency and provider request bursts.
    for(let start=0;start<jobs.length;start+=5)await Promise.all(jobs.slice(start,start+5).map(async(j:any)=>{
      let status='RETRY',errorCode:string|null=null;
      try {
        const response=await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,{
          method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(10000),
          body:JSON.stringify({message:{token:j.token,data:{id:j.notificationId,notificationId:j.notificationId,companyId:j.companyId,
            taskId:j.taskId,eventId:j.eventId,type:j.type,sound:j.sound,volume:String(j.volume),title:'TPC task notification',
            body:'Open your workspace to view this task update.'},webpush:{headers:{TTL:'300',Urgency:j.type==='task-overdue'?'high':'normal'}}}})});
        const result=await response.json();status=pushOutcome(response.status,result);errorCode=status==='DELIVERED'?null:`FCM_HTTP_${response.status}`;
      }catch{errorCode='FCM_TEMPORARILY_UNAVAILABLE';}
      const finished=await db.rpc('finish_notification_push',{p_id:j.id,p_lease:j.lease,p_status:status,p_error:errorCode});
      if(finished.error)throw Error('PUSH_ACK_FAILED');if(status==='DELIVERED')delivered++;
    }));
    return Response.json({processed:jobs.length,delivered});
  }catch{return Response.json({error:'Push worker temporarily unavailable; queued deliveries will retry.'},{status:503});}
});
