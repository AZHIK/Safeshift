// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { handle, otpMessage, signStandardWebhook } from '../auth-sms-hook/handler.ts';
import { MesejiClient, mesejiContact } from '../_shared/providers/meseji.ts';

const SECRET = `v1,whsec_${btoa('safeshift-test-secret-0123456789')}`;
const NOW = 1_800_000_000_000;

async function signedRequest(body: string, secret = SECRET, timestamp = NOW / 1000) {
  const id = 'msg_test';
  const ts = String(timestamp);
  const signature = await signStandardWebhook(secret, id, ts, body);
  return new Request('https://fn.test/auth-sms-hook', {
    method: 'POST',
    headers: {
      'webhook-id': id,
      'webhook-timestamp': ts,
      'webhook-signature': `v1,${signature}`,
    },
    body,
  });
}

function recordingClient() {
  const calls: { url: string; init: RequestInit }[] = [];
  const fetchImpl = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(JSON.stringify({ success: true, batch_id: 'batch-1' }), { status: 200 });
  }) as unknown as typeof fetch;
  const client = new MesejiClient({ apiKey: 'key-1', senderId: 'SAFESHIFT', fetchImpl });
  return { client, calls };
}

const payload = JSON.stringify({
  user: { id: 'u1', phone: '255712345678' },
  sms: { otp: '123456' },
});

Deno.test('auth-sms-hook sends the OTP through Meseji', async () => {
  const { client, calls } = recordingClient();
  const res = await handle(await signedRequest(payload), {
    secret: SECRET,
    client,
    now: () => NOW,
  });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {});
  assertEquals(calls.length, 1);
  assertEquals(calls[0].url, 'https://meseji.co.tz/api/v1/sms/send');
  assertEquals((calls[0].init.headers as Record<string, string>)['x-api-key'], 'key-1');
  assertEquals(JSON.parse(String(calls[0].init.body)), {
    sender_id: 'SAFESHIFT',
    message: otpMessage('123456'),
    contacts: '255712345678',
  });
});

Deno.test('auth-sms-hook rejects a bad signature without sending', async () => {
  const { client, calls } = recordingClient();
  const other = `v1,whsec_${btoa('a-different-secret-0123456789abc')}`;
  const res = await handle(await signedRequest(payload, other), {
    secret: SECRET,
    client,
    now: () => NOW,
  });
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test('auth-sms-hook rejects a stale timestamp', async () => {
  const { client, calls } = recordingClient();
  const res = await handle(await signedRequest(payload, SECRET, NOW / 1000 - 3600), {
    secret: SECRET,
    client,
    now: () => NOW,
  });
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test('auth-sms-hook reports a Meseji failure in the Auth hook error shape', async () => {
  const fetchImpl =
    (async () =>
      new Response(JSON.stringify({ message: 'bad key' }), { status: 401 })) as typeof fetch;
  const client = new MesejiClient({ apiKey: 'x', senderId: 'S', fetchImpl, sleep: async () => {} });
  const res = await handle(await signedRequest(payload), {
    secret: SECRET,
    client,
    now: () => NOW,
  });
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error.http_code, 502);
});

Deno.test('mesejiContact produces 255XXXXXXXXX', () => {
  assertEquals(mesejiContact('+255712345678'), '255712345678');
  assertEquals(mesejiContact('0712345678'), '255712345678');
  assertEquals(mesejiContact('712345678'), '255712345678');
  assertEquals(mesejiContact('255712345678'), '255712345678');
});
