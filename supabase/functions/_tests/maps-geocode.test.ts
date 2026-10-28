import { assertEquals } from 'jsr:@std/assert@1.0.14';
import { createHandler } from '../_shared/handler.ts';
import { fakeAuthDeps, jsonRequest } from './fixtures.ts';
import { createSupabaseMock } from './mocks.ts';
import { handle } from '../maps-geocode/handler.ts';

Deno.test('maps-geocode returns a forward cache hit without a provider client', async () => {
  const service = createSupabaseMock({
    tables: {
      geocoding_cache: {
        select: () => ({
          data: {
            result: {
              lat: -6.7924,
              lng: 39.2083,
              formatted_address: 'Dar es Salaam, Tanzania',
              place_id: 'place-1',
            },
          },
          error: null,
        }),
      },
    },
  });

  const handler = createHandler('maps-geocode', (req, ctx) =>
    handle(req, ctx, {
      auth: fakeAuthDeps(),
      service,
    }));

  const response = await handler(
    jsonRequest('http://localhost/functions/v1/maps-geocode', {
      body: { address: 'Dar es Salaam' },
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.data.cached, true);
  assertEquals(body.data.place_id, 'place-1');
});
