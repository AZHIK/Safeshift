'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState, useTransition, type ReactNode } from 'react';

import {
  DEFAULT_TIMEZONE,
  validateDraft,
  type AppliesTo,
  type BaseRates,
  type CargoSurchargeType,
  type PricingDraft,
  type SurchargeType,
} from '@/lib/pricing/draft';

import { saveDraftAction } from '../../../actions';

export type Option = { id: string; name: string };

export type EditorLookups = {
  cargoTypes: Option[];
  equipment: Option[];
  zones: Option[];
  vehicleTypes: Option[];
  tariffs: Option[];
};

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const SURCHARGE_TYPES: { value: SurchargeType; label: string }[] = [
  { value: 'flat_fee', label: 'Flat fee' },
  { value: 'multiplier', label: 'Multiplier' },
];
const CARGO_SURCHARGE_TYPES: { value: CargoSurchargeType; label: string }[] = [
  ...SURCHARGE_TYPES,
  { value: 'percentage', label: 'Percentage' },
];
const APPLIES_TO: { value: AppliesTo; label: string }[] = [
  { value: 'subtotal', label: 'Whole fare' },
  { value: 'base_fare', label: 'Base fare' },
  { value: 'distance', label: 'Distance charge' },
  { value: 'time', label: 'Time charge' },
];

/** Empty input → NaN, so validation reports it instead of silently using 0. */
const parseRequired = (raw: string) => (raw.trim() === '' ? Number.NaN : Number(raw));
const parseOptional = (raw: string) => (raw.trim() === '' ? null : Number(raw));
const show = (n: number | null) => (n === null || Number.isNaN(n) ? '' : String(n));

