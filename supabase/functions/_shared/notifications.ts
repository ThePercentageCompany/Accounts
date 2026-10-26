// deno-lint-ignore-file no-explicit-any
import { notificationInput } from './domain/notification-policy.js';
import { ApiError, requireThat } from './domain/errors.js';
import { databaseError } from './workspace.ts';

export async function notificationRequest(ctx:any, action:string, input:any = {}) {
  ctx.canRead('Tasks');
  if (action === 'settings') requireThat(ctx.admin,403,'ADMIN_REQUIRED','Only admins can choose the workspace notification sound.');
  if (action !== 'list') notificationInput(action,input);
  else {
    requireThat(Object.keys(input).every(k=>['cursor','filter','limit'].includes(k)) &&
      ['all','unread','task','deadline','overdue'].includes(input.filter??'all') &&
      (!input.cursor || typeof input.cursor==='string' && input.cursor.length<=160 && input.cursor.includes('|')) &&
      (input.limit==null || Number.isSafeInteger(Number(input.limit)) && Number(input.limit)>=1 && Number(input.limit)<=100),
      400,'INVALID_NOTIFICATION','Invalid notification page.');
  }
  const {data,error}=await ctx.db.rpc('task_notification_api',{p_company:ctx.company.id,p_actor:ctx.user.id,p_action:action,p_input:input});
  if(error?.message?.includes('NOTIFICATION_FORBIDDEN'))throw new ApiError(403,'SECTION_FORBIDDEN','Task notifications are unavailable.');
  if(error)databaseError(error);
  return {...data,pushAvailable:!!Deno.env.get('FCM_WEB_VAPID_KEY')&&!!Deno.env.get('FCM_SERVICE_ACCOUNT_JSON'),
    vapidKey:Deno.env.get('FCM_WEB_VAPID_KEY')??'',firebaseConfig:JSON.parse(Deno.env.get('FIREBASE_WEB_CONFIG')??'null')};
}
