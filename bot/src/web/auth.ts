import { config } from '../config';

interface HackClubUser {
  slackId: string;
  name: string;
  email: string;
}

export async function exchangeCodeForToken(code: string): Promise<string | null> {
  const res = await fetch('https://auth.hackclub.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: config.oauth.clientId,
      client_secret: config.oauth.clientSecret,
      redirect_uri: config.oauth.redirectUri,
      code,
      grant_type: 'authorization_code',
    }),
  });

  if (!res.ok) {
    console.error('[auth] Token exchange failed:', res.status, await res.text());
    return null;
  }

  const data = (await res.json()) as { access_token?: string; token_type?: string };
  return data.access_token || null;
}

export async function getUserInfo(accessToken: string): Promise<HackClubUser | null> {
  const res = await fetch('https://auth.hackclub.com/api/v1/me', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!res.ok) {
    console.error('[auth] User info failed:', res.status, await res.text());
    return null;
  }

  const data = (await res.json()) as { identity?: { slack_id?: string; first_name?: string; last_name?: string; name?: string; primary_email?: string } };
  const identity = data.identity || {};
  console.log('[auth] User info from HC:', JSON.stringify(identity));

  return {
    slackId: identity.slack_id || '',
    name: identity.first_name || identity.name || 'Support',
    email: identity.primary_email || '',
  };
}

export function getAuthorizationUrl(): string {
  const params = new URLSearchParams({
    client_id: config.oauth.clientId,
    redirect_uri: config.oauth.redirectUri,
    response_type: 'code',
    scope: 'openid profile name slack_id',
  });
  return `https://auth.hackclub.com/oauth/authorize?${params.toString()}`;
}
