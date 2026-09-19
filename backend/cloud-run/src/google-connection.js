import { OAuth2Client } from 'google-auth-library';
import { ApiError, requireThat } from './errors.js';

export const DATA_SCOPES = ['https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/spreadsheets'];
export class ReconnectRequired extends ApiError {
  constructor() { super(409, 'RECONNECT_REQUIRED', 'Reconnect Google. Your existing workspace is preserved.'); }
}

export class GoogleConnection {
  constructor(config, clientSecret) { this.config = config; this.secret = clientSecret; }
  client() {
    return new OAuth2Client(this.config.clientId, this.secret, `${this.config.apiOrigin}/v1/google/callback`);
  }
  authorizationUrl({ state, nonce, challenge, email }) {
    return this.client().generateAuthUrl({
      scope: ['openid', 'email', 'profile', ...DATA_SCOPES], access_type: 'offline',
      prompt: 'consent select_account', include_granted_scopes: false, login_hint: email,
      state, nonce, code_challenge: challenge, code_challenge_method: 'S256',
    });
  }
  async exchange(code, tx) {
    const client = this.client();
    try {
      const { tokens } = await client.getToken({ code, codeVerifier: tx.verifier });
      const ticket = await client.verifyIdToken({ idToken: tokens.id_token, audience: this.config.clientId });
      const claims = ticket.getPayload();
      requireThat(claims?.sub === tx.googleSub && claims.nonce === tx.nonce && claims.email_verified === true &&
        ['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss),
      403, 'GOOGLE_ACCOUNT_MISMATCH', 'Connect the same Google account used to sign in.');
      const scopes = (tokens.scope || '').split(' ');
      requireThat(DATA_SCOPES.every(scope => scopes.includes(scope)), 403, 'GOOGLE_SCOPES_REQUIRED', 'Allow the requested Sheets and Drive access.');
      requireThat(typeof tokens.refresh_token === 'string' && tokens.refresh_token.length > 0,
        409, 'OFFLINE_ACCESS_REQUIRED', 'Grant Google offline access to connect your company.');
      return { refreshToken: tokens.refresh_token, scopes, sub: claims.sub };
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(401, 'GOOGLE_CONNECTION_FAILED', 'Google connection failed. Please connect again.');
    }
  }
  async accessToken(refreshToken) {
    const client = this.client();
    client.setCredentials({ refresh_token: refreshToken });
    try {
      const { token } = await client.getAccessToken();
      if (!token) throw new ReconnectRequired();
      return token;
    } catch (error) {
      if (error instanceof ReconnectRequired || error.response?.data?.error === 'invalid_grant') throw new ReconnectRequired();
      throw new ApiError(503, 'GOOGLE_UNAVAILABLE', 'Google is temporarily unavailable. Retry setup.');
    }
  }
}