export function DraftEditor({
  versionId,
  initial,
  readOnly,
  currency,
  lookups,
  onDirtyChange,
}: {
  versionId: string;
  initial: PricingDraft;
  readOnly: boolean;
  currency: string;
  lookups: EditorLookups;
  onDirtyChange?: (dirty: boolean) => void;
}) {
  const router = useRouter();
  const [draft, setDraft] = useState<PricingDraft>(initial);
  const [saved, setSaved] = useState<PricingDraft>(initial);
  const [pending, startTransition] = useTransition();
  const [serverErrors, setServerErrors] = useState<string[]>([]);
  const [savedAt, setSavedAt] = useState<Date | null>(null);

  const issues = useMemo(() => validateDraft(draft), [draft]);
  const dirty = useMemo(() => JSON.stringify(draft) !== JSON.stringify(saved), [draft, saved]);

  useEffect(() => onDirtyChange?.(dirty), [dirty, onDirtyChange]);

  // Warn before leaving with unsaved edits.
  useEffect(() => {
    if (!dirty || readOnly) return;
    const handler = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, [dirty, readOnly]);

  const update = (patch: Partial<PricingDraft>) => setDraft((d) => ({ ...d, ...patch }));
  const setRate = (key: keyof BaseRates, value: number) =>
    setDraft((d) => ({ ...d, base_rates: { ...d.base_rates, [key]: value } }));

  function save() {
    setServerErrors([]);
    startTransition(async () => {
      const result = await saveDraftAction(versionId, draft);
      if (result.ok) {
        setSaved(draft);
        setSavedAt(new Date());
        router.refresh();
      } else {
        setServerErrors(result.errors);
      }
    });
  }

  const money = (key: keyof BaseRates, label: string, hint?: string) => (
    <label className="field" key={key}>
      {label}
      <input
        className="input"
        type="number"
        min="0"
        step="0.01"
        disabled={readOnly}
        value={show(draft.base_rates[key])}
        onChange={(e) => setRate(key, parseRequired(e.target.value))}
        aria-describedby={hint ? `${key}-hint` : undefined}
      />
      {hint ? (
        <span className="small muted" id={`${key}-hint`}>
          {hint}
        </span>
      ) : null}
    </label>
  );

  return (
    <div className="section-stack">
      <Section title="Base rates" sub={`All amounts in ${currency}. VAT is added on top of the subtotal.`}>
        <div className="form-grid">
          {money('base_fare', 'Base fare')}
          {money('per_km_rate', 'Per km', 'Used beyond the last distance tier')}
          {money('per_min_rate', 'Per minute')}
          {money('minimum_charge', 'Minimum charge')}
          {money('loading_fee', 'Loading fee')}
          {money('unloading_fee', 'Unloading fee')}
          {money('waiting_per_min_rate', 'Waiting, per minute')}
          <label className="field">
            Free waiting minutes
            <input
              className="input"
              type="number"
              min="0"
              step="1"
              disabled={readOnly}
              value={show(draft.base_rates.waiting_free_minutes)}
              onChange={(e) => setRate('waiting_free_minutes', parseRequired(e.target.value))}
            />
          </label>
          {money('multi_stop_fee', 'Fee per extra stop')}
          <label className="field">
            VAT %
            <input
              className="input"
              type="number"
              min="0"
              max="100"
              step="0.01"
              disabled={readOnly}
              value={show(Number.isNaN(draft.base_rates.vat_rate) ? Number.NaN : round(draft.base_rates.vat_rate * 100))}
              onChange={(e) => setRate('vat_rate', parseRequired(e.target.value) / 100)}
            />
          </label>
        </div>
      </Section>

      <Section
        title="Distance tiers"
        sub="Per-km rate by distance band. Leave “To” empty on the last tier for “and above”."
        onAdd={
          readOnly
            ? undefined
            : () => {
                const last = draft.distance_tiers.at(-1);
                update({
                  distance_tiers: [
                    ...draft.distance_tiers,
                    { min_km: last?.max_km ?? 0, max_km: null, per_km_rate: draft.base_rates.per_km_rate },
                  ],
                });
              }
        }
        empty={draft.distance_tiers.length === 0 ? 'No tiers: the base per-km rate applies to the whole trip.' : null}
      >
        {draft.distance_tiers.map((t, i) => (
          <Row
            key={i}
            readOnly={readOnly}
            onRemove={() => update({ distance_tiers: draft.distance_tiers.filter((_, j) => j !== i) })}
          >
            <NumberCell label="From km" value={t.min_km} readOnly={readOnly}
              onChange={(v) => update({ distance_tiers: replace(draft.distance_tiers, i, { ...t, min_km: v }) })} />
            <OptionalNumberCell label="To km" value={t.max_km} readOnly={readOnly}
              onChange={(v) => update({ distance_tiers: replace(draft.distance_tiers, i, { ...t, max_km: v }) })} />
            <NumberCell label="Per km" value={t.per_km_rate} readOnly={readOnly}
              onChange={(v) => update({ distance_tiers: replace(draft.distance_tiers, i, { ...t, per_km_rate: v }) })} />
          </Row>
        ))}
      </Section>

      {(['weight', 'volume'] as const).map((kind) => {
        const key = kind === 'weight' ? 'weight_tiers' : 'volume_tiers';
        const unit = kind === 'weight' ? 'kg' : 'm³';
        const minKey = kind === 'weight' ? 'min_kg' : 'min_m3';
        const maxKey = kind === 'weight' ? 'max_kg' : 'max_m3';
        const rows = draft[key] as Record<string, unknown>[];
        const set = (next: Record<string, unknown>[]) => update({ [key]: next } as Partial<PricingDraft>);
        return (
          <Section
            key={kind}
            title={kind === 'weight' ? 'Weight tiers' : 'Volume tiers'}
            sub={`Surcharge by ${kind} (${unit}). A flat fee adds an amount; a multiplier scales the fare.`}
            onAdd={
              readOnly
                ? undefined
                : () => {
                    const last = rows.at(-1);
                    set([
                      ...rows,
                      { [minKey]: (last?.[maxKey] as number | null) ?? 0, [maxKey]: null, surcharge_type: 'flat_fee', surcharge_value: 0 },
                    ]);
                  }
            }
            empty={rows.length === 0 ? `No ${kind} surcharges.` : null}
          >
            {rows.map((t, i) => (
              <Row key={i} readOnly={readOnly} onRemove={() => set(rows.filter((_, j) => j !== i))}>
                <NumberCell label={`From ${unit}`} value={t[minKey] as number} readOnly={readOnly}
                  onChange={(v) => set(replace(rows, i, { ...t, [minKey]: v }))} />
                <OptionalNumberCell label={`To ${unit}`} value={t[maxKey] as number | null} readOnly={readOnly}
                  onChange={(v) => set(replace(rows, i, { ...t, [maxKey]: v }))} />
                <SelectCell label="Type" value={t.surcharge_type as string} options={SURCHARGE_TYPES} readOnly={readOnly}
                  onChange={(v) => set(replace(rows, i, { ...t, surcharge_type: v }))} />
                <NumberCell label="Amount" value={t.surcharge_value as number} readOnly={readOnly} step="0.0001"
                  onChange={(v) => set(replace(rows, i, { ...t, surcharge_value: v }))} />
              </Row>
            ))}
          </Section>
        );
      })}

      <Section
        title="Cargo surcharges"
        sub="Extra charge for specific cargo types."
        onAdd={
          readOnly || lookups.cargoTypes.length === 0
            ? undefined
            : () =>
                update({
                  cargo_surcharges: [
                    ...draft.cargo_surcharges,
                    { cargo_type_id: '', surcharge_type: 'flat_fee', surcharge_value: 0 },
                  ],
                })
        }
        empty={draft.cargo_surcharges.length === 0 ? 'No cargo surcharges.' : null}
      >
        {draft.cargo_surcharges.map((s, i) => (
          <Row key={i} readOnly={readOnly}
            onRemove={() => update({ cargo_surcharges: draft.cargo_surcharges.filter((_, j) => j !== i) })}>
            <SelectCell label="Cargo type" value={s.cargo_type_id} readOnly={readOnly} placeholder="Choose…"
              options={lookups.cargoTypes.map((o) => ({ value: o.id, label: o.name }))}
              onChange={(v) => update({ cargo_surcharges: replace(draft.cargo_surcharges, i, { ...s, cargo_type_id: v }) })} />
            <SelectCell label="Type" value={s.surcharge_type} options={CARGO_SURCHARGE_TYPES} readOnly={readOnly}
              onChange={(v) => update({ cargo_surcharges: replace(draft.cargo_surcharges, i, { ...s, surcharge_type: v as CargoSurchargeType }) })} />
            <NumberCell label="Amount" value={s.surcharge_value} readOnly={readOnly} step="0.0001"
              onChange={(v) => update({ cargo_surcharges: replace(draft.cargo_surcharges, i, { ...s, surcharge_value: v }) })} />
          </Row>
        ))}
      </Section>

      <Section
        title="Equipment surcharges"
        sub="Extra charge when the booking needs equipment (straps, dolly, crane…)."
        onAdd={
          readOnly || lookups.equipment.length === 0
            ? undefined
            : () =>
                update({
                  equipment_surcharges: [
                    ...draft.equipment_surcharges,
                    { equipment_id: '', surcharge_type: 'flat_fee', surcharge_value: 0 },
                  ],
                })
        }
        empty={draft.equipment_surcharges.length === 0 ? 'No equipment surcharges.' : null}
      >
        {draft.equipment_surcharges.map((s, i) => (
          <Row key={i} readOnly={readOnly}
            onRemove={() => update({ equipment_surcharges: draft.equipment_surcharges.filter((_, j) => j !== i) })}>
            <SelectCell label="Equipment" value={s.equipment_id} readOnly={readOnly} placeholder="Choose…"
              options={lookups.equipment.map((o) => ({ value: o.id, label: o.name }))}
              onChange={(v) => update({ equipment_surcharges: replace(draft.equipment_surcharges, i, { ...s, equipment_id: v }) })} />
            <SelectCell label="Type" value={s.surcharge_type} options={SURCHARGE_TYPES} readOnly={readOnly}
              onChange={(v) => update({ equipment_surcharges: replace(draft.equipment_surcharges, i, { ...s, surcharge_type: v as SurchargeType }) })} />
            <NumberCell label="Amount" value={s.surcharge_value} readOnly={readOnly} step="0.0001"
              onChange={(v) => update({ equipment_surcharges: replace(draft.equipment_surcharges, i, { ...s, surcharge_value: v }) })} />
          </Row>
        ))}
      </Section>

      <Section
        title="Time multipliers"
        sub="Peak, night or weekend pricing. Windows may cross midnight (e.g. 22:00–05:00). Non-stacking windows may not overlap."
        onAdd={
          readOnly
            ? undefined
            : () =>
                update({
                  time_multipliers: [
                    ...draft.time_multipliers,
                    {
                      name: '',
                      days_of_week: [1, 2, 3, 4, 5],
                      start_time: '07:00',
                      end_time: '09:00',
                      timezone: DEFAULT_TIMEZONE,
                      multiplier: 1.2,
                      applies_to: 'subtotal',
                      priority: 0,
                      stacks: false,
                    },
                  ],
                })
        }
        empty={draft.time_multipliers.length === 0 ? 'No time-based pricing.' : null}
      >
        {draft.time_multipliers.map((m, i) => {
          const set = (patch: Partial<typeof m>) =>
            update({ time_multipliers: replace(draft.time_multipliers, i, { ...m, ...patch }) });
          return (
            <div key={i} className="card card-pad" style={{ marginBottom: 8 }}>
              <div className="form-grid">
                <label className="field">
                  Name
                  <input className="input" disabled={readOnly} value={m.name} placeholder="Morning peak"
                    onChange={(e) => set({ name: e.target.value })} />
                </label>
                <label className="field">
                  From
                  <input className="input" type="time" disabled={readOnly} value={m.start_time}
                    onChange={(e) => set({ start_time: e.target.value })} />
                </label>
                <label className="field">
                  To
                  <input className="input" type="time" disabled={readOnly} value={m.end_time}
                    onChange={(e) => set({ end_time: e.target.value })} />
                </label>
                <label className="field">
                  Multiplier
                  <input className="input" type="number" min="1" max="5" step="0.01" disabled={readOnly}
                    value={show(m.multiplier)} onChange={(e) => set({ multiplier: parseRequired(e.target.value) })} />
                </label>
                <label className="field">
                  Applies to
                  <select className="input" disabled={readOnly} value={m.applies_to}
                    onChange={(e) => set({ applies_to: e.target.value as AppliesTo })}>
                    {APPLIES_TO.map((o) => (
                      <option key={o.value} value={o.value}>{o.label}</option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  Priority
                  <input className="input" type="number" step="1" disabled={readOnly} value={show(m.priority)}
                    onChange={(e) => set({ priority: parseRequired(e.target.value) })} />
                </label>
              </div>
              <fieldset className="inline" style={{ border: 0, padding: 0, margin: '8px 0', gap: 12 }} disabled={readOnly}>
                <legend className="small muted">Days</legend>
                {DAYS.map((day, d) => (
                  <label key={day} className="field-check">
                    <input
                      type="checkbox"
                      checked={m.days_of_week.includes(d)}
                      onChange={(e) =>
                        set({
                          days_of_week: e.target.checked
                            ? [...m.days_of_week, d].sort()
                            : m.days_of_week.filter((x) => x !== d),
                        })
                      }
                    />
                    {day}
                  </label>
                ))}
                <label className="field-check" style={{ marginLeft: 'auto' }}>
                  <input type="checkbox" checked={m.stacks} onChange={(e) => set({ stacks: e.target.checked })} />
                  Stacks with other windows
                </label>
              </fieldset>
              {!readOnly ? (
                <button type="button" className="btn btn-sm"
                  onClick={() => update({ time_multipliers: draft.time_multipliers.filter((_, j) => j !== i) })}>
                  Remove window
                </button>
              ) : null}
            </div>
          );
        })}
      </Section>

      <Section
        title="Zone multipliers"
        sub="Higher prices for trips in specific service zones."
        onAdd={
          readOnly || lookups.zones.length === 0
            ? undefined
            : () =>
                update({
                  zone_multipliers: [...draft.zone_multipliers, { service_zone_id: '', multiplier: 1.1, reason: '' }],
                })
        }
        empty={
          lookups.zones.length === 0
            ? 'This city has no service zones yet.'
            : draft.zone_multipliers.length === 0
              ? 'No zone multipliers.'
              : null
        }
      >
        {draft.zone_multipliers.map((z, i) => (
          <Row key={i} readOnly={readOnly}
            onRemove={() => update({ zone_multipliers: draft.zone_multipliers.filter((_, j) => j !== i) })}>
            <SelectCell label="Zone" value={z.service_zone_id} readOnly={readOnly} placeholder="Choose…"
              options={lookups.zones.map((o) => ({ value: o.id, label: o.name }))}
              onChange={(v) => update({ zone_multipliers: replace(draft.zone_multipliers, i, { ...z, service_zone_id: v }) })} />
            <NumberCell label="Multiplier" value={z.multiplier} readOnly={readOnly} step="0.01"
              onChange={(v) => update({ zone_multipliers: replace(draft.zone_multipliers, i, { ...z, multiplier: v }) })} />
            <label className="field" style={{ flex: 2 }}>
              Reason
              <input className="input" disabled={readOnly} value={z.reason}
                onChange={(e) => update({ zone_multipliers: replace(draft.zone_multipliers, i, { ...z, reason: e.target.value }) })} />
            </label>
          </Row>
        ))}
      </Section>

      <Section title="Coverage" sub="Optional: limit this version to service zones and vehicle types.">
        <div className="form-grid">
          <div className="field">
            Service zones
            {lookups.zones.length === 0 ? <span className="small muted">No zones in this city.</span> : null}
            {lookups.zones.map((zone) => {
              const row = draft.zones.find((z) => z.service_zone_id === zone.id);
              return (
                <div key={zone.id} className="inline" style={{ gap: 12 }}>
                  <label className="field-check">
                    <input
                      type="checkbox"
                      disabled={readOnly}
                      checked={Boolean(row)}
                      onChange={(e) =>
                        update({
                          zones: e.target.checked
                            ? [...draft.zones, { service_zone_id: zone.id, is_primary: false }]
                            : draft.zones.filter((z) => z.service_zone_id !== zone.id),
                        })
                      }
                    />
                    {zone.name}
                  </label>
                  {row ? (
                    <label className="field-check small">
                      <input
                        type="radio"
                        name="primary-zone"
                        disabled={readOnly}
                        checked={row.is_primary}
                        onChange={() =>
                          update({
                            zones: draft.zones.map((z) => ({ ...z, is_primary: z.service_zone_id === zone.id })),
                          })
                        }
                      />
                      primary
                    </label>
                  ) : null}
                </div>
              );
            })}
          </div>
          <div className="field">
            Vehicle types
            {lookups.vehicleTypes.map((vt) => (
              <label key={vt.id} className="field-check">
                <input
                  type="checkbox"
                  disabled={readOnly}
                  checked={draft.vehicle_type_ids.includes(vt.id)}
                  onChange={(e) =>
                    update({
                      vehicle_type_ids: e.target.checked
                        ? [...draft.vehicle_type_ids, vt.id]
                        : draft.vehicle_type_ids.filter((x) => x !== vt.id),
                    })
                  }
                />
                {vt.name}
              </label>
            ))}
          </div>
        </div>
      </Section>

      <Section title="Regulation and notes">
        <div className="form-grid">
          <label className="field">
            Regulated tariff (cap)
            <select
              className="input"
              disabled={readOnly}
              value={draft.regulated_tariff_id ?? ''}
              onChange={(e) => update({ regulated_tariff_id: e.target.value || null })}
            >
              <option value="">None</option>
              {lookups.tariffs.map((t) => (
                <option key={t.id} value={t.id}>{t.name}</option>
              ))}
            </select>
          </label>
          <label className="field" style={{ gridColumn: 'span 2' }}>
            Notes (why this change)
            <input className="input" disabled={readOnly} value={draft.notes}
              onChange={(e) => update({ notes: e.target.value })} placeholder="e.g. Fuel price increase, Nov 2026" />
          </label>
        </div>
      </Section>

      {!readOnly ? (
        <div className="card card-pad" style={{ position: 'sticky', bottom: 0, zIndex: 2 }}>
          {issues.length > 0 ? (
            <div className="notice notice-error" role="alert">
              <strong>Fix before saving:</strong>
              <ul style={{ margin: '4px 0 0 16px' }}>
                {issues.map((issue, i) => (
                  <li key={i}>
                    {issue.section}: {issue.message}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
          {serverErrors.length > 0 ? (
            <div className="notice notice-error" role="alert">
              {serverErrors.map((e, i) => (
                <div key={i}>{e}</div>
              ))}
            </div>
          ) : null}
          <div className="inline" style={{ justifyContent: 'space-between' }}>
            <span className="small muted" aria-live="polite">
              {pending
                ? 'Saving…'
                : dirty
                  ? 'Unsaved changes'
                  : savedAt
                    ? `Saved at ${savedAt.toLocaleTimeString()}`
                    : 'No changes'}
            </span>
            <div className="inline">
              <button type="button" className="btn" disabled={!dirty || pending} onClick={() => setDraft(saved)}>
                Undo changes
              </button>
              <button
                type="button"
                className="btn btn-primary"
                disabled={!dirty || pending || issues.length > 0}
                onClick={save}
              >
                Save draft
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

function round(n: number) {
  return Math.round(n * 10000) / 10000;
}

function replace<T>(rows: T[], index: number, next: T): T[] {
  return rows.map((row, i) => (i === index ? next : row));
}

function Section({
  title,
  sub,
  onAdd,
  empty,
  children,
}: {
  title: string;
  sub?: string;
  onAdd?: () => void;
  empty?: string | null;
  children?: ReactNode;
}) {
  return (
    <section className="card card-pad" aria-label={title}>
      <div className="inline" style={{ justifyContent: 'space-between', marginBottom: 8 }}>
        <div>
          <h2 className="card-title">{title}</h2>
          {sub ? <p className="card-sub">{sub}</p> : null}
        </div>
        {onAdd ? (
          <button type="button" className="btn btn-sm" onClick={onAdd}>
            Add
          </button>
        ) : null}
      </div>
      {empty ? <p className="small muted">{empty}</p> : null}
      {children}
    </section>
  );
}

function Row({ readOnly, onRemove, children }: { readOnly: boolean; onRemove: () => void; children: ReactNode }) {
  return (
    <div className="form-row" style={{ alignItems: 'flex-end', gap: 8, marginBottom: 8 }}>
      {children}
      {!readOnly ? (
        <button type="button" className="btn btn-sm" onClick={onRemove} aria-label="Remove row">
          Remove
        </button>
      ) : null}
    </div>
  );
}

function NumberCell({
  label,
  value,
  readOnly,
  step = '0.01',
  onChange,
}: {
  label: string;
  value: number;
  readOnly: boolean;
  step?: string;
  onChange: (value: number) => void;
}) {
  return (
    <label className="field" style={{ flex: 1 }}>
      {label}
      <input className="input" type="number" min="0" step={step} disabled={readOnly} value={show(value)}
        onChange={(e) => onChange(parseRequired(e.target.value))} />
    </label>
  );
}

function OptionalNumberCell({
  label,
  value,
  readOnly,
  onChange,
}: {
  label: string;
  value: number | null;
  readOnly: boolean;
  onChange: (value: number | null) => void;
}) {
  return (
    <label className="field" style={{ flex: 1 }}>
      {label}
      <input className="input" type="number" min="0" step="0.01" disabled={readOnly} value={show(value)}
        placeholder="and above" onChange={(e) => onChange(parseOptional(e.target.value))} />
    </label>
  );
}

function SelectCell({
  label,
  value,
  options,
  readOnly,
  placeholder,
  onChange,
}: {
  label: string;
  value: string;
  options: { value: string; label: string }[];
  readOnly: boolean;
  placeholder?: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="field" style={{ flex: 1 }}>
      {label}
      <select className="input" disabled={readOnly} value={value} onChange={(e) => onChange(e.target.value)}>
        {placeholder ? <option value="">{placeholder}</option> : null}
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </label>
  );
}
