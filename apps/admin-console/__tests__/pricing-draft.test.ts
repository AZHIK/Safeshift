import { describe, expect, it } from 'vitest';

import {
  EMPTY_BASE_RATES,
  draftFromVersion,
  toSavePayload,
  validateDraft,
  versionStatus,
  type PricingDraft,
} from '@/lib/pricing/draft';

const ZONE_A = 'aaaaaaaa-0000-4000-8000-00000000000a';
const ZONE_B = 'bbbbbbbb-0000-4000-8000-00000000000b';
const CARGO = 'cccccccc-0000-4000-8000-00000000000c';

function draft(patch: Partial<PricingDraft> = {}): PricingDraft {
  return {
    notes: '',
    regulated_tariff_id: null,
    base_rates: { ...EMPTY_BASE_RATES, base_fare: 2000, per_km_rate: 500, per_min_rate: 40 },
    distance_tiers: [],
    weight_tiers: [],
    volume_tiers: [],
    cargo_surcharges: [],
    equipment_surcharges: [],
    time_multipliers: [],
    zone_multipliers: [],
    zones: [],
    vehicle_type_ids: [],
    ...patch,
  };
}

const messages = (d: PricingDraft) => validateDraft(d).map((i) => `${i.section}: ${i.message}`);

describe('draftFromVersion', () => {
  it('maps database rows, sorts tiers by display order and trims times', () => {
    const result = draftFromVersion({
      notes: 'Fuel',
      regulated_tariff_id: null,
      pricing_plan_base_rates: [
        { base_fare: '2000.00', per_km_rate: '500', per_min_rate: '40', loading_fee: '1500', vat_rate: '0.1800', waiting_free_minutes: 10 },
      ],
      pricing_distance_tiers: [
        { min_km: '10', max_km: null, per_km_rate: '500', display_order: 1 },
        { min_km: '0', max_km: '10', per_km_rate: '700', display_order: 0 },
      ],
      pricing_time_multipliers: [
        { name: 'Night', days_of_week: [0, 6], start_time: '22:00:00', end_time: '05:00:00', multiplier: '1.2500', stacks: false },
      ],
      pricing_plan_vehicle_types: [{ vehicle_type_id: 'v1' }],
    });

    expect(result.base_rates).toMatchObject({ base_fare: 2000, loading_fee: 1500, vat_rate: 0.18, waiting_free_minutes: 10 });
    expect(result.distance_tiers).toEqual([
      { min_km: 0, max_km: 10, per_km_rate: 700 },
      { min_km: 10, max_km: null, per_km_rate: 500 },
    ]);
    expect(result.time_multipliers[0]).toMatchObject({
      start_time: '22:00',
      end_time: '05:00',
      multiplier: 1.25,
      timezone: 'Africa/Dar_es_Salaam',
      applies_to: 'subtotal',
    });
    expect(result.vehicle_type_ids).toEqual(['v1']);
  });

  it('falls back to defaults when a version has no rows yet', () => {
    const result = draftFromVersion({});
    expect(result.base_rates.vat_rate).toBe(0.18);
    expect(result.base_rates.waiting_free_minutes).toBe(5);
    expect(result.distance_tiers).toEqual([]);
  });
});

