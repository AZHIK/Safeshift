// deno-lint-ignore-file require-await
import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { BrevoClient, parseSender } from '../_shared/providers/brevo.ts';
import { codeSms, handle, maskEmail, maskPhone } from '../admin-otp/handler.ts';
import { MesejiClient } from '../_shared/providers/meseji.ts';
import { fakeAuthDeps, jsonRequest, makeJwt } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';

const SESSION = '99999999-9999-4999-8999-999999999999';

function recordingBrevo(status = 201) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fetchImpl = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(
      JSON.stringify(status < 300 ? { messageId: '<m1@brevo>' } : { message: 'Key not found' }),
      {
        status,
      },
    );
  }) as unknown as typeof fetch;
  return {
    client: new BrevoClient({
      apiKey: 'brevo-key',
      from: 'SafeShift <noreply@safeshift.test>',
      fetchImpl,
      sleep: async () => {},
    }),
    calls,
  };
}

function serviceMock(
  rpcs: { name: string; args: Record<string, unknown> }[],
  issue: { data: unknown; error: unknown } = {
    data: [{ code: '123456', destination: 'kasimu@example.com' }],
    error: null,
  },
) {
  return createSupabaseMock({
    rpc: (name, args) => {
      rpcs.push({ name, args });
      return name === 'admin_issue_second_factor_challenge'
        ? (issue as never)
        : { data: null, error: null };
    },
  });
}

function request(sessionId: string | null = SESSION, body: Record<string, unknown> = {}) {
  return jsonRequest('http://localhost/functions/v1/admin-otp', {
    body,
    token: makeJwt(sessionId ? { session_id: sessionId } : {}),
  });
}

Deno.test('brevo client sends the documented request shape', async () => {
  const { client, calls } = recordingBrevo();
  const result = await client.sendEmail('a@example.com', '', 'Hi', '<p>Hi</p>', 'Hi', 'ref-1');
  assertEquals(result.provider_message_id, '<m1@brevo>');
  assertEquals(calls[0].url, 'https://api.brevo.com/v3/smtp/email');
  assertEquals((calls[0].init.headers as Record<string, string>)['api-key'], 'brevo-key');
  assertEquals(JSON.parse(String(calls[0].init.body)), {
    sender: { name: 'SafeShift', email: 'noreply@safeshift.test' },
    to: [{ email: 'a@example.com' }],
    subject: 'Hi',
    htmlContent: '<p>Hi</p>',
    textContent: 'Hi',
    headers: { 'X-Entity-Ref-ID': 'ref-1' },
  });
});

Deno.test('parseSender, maskEmail and maskPhone', () => {
  assertEquals(maskPhone('+255712345678'), '+255 •••• 678');
  assertEquals(parseSender('"Safe Shift" <a@b.co>'), { name: 'Safe Shift', email: 'a@b.co' });
  assertEquals(parseSender('a@b.co'), { email: 'a@b.co' });
  assertEquals(maskEmail('kasimu@example.com'), 'ka••••@example.com');
});

Deno.test('admin-otp issues for the caller session and emails the code', async () => {
  const rpcs: { name: string; args: Record<string, unknown> }[] = [];
  const { client, calls } = recordingBrevo();
  const handler = createHandler(
    'admin-otp',
    (req, ctx) =>
      handle(req, ctx, { auth: fakeAuthDeps(), service: serviceMock(rpcs), email: client }),
  );
  const res = await handler(request());
  const body = await res.json();
  assertEquals(res.status, 200);
  assertEquals(body.data, {
    sent: true,
    channel: 'email',
    to: 'ka••••@example.com',
    expires_in_seconds: 600,
  });
  assertEquals(rpcs, [{
    name: 'admin_issue_second_factor_challenge',
    args: {
      p_profile_id: '00000000-0000-4000-8000-000000000001',
      p_session_id: SESSION,
      p_channel: 'email',
    },
  }]);
  const sent = JSON.parse(String(calls[0].init.body));
  assertEquals(sent.to, [{ email: 'kasimu@example.com' }]);
  assertStringIncludes(sent.textContent, '123456');
  // The code never appears in the HTTP response.
  assertEquals(JSON.stringify(body).includes('123456'), false);
});

Deno.test('admin-otp discards the code when the email fails', async () => {
  const rpcs: { name: string; args: Record<string, unknown> }[] = [];
  const { client } = recordingBrevo(401);
  const handler = createHandler(
    'admin-otp',
    (req, ctx) =>
      handle(req, ctx, { auth: fakeAuthDeps(), service: serviceMock(rpcs), email: client }),
  );
  const res = await handler(request());
  assertEquals(res.status, 502);
  assertEquals(rpcs.map((r) => r.name), [
    'admin_issue_second_factor_challenge',
    'admin_discard_email_challenge',
  ]);
});

Deno.test('admin-otp answers 429 inside the one-minute window', async () => {
  const handler = createHandler('admin-otp', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      service: serviceMock([], {
        data: null,
        error: { code: '53400', message: 'a code was sent less than a minute ago' },
      }),
      email: recordingBrevo().client,
    }));
  const res = await handler(request());
  assertEquals(res.status, 429);
});

Deno.test('admin-otp needs a session id in the token', async () => {
  const handler = createHandler(
    'admin-otp',
    (req, ctx) =>
      handle(req, ctx, {
        auth: fakeAuthDeps(),
        service: serviceMock([]),
        email: recordingBrevo().client,
      }),
  );
  const res = await handler(request(null));
  assertEquals(res.status, 401);
});

Deno.test('admin-otp sends an SMS code through Meseji', async () => {
  const rpcs: { name: string; args: Record<string, unknown> }[] = [];
  const smsCalls: { url: string; init: RequestInit }[] = [];
  const fetchImpl = (async (url: string, init: RequestInit) => {
    smsCalls.push({ url, init });
    return new Response(JSON.stringify({ success: true, batch_id: 'b1' }), { status: 200 });
  }) as unknown as typeof fetch;
  const sms = new MesejiClient({ apiKey: 'm-key', senderId: 'SAFESHIFT', fetchImpl });
  const handler = createHandler('admin-otp', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      service: serviceMock(rpcs, {
        data: [{ code: '654321', destination: '+255712345678' }],
        error: null,
      }),
      email: recordingBrevo().client,
      sms,
    }));
  const res = await handler(request(SESSION, { channel: 'sms' }));
  const body = await res.json();
  assertEquals(res.status, 200);
  assertEquals(body.data, {
    sent: true,
    channel: 'sms',
    to: '+255 •••• 678',
    expires_in_seconds: 600,
  });
  assertEquals(rpcs[0].args.p_channel, 'sms');
  assertEquals(JSON.parse(String(smsCalls[0].init.body)), {
    sender_id: 'SAFESHIFT',
    message: codeSms('654321'),
    contacts: '255712345678',
  });
  assertEquals(JSON.stringify(body).includes('654321'), false);
});

Deno.test('admin-otp rejects an unknown channel', async () => {
  const rpcs: { name: string; args: Record<string, unknown> }[] = [];
  const handler = createHandler(
    'admin-otp',
    (req, ctx) =>
      handle(req, ctx, {
        auth: fakeAuthDeps(),
        service: serviceMock(rpcs),
        email: recordingBrevo().client,
      }),
  );
  const res = await handler(request(SESSION, { channel: 'pigeon' }));
  assertEquals(res.status, 422);
  assertEquals(rpcs, []);
});
