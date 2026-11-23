// Promo model shared by the promo form, the server actions and the tests.
// Mirrors the promo_codes constraints and the quote engine's discount rules
// (quote_calculate_and_persist) so problems show before saving.

export type DiscountType = 'flat_amount' | 'percentage' | 'capped_percentage' | 'free_ride';

export type RuleType =
  | 'first_job'
  | 'min_jobs_completed'
  | 'min_account_age_days'
  | 'specific_zone'
  | 'specific_day_of_week';

export type PromoRule = {
  rule_type: RuleType;
  /** min_jobs / min_days / day_of_week as a number, or a zone id. */
  value: string;
  description: string;
};

export type PromoForm = {
  code: string;
  name: string;
  description: string;
  country_id: string;
  discount_type: DiscountType;
  discount_value: number;
  max_discount_amount: number | null;
  min_purchase_amount: number;
  currency_code: string;
  /** ISO timestamps. */
  valid_from: string;
  valid_to: string;
  total_redemption_limit: number | null;
  per_user_redemption_limit: number;
  new_users_only: boolean;
  applicable_vehicle_type_ids: string[];
  applicable_city_ids: string[];
  applicable_cargo_type_ids: string[];
  is_active: boolean;
  rules: PromoRule[];
};

export const DISCOUNT_TYPES: { value: DiscountType; label: string; help: string }[] = [
  { value: 'percentage', label: 'Percentage', help: 'A share of the fare before VAT, with no cap.' },
  { value: 'capped_percentage', label: 'Percentage up to a cap', help: 'A share of the fare, never more than the cap.' },
  { value: 'flat_amount', label: 'Fixed amount', help: 'A fixed amount off, never more than the fare.' },
  { value: 'free_ride', label: 'Free ride', help: 'The whole fare before VAT is discounted.' },
];

export const RULE_TYPES: { value: RuleType; label: string; input: 'none' | 'number' | 'zone' | 'day' }[] = [
  { value: 'first_job', label: "Customer's first booking", input: 'none' },
  { value: 'min_jobs_completed', label: 'At least N completed bookings', input: 'number' },
  { value: 'min_account_age_days', label: 'Account at least N days old', input: 'number' },
  { value: 'specific_zone', label: 'Pickup in a service zone', input: 'zone' },
  { value: 'specific_day_of_week', label: 'Only on a day of the week', input: 'day' },
];

export const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

const CODE_RE = /^[A-Z0-9][A-Z0-9_-]{2,31}$/;

export function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}

const finite = (n: unknown): n is number => typeof n === 'number' && Number.isFinite(n);

/** Every problem in the form; an empty list means it can be saved. */
export function validatePromo(form: PromoForm): string[] {
  const errors: string[] = [];
  const code = normalizeCode(form.code);
  if (!CODE_RE.test(code)) {
    errors.push('Code: 3–32 characters, letters, digits, “-” or “_”, starting with a letter or digit.');
  }
  if (!form.name.trim()) errors.push('Name is required.');

  if (form.discount_type !== 'free_ride') {
    if (!finite(form.discount_value) || form.discount_value <= 0) {
      errors.push('Discount must be more than 0.');
    } else if (form.discount_type !== 'flat_amount' && form.discount_value > 100) {
      errors.push('A percentage discount cannot exceed 100.');
    }
  }
  if (form.discount_type === 'capped_percentage') {
    if (!finite(form.max_discount_amount) || form.max_discount_amount <= 0) {
      errors.push('Set the maximum discount for a capped percentage.');
    }
  }
  if (form.discount_type === 'flat_amount' && !form.currency_code.trim()) {
    errors.push('A fixed-amount discount needs a currency.');
  }
  if (!finite(form.min_purchase_amount) || form.min_purchase_amount < 0) {
    errors.push('Minimum fare must be 0 or more.');
  }

  const from = Date.parse(form.valid_from);
  const to = Date.parse(form.valid_to);
  if (Number.isNaN(from) || Number.isNaN(to)) errors.push('Set both the start and end of the validity window.');
  else if (to <= from) errors.push('The promo must end after it starts.');

  if (form.total_redemption_limit !== null && (!Number.isInteger(form.total_redemption_limit) || form.total_redemption_limit < 1)) {
    errors.push('Total uses must be a whole number of 1 or more, or empty for unlimited.');
  }
  if (!Number.isInteger(form.per_user_redemption_limit) || form.per_user_redemption_limit < 1) {
    errors.push('Uses per customer must be a whole number of 1 or more.');
  }
  if (
    form.total_redemption_limit !== null &&
    Number.isInteger(form.total_redemption_limit) &&
    form.per_user_redemption_limit > form.total_redemption_limit
  ) {
    errors.push('Uses per customer cannot exceed total uses.');
  }

  const seen = new Set<string>();
  form.rules.forEach((rule, i) => {
    const row = `Rule ${i + 1}`;
    const kind = RULE_TYPES.find((r) => r.value === rule.rule_type);
    if (!kind) {
      errors.push(`${row}: unknown rule.`);
      return;
    }
    const key = `${rule.rule_type}:${kind.input === 'zone' || kind.input === 'day' ? rule.value : ''}`;
    if (seen.has(key)) errors.push(`${row}: duplicate rule.`);
    seen.add(key);
    if (kind.input === 'number') {
      const n = Number(rule.value);
      if (!Number.isInteger(n) || n < 1) errors.push(`${row}: enter a whole number of 1 or more.`);
    } else if (kind.input === 'zone' && !rule.value) {
      errors.push(`${row}: choose a service zone.`);
    } else if (kind.input === 'day') {
      const n = Number(rule.value);
      if (rule.value === '' || !Number.isInteger(n) || n < 0 || n > 6) errors.push(`${row}: choose a day.`);
    }
  });

  return errors;
}

