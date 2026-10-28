// deno-lint-ignore-file require-await
import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle } from '../notification-dispatch/handler.ts';

const profileId = '33333333-3333-4333-8333-333333333333';

Deno.test('notification-dispatch skips quiet-hours channels and delivers the rest', async () => {
  const delivered: string[] = [];
  const service = createSupabaseMock({
    rpc(name, args) {
      if (name !== 'send_notification') return { data: null, error: null };
      if (args.p_channel === 'push') return { data: null, error: null };
      return { data: `notification-${args.p_channel}`, error: null };
    },
    tables: {
      notification_log: {
        select: (context) => {
          const id = String(context.filters[0]?.[1] ?? '');
          return {
            data: {
              public_id: id,
              profile_id: profileId,
              channel: id.endsWith('sms') ? 'sms' : 'email',
              recipient: id.endsWith('sms') ? '+255700000000' : 'customer@example.test',
              subject: 'SafeShift',
              body: 'Your job is ready',
              status: 'pending',
              provider: null,
              reference_type: null,
              reference_id: null,
            },
            error: null,
          };
        },
      },
    },
  });

  const handler = createHandler('notification-dispatch', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      service,
      deliver: async (channel) => {
        delivered.push(channel);
        return {
          notification_id: `notification-${channel}`,
          status: 'sent',
          provider_used: 'test',
        };
      },
    }));

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/notification-dispatch', {
      body: {
        profile_id: profileId,
        template_code: 'job_status',
        channels: ['push', 'sms', 'email'],
        variables: { job_id: 'job-1' },
      },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data.notification_ids, ['notification-sms', 'notification-email']);
  assertEquals(body.data.channels_used, ['sms', 'email']);
  assertEquals(delivered, ['sms', 'email']);
});

Deno.test('notification-dispatch returns 502 when every RPC fails', async () => {
  const service = createSupabaseMock({
    rpc: () => ({ data: null, error: { message: 'rpc unavailable' } }),
  });

  const handler = createHandler(
    'notification-dispatch',
    (req, ctx) => handle(req, ctx, { auth: fakeAuthDeps(), service }),
  );

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/notification-dispatch', {
      body: {
        profile_id: profileId,
        template_code: 'job_status',
        channels: ['sms', 'email'],
      },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 502);
  assertEquals(body.error.code, 'provider_error');
});
