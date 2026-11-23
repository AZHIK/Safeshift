// Pricing draft model shared by the editor, the server actions and the tests.
//
// The database is the authority (constraints, overlap triggers, published
// immutability). This module mirrors the important rules so the editor can
// show problems before saving, and normalises form values into the exact
// payload public.admin_save_pricing_draft expects.

export type SurchargeType = 'flat_fee' | 'multiplier';
export type CargoSurchargeType = SurchargeType | 'percentage';
export type AppliesTo = 'subtotal' | 'base_fare' | 'distance' | 'time';

export type BaseRates = {
  base_fare: number;
  per_km_rate: number;
  per_min_rate: number;
  minimum_charge: number;
  loading_fee: number;
  unloading_fee: number;
  waiting_per_min_rate: number;
  waiting_free_minutes: number;
  multi_stop_fee: number;
  /** Fraction, e.g. 0.18 for 18 %. */
  vat_rate: number;
};

export type DistanceTier = { min_km: number; max_km: number | null; per_km_rate: number };
export type WeightTier = {
  min_kg: number;
  max_kg: number | null;
  surcharge_type: SurchargeType;
  surcharge_value: number;
};
export type VolumeTier = {
  min_m3: number;
  max_m3: number | null;
  surcharge_type: SurchargeType;
  surcharge_value: number;
};
export type CargoSurcharge = {
  cargo_type_id: string;
  surcharge_type: CargoSurchargeType;
  surcharge_value: number;
};
export type EquipmentSurcharge = {
  equipment_id: string;
  surcharge_type: SurchargeType;
  surcharge_value: number;
};
export type TimeMultiplier = {
  name: string;
  /** 0 = Sunday … 6 = Saturday. */
  days_of_week: number[];
  /** "HH:MM". */
  start_time: string;
  end_time: string;
  timezone: string;
  multiplier: number;
  applies_to: AppliesTo;
  priority: number;
  stacks: boolean;
};
export type ZoneMultiplier = { service_zone_id: string; multiplier: number; reason: string };
export type PlanZone = { service_zone_id: string; is_primary: boolean };

export type PricingDraft = {
  notes: string;
  regulated_tariff_id: string | null;
  base_rates: BaseRates;
  distance_tiers: DistanceTier[];
  weight_tiers: WeightTier[];
  volume_tiers: VolumeTier[];
  cargo_surcharges: CargoSurcharge[];
  equipment_surcharges: EquipmentSurcharge[];
  time_multipliers: TimeMultiplier[];
  zone_multipliers: ZoneMultiplier[];
  zones: PlanZone[];
  vehicle_type_ids: string[];
};

export const EMPTY_BASE_RATES: BaseRates = {
  base_fare: 0,
  per_km_rate: 0,
  per_min_rate: 0,
  minimum_charge: 0,
  loading_fee: 0,
  unloading_fee: 0,
  waiting_per_min_rate: 0,
  waiting_free_minutes: 5,
  multi_stop_fee: 0,
  vat_rate: 0.18,
};

export const DEFAULT_TIMEZONE = 'Africa/Dar_es_Salaam';

// ---------------------------------------------------------------------------
// Rows → draft
// ---------------------------------------------------------------------------

type Row = Record<string, unknown>;

const num = (value: unknown, fallback = 0): number => {
  if (value === null || value === undefined || value === '') return fallback;
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
};
const numOrNull = (value: unknown): number | null =>
  value === null || value === undefined || value === '' ? null : num(value);
const str = (value: unknown): string => (value === null || value === undefined ? '' : String(value));
/** Postgres returns "22:00:00"; the editor uses "22:00". */
const hhmm = (value: unknown): string => str(value).slice(0, 5);

const byOrder = (a: Row, b: Row) => num(a.display_order) - num(b.display_order);

