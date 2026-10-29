import { z } from 'npm:zod@3.23.8';
import { ValidationError } from './errors.ts';

export const coordinateSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

const optionalUuid = z.string().uuid().optional();
const optionalText = z.string().trim().min(1).max(2_000).optional();

export const quoteSchema = z.object({
  pickup: coordinateSchema.extend({ address: z.string().trim().min(1).max(500) }),
  destination: coordinateSchema.extend({ address: z.string().trim().min(1).max(500) }),
  vehicle_type_id: z.string().uuid(),
  cargo_type_id: optionalUuid,
  cargo_weight_kg: z.number().nonnegative().optional(),
  cargo_volume_m3: z.number().nonnegative().optional(),
  scheduled_at: z.string().datetime().optional(),
  stop_count: z.number().int().min(2).max(20).optional(),
  waiting_minutes: z.number().int().min(0).max(1_440).optional(),
  equipment_ids: z.array(z.string().uuid()).max(20).optional(),
  promo_code_id: optionalUuid,
});

export const paymentInitiateSchema = z
  .object({
    job_id: z.string().uuid(),
    amount: z.number().positive().optional(),
    phone: z.string().trim().min(7).max(32).optional(),
    card_token: z.string().trim().min(1).max(500).optional(),
    payment_method_id: optionalUuid,
  })
  .refine(
    (value) =>
      value.phone !== undefined || value.card_token !== undefined ||
      value.payment_method_id !== undefined,
    {
      message: 'phone, card_token, or payment_method_id is required',
      path: ['phone'],
    },
  );

export const refundSchema = z.object({
  payment_id: z.string().uuid(),
  amount: z.number().positive(),
  reason: z.string().trim().min(3).max(1_000),
  refund_type: z.enum(['full', 'partial']).default('partial'),
});

export const smsSchema = z.object({
  to: z.string().trim().min(7).max(32).optional(),
  profile_id: optionalUuid,
  body: optionalText,
  template_code: optionalText,
  variables: z.record(z.string(), z.union([z.string(), z.number(), z.boolean()])).optional(),
  reference_type: optionalText,
  reference_id: optionalUuid,
});

export const emailSchema = z.object({
  to: z.string().email().optional(),
  profile_id: optionalUuid,
  subject: z.string().trim().min(1).max(300).optional(),
  html: z.string().min(1).max(200_000).optional(),
  text: z.string().min(1).max(200_000).optional(),
  template_code: optionalText,
  variables: z.record(z.string(), z.union([z.string(), z.number(), z.boolean()])).optional(),
  reference_type: optionalText,
  reference_id: optionalUuid,
});

export const pushSchema = z
  .object({
    profile_id: optionalUuid,
    device_token: z.string().trim().min(1).max(4_096).optional(),
    title: z.string().trim().min(1).max(200),
    body: z.string().trim().min(1).max(2_000),
    data: z.record(z.string(), z.string()).optional(),
    deep_link: z.string().trim().max(1_000).optional(),
  })
  .refine((value) => value.profile_id !== undefined || value.device_token !== undefined, {
    message: 'profile_id or device_token is required',
    path: ['profile_id'],
  });

export const notificationDispatchSchema = z.object({
  profile_id: z.string().uuid(),
  template_code: z.string().trim().min(1).max(120),
  channels: z.array(z.enum(['push', 'sms', 'email'])).min(1).max(3),
  variables: z.record(z.string(), z.union([z.string(), z.number(), z.boolean()])).default({}),
  reference_type: optionalText,
  reference_id: optionalUuid,
});

export const mapsDistanceSchema = z.object({
  origins: z.array(coordinateSchema).min(1).max(25),
  destinations: z.array(coordinateSchema).min(1).max(25),
  mode: z.enum(['driving', 'walking', 'bicycling', 'transit']).default('driving'),
});

export const mapsGeocodeSchema = z.union([
  z.object({ address: z.string().trim().min(1).max(500) }),
  z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) }),
]);

export const payoutSchema = z.object({
  payout_id: z.string().uuid(),
  provider_code: z.enum(['selcom', 'flutterwave']).optional(),
});

export const dataExportSchema = z
  .object({
    request_id: optionalUuid,
    profile_id: optionalUuid,
  })
  .refine((value) => value.request_id !== undefined || value.profile_id !== undefined, {
    message: 'request_id or profile_id is required',
    path: ['request_id'],
  });

export const sosAlertSchema = z.object({
  alert_id: z.string().uuid(),
  job_id: z.string().uuid().optional(),
  note: z.string().trim().max(1_000).optional(),
});

export const tripShareSchema = z.object({
  job_id: z.string().uuid(),
});

export const authValidateQuerySchema = z.object({});

export async function parseJsonBody<T>(req: Request, schema: z.ZodType<T>): Promise<T> {
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    throw new ValidationError('Request body must be valid JSON');
  }

  const result = schema.safeParse(raw);
  if (!result.success) {
    throw new ValidationError(
      'Request validation failed',
      result.error.issues.map((issue) => ({
        field: issue.path.join('.') || null,
        message: issue.message,
        code: issue.code,
      })),
    );
  }

  return result.data;
}

export { z };
