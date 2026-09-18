import { OAuth2Client } from 'google-auth-library';
import { ApiError, requireThat } from './errors.js';

export class GoogleIdentity {
  constructor(config, clientSecret) {
    this.config = config;
    this.client = new OAuth2Client(config.clientId, clientSecret, `${config.apiOrigin}/v1/auth/google/callback`);
  }
  authorizationUrl({ state, nonce, challenge }) {
    return this.client.generateAuthUrl({
      scope: ['openid', 'email', 'profile'], access_type: 'online',
      state, nonce, code_challenge: challenge, code_challenge_method: 'S256',
      prompt: 'select_account', include_granted_scopes: false,
    });
  }
  async exchange(code, transaction) {
    try {
      const { tokens } = await this.client.getToken({ code, codeVerifier: transaction.verifier });
      requireThat(tokens.id_token, 401, 'GOOGLE_IDENTITY_INVALID', 'Google sign-in could not be verified.');
      const ticket = await this.client.verifyIdToken({ idToken: tokens.id_token, audience: this.config.clientId });
      const claims = ticket.getPayload();
      requireThat(claims && claims.nonce === transaction.nonce &&
        typeof claims.sub === 'string' && claims.sub.length > 0 && claims.sub.length <= 255 &&
        claims.email_verified === true && typeof claims.email === 'string' &&
        ['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss),
      401, 'GOOGLE_IDENTITY_INVALID', 'Google sign-in could not be verified.');
      // Identity-only tokens are deliberately discarded. Drive connection is separate.
      return { sub: claims.sub, email: claims.email, name: String(claims.name || '').slice(0, 200) };
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(401, 'GOOGLE_SIGN_IN_FAILED', 'Google sign-in failed. Start sign-in again.');
    }
  }
}