describe('validateDraft', () => {
  it('accepts a complete, consistent draft', () => {
    expect(
      messages(
        draft({
          distance_tiers: [
            { min_km: 0, max_km: 10, per_km_rate: 700 },
            { min_km: 10, max_km: null, per_km_rate: 500 },
          ],
          time_multipliers: [
            {
              name: 'Night', days_of_week: [0, 1], start_time: '22:00', end_time: '05:00',
              timezone: 'Africa/Dar_es_Salaam', multiplier: 1.25, applies_to: 'subtotal', priority: 0, stacks: false,
            },
          ],
        }),
      ),
    ).toEqual([]);
  });

  it('reports an empty required rate instead of treating it as zero', () => {
    const d = draft();
    d.base_rates.per_km_rate = Number.NaN;
    expect(messages(d)).toContain('Base rates: Per-km rate must be 0 or more.');
  });

  it('rejects VAT outside 0–100 %', () => {
    const d = draft();
    d.base_rates.vat_rate = 1.5;
    expect(messages(d)).toContain('Base rates: VAT must be between 0 % and 100 %.');
  });

  it('detects overlapping tiers, including an open-ended tier followed by another', () => {
    expect(
      messages(draft({ distance_tiers: [{ min_km: 0, max_km: 10, per_km_rate: 1 }, { min_km: 5, max_km: 20, per_km_rate: 1 }] })),
    ).toContain('Distance tiers: Ranges overlap. Each distance or size may match only one row.');
    expect(
      messages(draft({ distance_tiers: [{ min_km: 0, max_km: null, per_km_rate: 1 }, { min_km: 20, max_km: 30, per_km_rate: 1 }] })),
    ).toContain('Distance tiers: Ranges overlap. Each distance or size may match only one row.');
    expect(
      messages(draft({ weight_tiers: [{ min_kg: 100, max_kg: 50, surcharge_type: 'flat_fee', surcharge_value: 1 }] })),
    ).toContain('Weight tiers: Row 1: the end must be greater than the start.');
  });

  it('checks surcharge amounts and multiplier bounds', () => {
    expect(
      messages(draft({ volume_tiers: [{ min_m3: 0, max_m3: null, surcharge_type: 'multiplier', surcharge_value: 0.5 }] })),
    ).toContain('Volume tiers: Row 1: a multiplier below 1 would reduce the fare.');
    expect(
      messages(draft({ cargo_surcharges: [{ cargo_type_id: CARGO, surcharge_type: 'percentage', surcharge_value: 150 }] })),
    ).toContain('Cargo surcharges: Row 1: a percentage cannot exceed 100.');
    expect(
      messages(draft({ zone_multipliers: [{ service_zone_id: ZONE_A, multiplier: 6, reason: '' }] })),
    ).toContain('Zone multipliers: Row 1: the multiplier must be between 1 and 5.');
  });

  it('requires a choice per row and no duplicates', () => {
    expect(
      messages(
        draft({
          cargo_surcharges: [
            { cargo_type_id: CARGO, surcharge_type: 'flat_fee', surcharge_value: 1 },
            { cargo_type_id: CARGO, surcharge_type: 'flat_fee', surcharge_value: 2 },
          ],
        }),
      ),
    ).toContain('Cargo surcharges: Each cargo type can appear only once.');
    expect(
      messages(draft({ equipment_surcharges: [{ equipment_id: '', surcharge_type: 'flat_fee', surcharge_value: 1 }] })),
    ).toContain('Equipment surcharges: Choose an equipment item for every row.');
  });

  it('validates time windows', () => {
    const base = {
      timezone: 'Africa/Dar_es_Salaam', multiplier: 1.2, applies_to: 'subtotal' as const, priority: 0, stacks: false,
    };
    const result = messages(
      draft({
        time_multipliers: [
          { ...base, name: '', days_of_week: [], start_time: '08:00', end_time: '08:00' },
          { ...base, name: 'Bad', days_of_week: [1], start_time: '25:00', end_time: '09:00', multiplier: 9 },
        ],
      }),
    );
    expect(result).toEqual(
      expect.arrayContaining([
        'Time multipliers: Row 1: give it a name.',
        'Time multipliers: Row 1: choose at least one day.',
        'Time multipliers: Row 1: start and end cannot be the same.',
        'Time multipliers: Row 2: enter start and end times.',
        'Time multipliers: Row 2: the multiplier must be between 1 and 5.',
      ]),
    );
  });

  it('allows only one primary service zone', () => {
    expect(
      messages(
        draft({
          zones: [
            { service_zone_id: ZONE_A, is_primary: true },
            { service_zone_id: ZONE_B, is_primary: true },
          ],
        }),
      ),
    ).toContain('Service zones: Only one zone can be primary.');
  });
});

describe('toSavePayload', () => {
  it('trims text, sorts and de-duplicates days and vehicle types', () => {
    const payload = toSavePayload(
      draft({
        notes: '  Fuel increase  ',
        regulated_tariff_id: '',
        vehicle_type_ids: ['v1', 'v1', 'v2'],
        time_multipliers: [
          {
            name: ' Night ', days_of_week: [6, 0, 6], start_time: '22:00', end_time: '05:00',
            timezone: 'Africa/Dar_es_Salaam', multiplier: 1.25, applies_to: 'subtotal', priority: 0, stacks: false,
          },
        ],
        zone_multipliers: [{ service_zone_id: ZONE_A, multiplier: 1.1, reason: '  CBD ' }],
      }),
    );
    expect(payload.notes).toBe('Fuel increase');
    expect(payload.regulated_tariff_id).toBeNull();
    expect(payload.vehicle_type_ids).toEqual(['v1', 'v2']);
    expect(payload.time_multipliers[0]).toMatchObject({ name: 'Night', days_of_week: [0, 6] });
    expect(payload.zone_multipliers[0].reason).toBe('CBD');
  });
});

describe('versionStatus', () => {
  const now = new Date('2026-11-23T12:00:00Z');
  it('classifies drafts, scheduled, active and superseded versions', () => {
    expect(versionStatus({ published_at: null, effective_from: '2026-11-01T00:00:00Z', effective_to: null }, now)).toBe('draft');
    expect(
      versionStatus({ published_at: '2026-11-20T00:00:00Z', effective_from: '2026-11-24T00:00:00Z', effective_to: null }, now),
    ).toBe('scheduled');
    expect(
      versionStatus({ published_at: '2026-11-01T00:00:00Z', effective_from: '2026-11-01T00:00:00Z', effective_to: null }, now),
    ).toBe('active');
    expect(
      versionStatus(
        { published_at: '2026-11-01T00:00:00Z', effective_from: '2026-11-01T00:00:00Z', effective_to: '2026-11-23T11:00:00Z' },
        now,
      ),
    ).toBe('superseded');
    // A version replaced by a scheduled one stays active until the switch.
    expect(
      versionStatus(
        { published_at: '2026-11-01T00:00:00Z', effective_from: '2026-11-01T00:00:00Z', effective_to: '2026-11-24T00:00:00Z' },
        now,
      ),
    ).toBe('active');
  });
});
