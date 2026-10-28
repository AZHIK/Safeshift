import { ProviderUnavailableError } from './errors.ts';
import { readOptionalSecret, readSecret } from './vault.ts';
import { SelcomClient } from './providers/selcom.ts';
import { FlutterwaveClient } from './providers/flutterwave.ts';
import { BeemClient } from './providers/beem.ts';
import { AfricaSTalkingClient } from './providers/africastalking.ts';
import { ResendClient } from './providers/resend.ts';
import { FcmClient, parseServiceAccount } from './providers/fcm.ts';
import { GoogleMapsClient } from './providers/google_maps.ts';
import type { FetchLike } from './providers/base.ts';

export async function selcomClient(
  requestId?: string,
  fetchImpl?: FetchLike,
): Promise<SelcomClient> {
  const apiKey = await readOptionalSecret('SELCOM_API_KEY');
  const apiSecret = await readOptionalSecret('SELCOM_API_SECRET');
  if (!apiKey || !apiSecret) {
    throw new ProviderUnavailableError('selcom', 'Selcom credentials are not configured');
  }
  return new SelcomClient({
    apiKey,
    apiSecret,
    vendorId: (await readOptionalSecret('SELCOM_VENDOR_ID')) ?? undefined,
    webhookSecret: (await readOptionalSecret('SELCOM_WEBHOOK_SECRET')) ?? undefined,
    baseUrl: Deno.env.get('SELCOM_BASE_URL') ?? undefined,
    requestId,
    fetchImpl,
  });
}

export async function flutterwaveClient(
  requestId?: string,
  fetchImpl?: FetchLike,
): Promise<FlutterwaveClient> {
  const secretKey = await readOptionalSecret('FLUTTERWAVE_SECRET_KEY');
  if (!secretKey) {
    throw new ProviderUnavailableError('flutterwave', 'Flutterwave credentials are not configured');
  }
  return new FlutterwaveClient({
    secretKey,
    secretHash: (await readOptionalSecret('FLUTTERWAVE_WEBHOOK_SECRET')) ??
      (await readOptionalSecret('FLUTTERWAVE_SECRET_HASH')) ?? undefined,
    baseUrl: Deno.env.get('FLUTTERWAVE_BASE_URL') ?? undefined,
    redirectUrl: Deno.env.get('FLUTTERWAVE_REDIRECT_URL') ?? undefined,
    requestId,
    fetchImpl,
  });
}

export async function beemClient(requestId?: string, fetchImpl?: FetchLike): Promise<BeemClient> {
  const apiKey = await readOptionalSecret('BEEM_API_KEY');
  const apiSecret = (await readOptionalSecret('BEEM_SECRET_KEY')) ??
    (await readOptionalSecret('BEEM_API_SECRET'));
  if (!apiKey || !apiSecret) {
    throw new ProviderUnavailableError('beem', 'Beem credentials are not configured');
  }
  return new BeemClient({
    apiKey,
    apiSecret,
    senderId: Deno.env.get('BEEM_SENDER_ID') ?? 'SAFESHIFT',
    baseUrl: Deno.env.get('BEEM_BASE_URL') ?? undefined,
    requestId,
    fetchImpl,
  });
}

export async function africaSTalkingClient(
  requestId?: string,
  fetchImpl?: FetchLike,
): Promise<AfricaSTalkingClient> {
  const username = await readOptionalSecret('AFRICASTALKING_USERNAME');
  const apiKey = await readOptionalSecret('AFRICASTALKING_API_KEY');
  if (!username || !apiKey) {
    throw new ProviderUnavailableError(
      'africastalking',
      "Africa's Talking credentials are not configured",
    );
  }
  return new AfricaSTalkingClient({
    username,
    apiKey,
    senderId: Deno.env.get('AFRICASTALKING_SENDER_ID') ?? undefined,
    baseUrl: Deno.env.get('AFRICASTALKING_BASE_URL') ?? undefined,
    requestId,
    fetchImpl,
  });
}

export async function resendClient(
  requestId?: string,
  fetchImpl?: FetchLike,
): Promise<ResendClient> {
  const apiKey = await readOptionalSecret('RESEND_API_KEY');
  if (!apiKey) {
    throw new ProviderUnavailableError('resend', 'Resend credentials are not configured');
  }
  return new ResendClient({
    apiKey,
    from: Deno.env.get('RESEND_FROM_EMAIL') ?? 'SafeShift <noreply@safeshift.app>',
    requestId,
    fetchImpl,
  });
}

export async function fcmClient(requestId?: string, fetchImpl?: FetchLike): Promise<FcmClient> {
  const raw = await readOptionalSecret('FCM_SERVICE_ACCOUNT_JSON');
  if (!raw) {
    throw new ProviderUnavailableError('fcm', 'FCM service account is not configured');
  }
  return new FcmClient({
    serviceAccount: parseServiceAccount(raw),
    requestId,
    fetchImpl,
  });
}

export async function googleMapsClient(
  requestId?: string,
  fetchImpl?: FetchLike,
): Promise<GoogleMapsClient> {
  const apiKey = (await readOptionalSecret('GOOGLE_MAPS_API_KEY')) ??
    (await readOptionalSecret('GOOGLE_MAPS_SERVER_API_KEY'));
  if (!apiKey) {
    throw new ProviderUnavailableError('google_maps', 'Google Maps API key is not configured');
  }
  return new GoogleMapsClient({
    apiKey,
    baseUrl: Deno.env.get('GOOGLE_MAPS_BASE_URL') ?? undefined,
    requestId,
    fetchImpl,
  });
}

export function providerSecret(name: string): Promise<string> {
  return readSecret(name);
}