/** Builds editor state from a version row with its nested child rows. */
export function draftFromVersion(version: Row): PricingDraft {
  const rates = ((version.pricing_plan_base_rates as Row[] | undefined) ?? [])[0] ?? {};
  const rows = (key: string) => (version[key] as Row[] | undefined) ?? [];

  return {
    notes: str(version.notes),
    regulated_tariff_id: (version.regulated_tariff_id as string | null) ?? null,
    base_rates: {
      base_fare: num(rates.base_fare),
      per_km_rate: num(rates.per_km_rate),
      per_min_rate: num(rates.per_min_rate),
      minimum_charge: num(rates.minimum_charge),
      loading_fee: num(rates.loading_fee),
      unloading_fee: num(rates.unloading_fee),
      waiting_per_min_rate: num(rates.waiting_per_min_rate),
      waiting_free_minutes: num(rates.waiting_free_minutes, 5),
      multi_stop_fee: num(rates.multi_stop_fee),
      vat_rate: num(rates.vat_rate, 0.18),
    },
    distance_tiers: [...rows('pricing_distance_tiers')].sort(byOrder).map((t) => ({
      min_km: num(t.min_km),
      max_km: numOrNull(t.max_km),
      per_km_rate: num(t.per_km_rate),
    })),
    weight_tiers: [...rows('pricing_weight_tiers')].sort(byOrder).map((t) => ({
      min_kg: num(t.min_kg),
      max_kg: numOrNull(t.max_kg),
      surcharge_type: str(t.surcharge_type) as SurchargeType,
      surcharge_value: num(t.surcharge_value),
    })),
    volume_tiers: [...rows('pricing_volume_tiers')].sort(byOrder).map((t) => ({
      min_m3: num(t.min_m3),
      max_m3: numOrNull(t.max_m3),
      surcharge_type: str(t.surcharge_type) as SurchargeType,
      surcharge_value: num(t.surcharge_value),
    })),
    cargo_surcharges: rows('pricing_cargo_surcharges').map((s) => ({
      cargo_type_id: str(s.cargo_type_id),
      surcharge_type: str(s.surcharge_type) as CargoSurchargeType,
      surcharge_value: num(s.surcharge_value),
    })),
    equipment_surcharges: rows('pricing_equipment_surcharges').map((s) => ({
      equipment_id: str(s.equipment_id),
      surcharge_type: str(s.surcharge_type) as SurchargeType,
      surcharge_value: num(s.surcharge_value),
    })),
    time_multipliers: rows('pricing_time_multipliers').map((m) => ({
      name: str(m.name),
      days_of_week: ((m.days_of_week as number[] | null) ?? []).map(Number),
      start_time: hhmm(m.start_time),
      end_time: hhmm(m.end_time),
      timezone: str(m.timezone) || DEFAULT_TIMEZONE,
      multiplier: num(m.multiplier, 1),
      applies_to: (str(m.applies_to) || 'subtotal') as AppliesTo,
      priority: num(m.priority),
      stacks: Boolean(m.stacks),
    })),
    zone_multipliers: rows('pricing_zone_multipliers').map((z) => ({
      service_zone_id: str(z.service_zone_id),
      multiplier: num(z.multiplier, 1),
      reason: str(z.reason),
    })),
    zones: rows('pricing_plan_zones').map((z) => ({
      service_zone_id: str(z.service_zone_id),
      is_primary: Boolean(z.is_primary),
    })),
    vehicle_type_ids: rows('pricing_plan_vehicle_types').map((v) => str(v.vehicle_type_id)),
  };
}

/** The select string that loads everything draftFromVersion needs. */
export const VERSION_SELECT = [
  'id, pricing_plan_id, version_number, currency_code, effective_from, effective_to,',
  'published_at, published_by, superseded_by_version_id, regulated_tariff_id, notes, created_at,',
  'pricing_plan_base_rates(*), pricing_distance_tiers(*), pricing_weight_tiers(*),',
  'pricing_volume_tiers(*), pricing_cargo_surcharges(*), pricing_equipment_surcharges(*),',
  'pricing_time_multipliers(*), pricing_zone_multipliers(*), pricing_plan_zones(*),',
  'pricing_plan_vehicle_types(*)',
].join(' ');

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

export type DraftIssue = { section: string; message: string };

const isFiniteNumber = (n: unknown): n is number => typeof n === 'number' && Number.isFinite(n);
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

/** Half-open ranges [min, max) with max = null meaning "and above". */
function overlaps(ranges: { min: number; max: number | null }[]): boolean {
  const sorted = [...ranges].sort((a, b) => a.min - b.min);
  for (let i = 1; i < sorted.length; i++) {
    const prev = sorted[i - 1];
    if (prev.max === null || sorted[i].min < prev.max) return true;
  }
  return false;
}

