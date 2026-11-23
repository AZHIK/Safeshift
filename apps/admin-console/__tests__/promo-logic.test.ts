import { describe, expect, it } from 'vitest';

import {
  describeDiscount,
  formFromPromo,
  promoStatus,
  toSaveArgs,
  validatePromo,
  type PromoForm,
} from '@/lib/promos/promo';

const ZONE = 'aaaaaaaa-0000-4000-8000-00000000000a';

function form(patch: Partial<PromoForm> = {}): PromoForm {
  return {
    code: 'karibu20',
    name: 'Launch',
    description: '',
    country_id: '',
    discount_type: 'percentage',
    discount_value: 20,
    max_discount_amount: null,
    min_purchase_amount: 0,
    currency_code: 'TZS',
    valid_from: '2026-12-01T00:00:00.000Z',
    valid_to: '2026-12-31T00:00:00.000Z',
    total_redemption_limit: null,
    per_user_redemption_limit: 1,
    new_users_only: false,
    applicable_vehicle_type_ids: [],
    applicable_city_ids: [],
    applicable_cargo_type_ids: [],
    is_active: true,
    rules: [],
    ...patch,
  };
}

describe('validatePromo', () => {
  it('accepts a valid promo (code is normalised, not rejected, for case)', () => {
    expect(validatePromo(form())).toEqual([]);
  });

  it('enforces the database code format', () => {
    expect(validatePromo(form({ code: 'ab' }))[0]).toMatch(/^Code:/);
    expect(validatePromo(form({ code: '-STARTS-WITH-DASH' }))[0]).toMatch(/^Code:/);
    expect(validatePromo(form({ code: 'HAS SPACE' }))[0]).toMatch(/^Code:/);
  });

  it('checks discount values per type', () => {
    expect(validatePromo(form({ discount_value: 120 }))).toContain('A percentage discount cannot exceed 100.');
    expect(validatePromo(form({ discount_value: 0 }))).toContain('Discount must be more than 0.');
    expect(validatePromo(form({ discount_type: 'capped_percentage', max_discount_amount: null }))).toContain(
      'Set the maximum discount for a capped percentage.',
    );
    expect(validatePromo(form({ discount_type: 'flat_amount', discount_value: 5000, currency_code: '' }))).toContain(
      'A fixed-amount discount needs a currency.',
    );
    // A free ride ignores the value entirely.
    expect(validatePromo(form({ discount_type: 'free_ride', discount_value: Number.NaN }))).toEqual([]);
  });

  it('checks the validity window and limits', () => {
    expect(validatePromo(form({ valid_to: '2026-11-01T00:00:00.000Z' }))).toContain('The promo must end after it starts.');
    expect(validatePromo(form({ valid_from: '' }))).toContain('Set both the start and end of the validity window.');
    expect(validatePromo(form({ total_redemption_limit: 0 }))).toContain(
      'Total uses must be a whole number of 1 or more, or empty for unlimited.',
    );
    expect(validatePromo(form({ total_redemption_limit: 2, per_user_redemption_limit: 3 }))).toContain(
      'Uses per customer cannot exceed total uses.',
    );
  });

  it('checks each eligibility rule and rejects duplicates', () => {
    const errors = validatePromo(
      form({
        rules: [
          { rule_type: 'min_jobs_completed', value: '0', description: '' },
          { rule_type: 'specific_zone', value: '', description: '' },
          { rule_type: 'specific_day_of_week', value: '', description: '' },
          { rule_type: 'first_job', value: '', description: '' },
          { rule_type: 'first_job', value: '', description: '' },
        ],
      }),
    );
    expect(errors).toEqual(
      expect.arrayContaining([
        'Rule 1: enter a whole number of 1 or more.',
        'Rule 2: choose a service zone.',
        'Rule 3: choose a day.',
        'Rule 5: duplicate rule.',
      ]),
    );
  });
});

