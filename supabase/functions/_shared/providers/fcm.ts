import { ProviderError } from '../errors.ts';
import type { PushResult } from '../types/index.ts';
import { type FetchLike, requestJson, type SleepLike } from './base.ts';

export interface FcmServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export interface FcmConfig {
  serviceAccount: FcmServiceAccount;
  baseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

function base64UrlEncode(bytes: Uint8Array | string): string {
  const data = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes;
  let binary = '';
  for (const byte of data) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const binary = atob(body);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

export class FcmClient {
  private readonly baseUrl: string;
  private readonly config: FcmConfig;
  private accessToken: string | null = null;
  private accessTokenExpiresAt = 0;

  constructor(config: FcmConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? 'https://fcm.googleapis.com').replace(/\/$/, '');
  }

  private async getAccessToken(): Promise<string> {
    if (this.accessToken && Date.now() < this.accessTokenExpiresAt - 60_000) {
      return this.accessToken;
    }

    const tokenUri = this.config.serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token';
    const now = Math.floor(Date.now() / 1_000);
    const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claim = base64UrlEncode(
      JSON.stringify({
        iss: this.config.serviceAccount.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: tokenUri,
        iat: now,
        exp: now + 3_600,
      }),
    );
    const unsigned = `${header}.${claim}`;

    const key = await crypto.subtle.importKey(
      'pkcs8',
      pemToDer(this.config.serviceAccount.private_key) as BufferSource,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(unsigned),
    );
    const assertion = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;

    const fetchImpl = this.config.fetchImpl ?? fetch;
    const response = await fetchImpl(tokenUri, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    });

    if (!response.ok) {
      throw new ProviderError('fcm', 'Unable to obtain FCM access token', {
        status: response.status,
      });
    }

    const payload = (await response.json()) as { access_token?: string; expires_in?: number };
    if (!payload.access_token) {
      throw new ProviderError('fcm', 'FCM token response was empty');
    }

    this.accessToken = payload.access_token;
    this.accessTokenExpiresAt = Date.now() + (payload.expires_in ?? 3_600) * 1_000;
    return this.accessToken;
  }

  private async send(message: Record<string, unknown>, reference: string): Promise<PushResult> {
    const accessToken = await this.getAccessToken();
    const { data } = await requestJson<Record<string, unknown>>(
      'fcm',
      `${this.baseUrl}/v1/projects/${this.config.serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${accessToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ message }),
      },
      {
        fetchImpl: this.config.fetchImpl,
        sleep: this.config.sleep,
        requestId: this.config.requestId,
      },
    );

    return {
      provider_message_id: String(data.name ?? reference),
      status: 'sent',
    };
  }

  sendToToken(
    token: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
    deepLink?: string,
  ): Promise<PushResult> {
    return this.send(
      {
        token,
        notification: { title, body },
        data: { ...data, ...(deepLink ? { deep_link: deepLink } : {}) },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      },
      token,
    );
  }

  sendToTopic(
    topic: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<PushResult> {
    return this.send(
      {
        topic,
        notification: { title, body },
        data,
        android: { priority: 'high' },
      },
      topic,
    );
  }
}

export function parseServiceAccount(raw: string): FcmServiceAccount {
  const decoded = raw.trim().startsWith('{') ? raw : atob(raw);
  const parsed = JSON.parse(decoded) as FcmServiceAccount;
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new ProviderError('fcm', 'FCM service account JSON is incomplete');
  }
  return parsed;
}