function checkRanges(
  issues: DraftIssue[],
  section: string,
  unit: string,
  ranges: { min: number; max: number | null }[],
) {
  ranges.forEach((r, i) => {
    if (!isFiniteNumber(r.min) || r.min < 0) {
      issues.push({ section, message: `Row ${i + 1}: the start must be 0 ${unit} or more.` });
    }
    if (r.max !== null && (!isFiniteNumber(r.max) || r.max <= r.min)) {
      issues.push({ section, message: `Row ${i + 1}: the end must be greater than the start.` });
    }
  });
  if (overlaps(ranges)) {
    issues.push({ section, message: 'Ranges overlap. Each distance or size may match only one row.' });
  }
}

function checkSurcharge(issues: DraftIssue[], section: string, row: number, type: string, value: number) {
  if (!isFiniteNumber(value) || value < 0) {
    issues.push({ section, message: `Row ${row}: the amount must be 0 or more.` });
  } else if (type === 'multiplier' && value < 1) {
    issues.push({ section, message: `Row ${row}: a multiplier below 1 would reduce the fare.` });
  } else if (type === 'percentage' && value > 100) {
    issues.push({ section, message: `Row ${row}: a percentage cannot exceed 100.` });
  }
}

/** `what` is singular with its article, e.g. "a cargo type". */
function checkUnique(issues: DraftIssue[], section: string, ids: string[], what: string) {
  const noun = what.replace(/^an? /, '');
  if (ids.some((id) => !id)) issues.push({ section, message: `Choose ${what} for every row.` });
  if (new Set(ids.filter(Boolean)).size !== ids.filter(Boolean).length) {
    issues.push({ section, message: `Each ${noun} can appear only once.` });
  }
}

/** Returns every problem in the draft; an empty list means it can be saved. */
export function validateDraft(draft: PricingDraft): DraftIssue[] {
  const issues: DraftIssue[] = [];
  const r = draft.base_rates;

  const money: [keyof BaseRates, string][] = [
    ['base_fare', 'Base fare'],
    ['per_km_rate', 'Per-km rate'],
    ['per_min_rate', 'Per-minute rate'],
    ['minimum_charge', 'Minimum charge'],
    ['loading_fee', 'Loading fee'],
    ['unloading_fee', 'Unloading fee'],
    ['waiting_per_min_rate', 'Waiting rate'],
    ['multi_stop_fee', 'Multi-stop fee'],
  ];
  for (const [key, label] of money) {
    if (!isFiniteNumber(r[key]) || r[key] < 0) {
      issues.push({ section: 'Base rates', message: `${label} must be 0 or more.` });
    }
  }
  if (!Number.isInteger(r.waiting_free_minutes) || r.waiting_free_minutes < 0) {
    issues.push({ section: 'Base rates', message: 'Free waiting minutes must be a whole number, 0 or more.' });
  }
  if (!isFiniteNumber(r.vat_rate) || r.vat_rate < 0 || r.vat_rate > 1) {
    issues.push({ section: 'Base rates', message: 'VAT must be between 0 % and 100 %.' });
  }

  checkRanges(
    issues,
    'Distance tiers',
    'km',
    draft.distance_tiers.map((t) => ({ min: t.min_km, max: t.max_km })),
  );
  draft.distance_tiers.forEach((t, i) => {
    if (!isFiniteNumber(t.per_km_rate) || t.per_km_rate < 0) {
      issues.push({ section: 'Distance tiers', message: `Row ${i + 1}: the per-km rate must be 0 or more.` });
    }
  });

  checkRanges(issues, 'Weight tiers', 'kg', draft.weight_tiers.map((t) => ({ min: t.min_kg, max: t.max_kg })));
  draft.weight_tiers.forEach((t, i) =>
    checkSurcharge(issues, 'Weight tiers', i + 1, t.surcharge_type, t.surcharge_value),
  );

  checkRanges(issues, 'Volume tiers', 'm³', draft.volume_tiers.map((t) => ({ min: t.min_m3, max: t.max_m3 })));
  draft.volume_tiers.forEach((t, i) =>
    checkSurcharge(issues, 'Volume tiers', i + 1, t.surcharge_type, t.surcharge_value),
  );

  checkUnique(issues, 'Cargo surcharges', draft.cargo_surcharges.map((s) => s.cargo_type_id), 'a cargo type');
  draft.cargo_surcharges.forEach((s, i) =>
    checkSurcharge(issues, 'Cargo surcharges', i + 1, s.surcharge_type, s.surcharge_value),
  );

  checkUnique(issues, 'Equipment surcharges', draft.equipment_surcharges.map((s) => s.equipment_id), 'an equipment item');
  draft.equipment_surcharges.forEach((s, i) =>
    checkSurcharge(issues, 'Equipment surcharges', i + 1, s.surcharge_type, s.surcharge_value),
  );

  draft.time_multipliers.forEach((m, i) => {
    const row = `Row ${i + 1}`;
    if (!m.name.trim()) issues.push({ section: 'Time multipliers', message: `${row}: give it a name.` });
    if (m.days_of_week.length === 0) {
      issues.push({ section: 'Time multipliers', message: `${row}: choose at least one day.` });
    }
    if (!TIME_RE.test(m.start_time) || !TIME_RE.test(m.end_time)) {
      issues.push({ section: 'Time multipliers', message: `${row}: enter start and end times.` });
    } else if (m.start_time === m.end_time) {
      issues.push({ section: 'Time multipliers', message: `${row}: start and end cannot be the same.` });
    }
    if (!isFiniteNumber(m.multiplier) || m.multiplier < 1 || m.multiplier > 5) {
      issues.push({ section: 'Time multipliers', message: `${row}: the multiplier must be between 1 and 5.` });
    }
  });

  checkUnique(issues, 'Zone multipliers', draft.zone_multipliers.map((z) => z.service_zone_id), 'a zone');
  draft.zone_multipliers.forEach((z, i) => {
    if (!isFiniteNumber(z.multiplier) || z.multiplier < 1 || z.multiplier > 5) {
      issues.push({ section: 'Zone multipliers', message: `Row ${i + 1}: the multiplier must be between 1 and 5.` });
    }
  });

  checkUnique(issues, 'Service zones', draft.zones.map((z) => z.service_zone_id), 'a zone');
  if (draft.zones.filter((z) => z.is_primary).length > 1) {
    issues.push({ section: 'Service zones', message: 'Only one zone can be primary.' });
  }

  return issues;
}

