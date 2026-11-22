// deno-lint-ignore-file no-explicit-any
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { pushOutcome } from '../_shared/domain/notification-policy.js';

let cached:{token:string,expires:number}|null=null;
const titles: Record<string, string> = {
  'task-assigned': 'New task assigned',
  'task-unassigned': 'Task unassigned',
  'task-status': 'Task status updated',
  'task-updated': 'Task updated',
  'task-deleted': 'Task deleted',
  'task-comment': 'Task comment added',
  'task-attachment': 'Task attachment updated',
  'task-deadline': 'Task deadline updated',
  'task-due': 'Task deadline reminder',
  'task-overdue': 'Task overdue',
  'payroll-paid': 'Salary payment recorded',
  'push-test': 'Test notification',
  'payroll-due': 'Payroll payment reminder',
};

function pushMessage(job: any) {
  const title = titles[job.type] ?? 'Workspace notification';
  const body = job.type === 'push-test' ? 'Push notifications are working on this device.' : 'Open your workspace for details.';
  const data = {
    id: job.notificationId, notificationId: job.notificationId,
    companyId: job.companyId, taskId: job.canOpenTask ? (job.taskId ?? '') : '',
    type: job.type, sound: job.sound, title, body,
  };
  const base = { token: job.token, data };
  if (job.platform === 'android') {
    return { ...base, notification: { title, body }, android: {
      ttl: '300s', priority: 'high', notification: {
        tag: job.notificationId, channel_id: job.sound === 'none' ? 'workspace_silent' : 'workspace_alerts',
      },
    } };
  }
  if (job.platform === 'ios') {
    return { ...base, notification: { title, body }, apns: {
      headers: { 'apns-expiration': String(Math.floor(Date.now() / 1000) + 300) },
      payload: { aps: job.sound === 'none' ? {} : { sound: 'default' } },
    } };
  }
  return { ...base, webpush: { headers: { TTL: '300',
    Urgency: job.type === 'task-overdue' ? 'high' : 'normal' } } };
}
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
  let failureCode = 'FCM_SERVICE_ACCOUNT_INVALID';
  try {
    const account=JSON.parse(raw);
    if (!account?.project_id || !account?.client_email ||
        typeof account.private_key !== 'string' || !account.private_key.includes('BEGIN PRIVATE KEY')) {
      throw Error('Invalid service account');
    }
    failureCode = 'FCM_AUTH_FAILED';
    const token=await accessToken(account);
    failureCode = 'PUSH_QUEUE_UNAVAILABLE';
    const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
    const {data:jobs,error}=await db.rpc('claim_notification_push',{p_limit:50});if(error)throw Error('PUSH_QUEUE_UNAVAILABLE');
    failureCode = 'PUSH_ACK_FAILED';
    let delivered=0;
    // Bounded batches avoid task-write latency and provider request bursts.
    for(let start=0;start<jobs.length;start+=5)await Promise.all(jobs.slice(start,start+5).map(async(j:any)=>{
      let status='RETRY',errorCode:string|null=null;
      try {
        const response=await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,{
          method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(10000),
          body:JSON.stringify({message:pushMessage(j)})});
        const result=await response.json();status=pushOutcome(response.status,result);errorCode=status==='DELIVERED'?null:`FCM_HTTP_${response.status}`;
      }catch{errorCode='FCM_TEMPORARILY_UNAVAILABLE';}
      const finished=await db.rpc('finish_notification_push',{p_id:j.id,p_lease:j.lease,p_status:status,p_error:errorCode});
      if(finished.error)throw Error('PUSH_ACK_FAILED');if(status==='DELIVERED')delivered++;
    }));
    return Response.json({processed:jobs.length,delivered});
  }catch{return Response.json({code:failureCode,error:'Push worker temporarily unavailable; queued deliveries will retry.'},{status:503});}
});