describe('toSaveArgs', () => {
  it('normalises the promo and maps rules to the keys the quote engine reads', () => {
    const { promo, rules } = toSaveArgs(
      form({
        code: ' karibu20 ',
        discount_type: 'free_ride',
        discount_value: 7,
        max_discount_amount: 999,
        currency_code: 'tzs',
        valid_from: '2026-12-01T03:00:00+03:00',
        applicable_city_ids: ['c1', 'c1'],
        rules: [
          { rule_type: 'min_jobs_completed', value: '3', description: ' loyal ' },
          { rule_type: 'min_account_age_days', value: '7', description: '' },
          { rule_type: 'specific_zone', value: ZONE, description: '' },
          { rule_type: 'specific_day_of_week', value: '5', description: '' },
          { rule_type: 'first_job', value: 'ignored', description: '' },
        ],
      }),
    );
    expect(promo).toMatchObject({
      code: 'KARIBU20',
      discount_value: 100,
      max_discount_amount: null,
      currency_code: 'TZS',
      valid_from: '2026-12-01T00:00:00.000Z',
      applicable_city_ids: ['c1'],
      country_id: null,
    });
    expect(rules).toEqual([
      { rule_type: 'min_jobs_completed', rule_value: { min_jobs: 3 }, description: 'loyal' },
      { rule_type: 'min_account_age_days', rule_value: { min_days: 7 }, description: '' },
      { rule_type: 'specific_zone', rule_value: { zone_id: ZONE }, description: '' },
      { rule_type: 'specific_day_of_week', rule_value: { day_of_week: 5 }, description: '' },
      { rule_type: 'first_job', rule_value: {}, description: '' },
    ]);
  });
});

describe('formFromPromo', () => {
  it('reads a database row, including legacy service_zone_id rule values', () => {
    const f = formFromPromo({
      code: 'KARIBU20',
      name: 'Launch',
      discount_type: 'capped_percentage',
      discount_value: '20.0000',
      max_discount_amount: '5000.00',
      currency_code: 'TZS',
      valid_from: '2026-12-01T00:00:00+00',
      valid_to: '2026-12-31T00:00:00+00',
      total_redemption_limit: null,
      per_user_redemption_limit: 2,
      promo_code_eligibility_rules: [
        { rule_type: 'specific_zone', rule_value: { service_zone_id: ZONE }, description: null },
        { rule_type: 'specific_day_of_week', rule_value: { day_of_week: 0 }, description: null },
      ],
    });
    expect(f).toMatchObject({ discount_value: 20, max_discount_amount: 5000, per_user_redemption_limit: 2 });
    expect(f.rules).toEqual([
      { rule_type: 'specific_zone', value: ZONE, description: '' },
      { rule_type: 'specific_day_of_week', value: '0', description: '' },
    ]);
  });
});

describe('promoStatus and describeDiscount', () => {
  const now = new Date('2026-12-10T00:00:00Z');
  const base = { is_active: true, valid_from: '2026-12-01T00:00:00Z', valid_to: '2026-12-31T00:00:00Z', total_redemption_limit: 10 };

  it('classifies promos', () => {
    expect(promoStatus(base, 3, now)).toBe('live');
    expect(promoStatus({ ...base, is_active: false }, 3, now)).toBe('inactive');
    expect(promoStatus({ ...base, valid_from: '2026-12-20T00:00:00Z' }, 0, now)).toBe('scheduled');
    expect(promoStatus({ ...base, valid_to: '2026-12-05T00:00:00Z' }, 3, now)).toBe('expired');
    expect(promoStatus(base, 10, now)).toBe('used_up');
  });

  it('describes each discount type', () => {
    const money = (v: number, c?: string) => `${c ?? '?'} ${v}`;
    const p = { discount_value: 20, max_discount_amount: 5000, currency_code: 'TZS ' };
    expect(describeDiscount({ ...p, discount_type: 'percentage' }, money)).toBe('20 % off');
    expect(describeDiscount({ ...p, discount_type: 'capped_percentage' }, money)).toBe('20 % off, max TZS 5000');
    expect(describeDiscount({ ...p, discount_type: 'flat_amount', discount_value: 3000 }, money)).toBe('TZS 3000 off');
    expect(describeDiscount({ ...p, discount_type: 'free_ride' }, money)).toBe('Free ride');
  });
});