/** Normalises a draft into the JSON admin_save_pricing_draft expects. */
export function toSavePayload(draft: PricingDraft) {
  return {
    notes: draft.notes.trim(),
    regulated_tariff_id: draft.regulated_tariff_id || null,
    base_rates: { ...draft.base_rates },
    distance_tiers: draft.distance_tiers.map((t) => ({ ...t })),
    weight_tiers: draft.weight_tiers.map((t) => ({ ...t })),
    volume_tiers: draft.volume_tiers.map((t) => ({ ...t })),
    cargo_surcharges: draft.cargo_surcharges.map((s) => ({ ...s })),
    equipment_surcharges: draft.equipment_surcharges.map((s) => ({ ...s })),
    time_multipliers: draft.time_multipliers.map((m) => ({
      ...m,
      name: m.name.trim(),
      days_of_week: [...new Set(m.days_of_week)].sort(),
    })),
    zone_multipliers: draft.zone_multipliers.map((z) => ({ ...z, reason: z.reason.trim() })),
    zones: draft.zones.map((z) => ({ ...z })),
    vehicle_type_ids: [...new Set(draft.vehicle_type_ids)],
  };
}

// ---------------------------------------------------------------------------
// Version status
// ---------------------------------------------------------------------------

export type VersionStatus = 'draft' | 'scheduled' | 'active' | 'superseded';

export type VersionTiming = {
  published_at: string | null;
  effective_from: string;
  effective_to: string | null;
};

/** Where a version stands at `now`. */
export function versionStatus(v: VersionTiming, now: Date = new Date()): VersionStatus {
  if (!v.published_at) return 'draft';
  const t = now.getTime();
  if (new Date(v.effective_from).getTime() > t) return 'scheduled';
  if (v.effective_to && new Date(v.effective_to).getTime() <= t) return 'superseded';
  return 'active';
}

export const VERSION_STATUS_LABEL: Record<VersionStatus, string> = {
  draft: 'Draft',
  scheduled: 'Scheduled',
  active: 'Active',
  superseded: 'Superseded',
};