/** The two JSON arguments of public.admin_save_promo. */
export function toSaveArgs(form: PromoForm) {
  const promo = {
    code: normalizeCode(form.code),
    name: form.name.trim(),
    description: form.description.trim(),
    country_id: form.country_id || null,
    discount_type: form.discount_type,
    discount_value: form.discount_type === 'free_ride' ? 100 : form.discount_value,
    max_discount_amount: form.discount_type === 'capped_percentage' ? form.max_discount_amount : null,
    min_purchase_amount: form.min_purchase_amount,
    currency_code: form.currency_code.trim().toUpperCase() || null,
    valid_from: new Date(form.valid_from).toISOString(),
    valid_to: new Date(form.valid_to).toISOString(),
    total_redemption_limit: form.total_redemption_limit,
    per_user_redemption_limit: form.per_user_redemption_limit,
    new_users_only: form.new_users_only,
    applicable_vehicle_type_ids: [...new Set(form.applicable_vehicle_type_ids)],
    applicable_city_ids: [...new Set(form.applicable_city_ids)],
    applicable_cargo_type_ids: [...new Set(form.applicable_cargo_type_ids)],
    is_active: form.is_active,
  };
  const rules = form.rules.map((rule) => {
    const input = RULE_TYPES.find((r) => r.value === rule.rule_type)?.input;
    const value =
      rule.rule_type === 'min_jobs_completed'
        ? { min_jobs: Number(rule.value) }
        : rule.rule_type === 'min_account_age_days'
          ? { min_days: Number(rule.value) }
          : rule.rule_type === 'specific_zone'
            ? { zone_id: rule.value }
            : rule.rule_type === 'specific_day_of_week'
              ? { day_of_week: Number(rule.value) }
              : {};
    return { rule_type: rule.rule_type, rule_value: input === 'none' ? {} : value, description: rule.description.trim() };
  });
  return { promo, rules };
}

type Row = Record<string, unknown>;

/** Builds form state from a promo_codes row with its eligibility rules. */
export function formFromPromo(row: Row): PromoForm {
  const rules = ((row.promo_code_eligibility_rules as Row[] | undefined) ?? []).map((r) => {
    const value = (r.rule_value as Row | null) ?? {};
    const raw =
      value.min_jobs ?? value.min_days ?? value.zone_id ?? value.service_zone_id ?? value.day_of_week ?? '';
    return {
      rule_type: String(r.rule_type) as RuleType,
      value: String(raw),
      description: String(r.description ?? ''),
    };
  });
  const num = (v: unknown, fallback = 0) => (v === null || v === undefined || v === '' ? fallback : Number(v));
  return {
    code: String(row.code ?? ''),
    name: String(row.name ?? ''),
    description: String(row.description ?? ''),
    country_id: String(row.country_id ?? ''),
    discount_type: String(row.discount_type ?? 'percentage') as DiscountType,
    discount_value: num(row.discount_value),
    max_discount_amount: row.max_discount_amount === null || row.max_discount_amount === undefined ? null : Number(row.max_discount_amount),
    min_purchase_amount: num(row.min_purchase_amount),
    currency_code: String(row.currency_code ?? '').trim(),
    valid_from: String(row.valid_from ?? ''),
    valid_to: String(row.valid_to ?? ''),
    total_redemption_limit:
      row.total_redemption_limit === null || row.total_redemption_limit === undefined ? null : Number(row.total_redemption_limit),
    per_user_redemption_limit: num(row.per_user_redemption_limit, 1),
    new_users_only: Boolean(row.new_users_only),
    applicable_vehicle_type_ids: ((row.applicable_vehicle_type_ids as string[] | null) ?? []).map(String),
    applicable_city_ids: ((row.applicable_city_ids as string[] | null) ?? []).map(String),
    applicable_cargo_type_ids: ((row.applicable_cargo_type_ids as string[] | null) ?? []).map(String),
    is_active: row.is_active === undefined ? true : Boolean(row.is_active),
    rules,
  };
}

export type PromoStatus = 'inactive' | 'scheduled' | 'live' | 'expired' | 'used_up';

export function promoStatus(
  p: { is_active: boolean; valid_from: string; valid_to: string; total_redemption_limit: number | null },
  redemptions: number,
  now: Date = new Date(),
): PromoStatus {
  if (!p.is_active) return 'inactive';
  const t = now.getTime();
  if (Date.parse(p.valid_to) <= t) return 'expired';
  if (p.total_redemption_limit !== null && redemptions >= p.total_redemption_limit) return 'used_up';
  if (Date.parse(p.valid_from) > t) return 'scheduled';
  return 'live';
}

export const PROMO_STATUS: Record<PromoStatus, { label: string; tone: string }> = {
  live: { label: 'Live', tone: 'green' },
  scheduled: { label: 'Scheduled', tone: 'violet' },
  inactive: { label: 'Paused', tone: 'gray' },
  expired: { label: 'Expired', tone: 'gray' },
  used_up: { label: 'Used up', tone: 'amber' },
};

/** "20 % off (max TZS 5,000)" etc. */
export function describeDiscount(
  p: { discount_type: string; discount_value: number; max_discount_amount: number | null; currency_code: string | null },
  formatMoney: (value: number, currency?: string) => string,
): string {
  const currency = p.currency_code?.trim() || undefined;
  switch (p.discount_type) {
    case 'flat_amount':
      return `${formatMoney(p.discount_value, currency)} off`;
    case 'percentage':
      return `${Number(p.discount_value)} % off`;
    case 'capped_percentage':
      return `${Number(p.discount_value)} % off, max ${formatMoney(Number(p.max_discount_amount ?? 0), currency)}`;
    case 'free_ride':
      return 'Free ride';
    default:
      return p.discount_type;
  }
}
