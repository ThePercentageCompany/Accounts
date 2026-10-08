import { GoogleAuth } from 'google-auth-library';
export function nativePushSender(project, auth = new GoogleAuth({scopes: ['https://www.googleapis.com/auth/firebase.messaging']})) {
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(project)) throw new Error('Invalid Firebase project');
  return async (subscription, payload) => {
    const client = await auth.getClient();
    try {
      await client.request({url: 'https://fcm.googleapis.com/v1/projects/' + project + '/messages:send', method: 'POST',
        timeout: 15000, data: {message: {token: subscription.token,
          notification: {title: payload.title, body: payload.body},
          data: {id: payload.id, companyId: payload.companyId, taskId: payload.taskId, type: payload.type},
          android: {priority: 'high', ttl: '3600s'},
          apns: {headers: {'apns-priority': '10'}, payload: {aps: {sound: 'default'}}}}}});
    } catch (error) {
      const details = error.response?.data?.error?.details || [];
      if (details.some(d => d.errorCode === 'UNREGISTERED')) error.statusCode = 410;
      throw error;
    }
  };
}
