'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState, useTransition } from 'react';

import {
  DAYS,
  DISCOUNT_TYPES,
  RULE_TYPES,
  validatePromo,
  type DiscountType,
  type PromoForm,
  type RuleType,
} from '@/lib/promos/promo';

import { savePromoAction } from './actions';

type Option = { id: string; name: string };
export type PromoLookups = {
  countries: Option[];
  cities: (Option & { country_id: string })[];
  vehicleTypes: Option[];
  cargoTypes: Option[];
  zones: Option[];
};

/** ISO → "YYYY-MM-DDTHH:MM" in local time for datetime-local inputs. */
function toLocalInput(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
const fromLocalInput = (value: string) => (value ? new Date(value).toISOString() : '');

const parseNum = (raw: string) => (raw.trim() === '' ? Number.NaN : Number(raw));
const parseOptional = (raw: string) => (raw.trim() === '' ? null : Number(raw));
const show = (n: number | null) => (n === null || Number.isNaN(n) ? '' : String(n));

export function PromoFormClient({
  promoId,
  initial,
  lookups,
  codeLocked,
}: {
  promoId: string | null;
  initial: PromoForm;
  lookups: PromoLookups;
  /** True once redeemed: the code customers used must not change. */
  codeLocked: boolean;
}) {
  const router = useRouter();
  const [form, setForm] = useState<PromoForm>(initial);
  const [touched, setTouched] = useState(false);
  const [serverErrors, setServerErrors] = useState<string[]>([]);
  const [pending, startTransition] = useTransition();

  const errors = useMemo(() => validatePromo(form), [form]);
  const set = (patch: Partial<PromoForm>) => {
    setTouched(true);
    setForm((f) => ({ ...f, ...patch }));
  };
  const cities = lookups.cities.filter((c) => !form.country_id || c.country_id === form.country_id);
  const isPercent = form.discount_type === 'percentage' || form.discount_type === 'capped_percentage';

  function toggle(key: 'applicable_vehicle_type_ids' | 'applicable_city_ids' | 'applicable_cargo_type_ids', id: string) {
    const list = form[key];
    set({ [key]: list.includes(id) ? list.filter((x) => x !== id) : [...list, id] } as Partial<PromoForm>);
  }

  function submit(event: React.FormEvent) {
    event.preventDefault();
    setTouched(true);
    if (errors.length > 0) return;
    setServerErrors([]);
    startTransition(async () => {
      const result = await savePromoAction(promoId, form);
      if (result.ok) {
        router.push(`/promos/${result.id}?ok=${encodeURIComponent(promoId ? 'Promo saved.' : 'Promo created.')}`);
        router.refresh();
      } else {
        setServerErrors(result.errors);
      }
    });
  }

  const targetList = (
    title: string,
    key: 'applicable_vehicle_type_ids' | 'applicable_city_ids' | 'applicable_cargo_type_ids',
    options: Option[],
  ) => (
    <fieldset className="field" style={{ border: 0, padding: 0, margin: 0 }}>
      <legend>{title}</legend>
      <span className="small muted">{form[key].length === 0 ? 'All' : `${form[key].length} selected`}</span>
      <div style={{ maxHeight: 160, overflow: 'auto' }}>
        {options.map((o) => (
          <label key={o.id} className="field-check">
            <input type="checkbox" checked={form[key].includes(o.id)} onChange={() => toggle(key, o.id)} />
            {o.name}
          </label>
        ))}
      </div>
    </fieldset>
  );

  return (
    <form onSubmit={submit} className="section-stack" noValidate>
      <section className="card card-pad" aria-label="Promo">
        <h2 className="card-title">Promo</h2>
        <div className="form-grid" style={{ marginTop: 8 }}>
          <label className="field">
            Code
            <input
              className="input mono"
              value={form.code}
              disabled={codeLocked}
              onChange={(e) => set({ code: e.target.value.toUpperCase() })}
              placeholder="KARIBU20"
              aria-describedby="code-help"
            />
            <span id="code-help" className="small muted">
              {codeLocked ? 'Locked: customers have already used this code.' : 'What customers type. Letters, digits, - and _.'}
            </span>
          </label>
          <label className="field">
            Name
            <input className="input" value={form.name} onChange={(e) => set({ name: e.target.value })} placeholder="Launch week" />
          </label>
          <label className="field" style={{ gridColumn: 'span 2' }}>
            Description (internal)
            <input className="input" value={form.description} onChange={(e) => set({ description: e.target.value })} />
          </label>
        </div>
      </section>

      <section className="card card-pad" aria-label="Discount">
        <h2 className="card-title">Discount</h2>
        <div className="form-grid" style={{ marginTop: 8 }}>
          <label className="field">
            Type
            <select
              className="input"
              value={form.discount_type}
              onChange={(e) => set({ discount_type: e.target.value as DiscountType })}
            >
              {DISCOUNT_TYPES.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
            <span className="small muted">{DISCOUNT_TYPES.find((t) => t.value === form.discount_type)?.help}</span>
          </label>
          {form.discount_type !== 'free_ride' ? (
            <label className="field">
              {isPercent ? 'Percent off' : 'Amount off'}
              <input
                className="input"
                type="number"
                min="0"
                max={isPercent ? 100 : undefined}
                step="0.01"
                value={show(form.discount_value)}
                onChange={(e) => set({ discount_value: parseNum(e.target.value) })}
              />
            </label>
          ) : null}
          {form.discount_type === 'capped_percentage' ? (
            <label className="field">
              Maximum discount
              <input
                className="input"
                type="number"
                min="0"
                step="0.01"
                value={show(form.max_discount_amount)}
                onChange={(e) => set({ max_discount_amount: parseOptional(e.target.value) })}
              />
            </label>
          ) : null}
          <label className="field">
            Currency
            <input
              className="input"
              value={form.currency_code}
              maxLength={3}
              placeholder="TZS"
              onChange={(e) => set({ currency_code: e.target.value.toUpperCase() })}
            />
          </label>
          <label className="field">
            Minimum fare
            <input
              className="input"
              type="number"
              min="0"
              step="0.01"
              value={show(form.min_purchase_amount)}
              onChange={(e) => set({ min_purchase_amount: parseNum(e.target.value) })}
            />
            <span className="small muted">Fare before discount and VAT.</span>
          </label>
        </div>
      </section>

      <section className="card card-pad" aria-label="Validity and limits">
        <h2 className="card-title">Validity and limits</h2>
        <div className="form-grid" style={{ marginTop: 8 }}>
          <label className="field">
            Starts (your local time)
            <input
              className="input"
              type="datetime-local"
              value={toLocalInput(form.valid_from)}
              onChange={(e) => set({ valid_from: fromLocalInput(e.target.value) })}
            />
          </label>
          <label className="field">
            Ends
            <input
              className="input"
              type="datetime-local"
              value={toLocalInput(form.valid_to)}
              onChange={(e) => set({ valid_to: fromLocalInput(e.target.value) })}
            />
          </label>
          <label className="field">
            Total uses
            <input
              className="input"
              type="number"
              min="1"
              step="1"
              placeholder="Unlimited"
              value={show(form.total_redemption_limit)}
              onChange={(e) => set({ total_redemption_limit: parseOptional(e.target.value) })}
            />
          </label>
          <label className="field">
            Uses per customer
            <input
              className="input"
              type="number"
              min="1"
              step="1"
              value={show(form.per_user_redemption_limit)}
              onChange={(e) => set({ per_user_redemption_limit: parseNum(e.target.value) })}
            />
          </label>
        </div>
        <label className="field-check" style={{ marginTop: 8 }}>
          <input type="checkbox" checked={form.new_users_only} onChange={(e) => set({ new_users_only: e.target.checked })} />
          New customers only (joined in the last 30 days, never used a promo)
        </label>
        <label className="field-check">
          <input type="checkbox" checked={form.is_active} onChange={(e) => set({ is_active: e.target.checked })} />
          Active
        </label>
      </section>

      <section className="card card-pad" aria-label="Where it applies">
        <h2 className="card-title">Where it applies</h2>
        <p className="card-sub">Leave a list empty to allow all.</p>
        <div className="form-grid" style={{ marginTop: 8 }}>
          <label className="field">
            Country
            <select
              className="input"
              value={form.country_id}
              onChange={(e) => set({ country_id: e.target.value, applicable_city_ids: [] })}
            >
              <option value="">All countries</option>
              {lookups.countries.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
          {targetList('Cities', 'applicable_city_ids', cities)}
          {targetList('Vehicle types', 'applicable_vehicle_type_ids', lookups.vehicleTypes)}
          {targetList('Cargo types', 'applicable_cargo_type_ids', lookups.cargoTypes)}
        </div>
      </section>

      <section className="card card-pad" aria-label="Eligibility rules">
        <div className="inline" style={{ justifyContent: 'space-between' }}>
          <div>
            <h2 className="card-title">Eligibility rules</h2>
            <p className="card-sub">All rules must pass for the promo to apply.</p>
          </div>
          <button
            type="button"
            className="btn btn-sm"
            onClick={() => set({ rules: [...form.rules, { rule_type: 'first_job', value: '', description: '' }] })}
          >
            Add rule
          </button>
        </div>
        {form.rules.length === 0 ? <p className="small muted">No extra rules.</p> : null}
        {form.rules.map((rule, i) => {
          const kind = RULE_TYPES.find((r) => r.value === rule.rule_type);
          const update = (patch: Partial<typeof rule>) =>
            set({ rules: form.rules.map((r, j) => (j === i ? { ...r, ...patch } : r)) });
          return (
            <div key={i} className="form-row" style={{ alignItems: 'flex-end', gap: 8, marginTop: 8 }}>
              <label className="field" style={{ flex: 2 }}>
                Rule
                <select
                  className="input"
                  value={rule.rule_type}
                  onChange={(e) => update({ rule_type: e.target.value as RuleType, value: '' })}
                >
                  {RULE_TYPES.map((r) => (
                    <option key={r.value} value={r.value}>
                      {r.label}
                    </option>
                  ))}
                </select>
              </label>
              {kind?.input === 'number' ? (
                <label className="field" style={{ flex: 1 }}>
                  N
                  <input className="input" type="number" min="1" step="1" value={rule.value}
                    onChange={(e) => update({ value: e.target.value })} />
                </label>
              ) : null}
              {kind?.input === 'zone' ? (
                <label className="field" style={{ flex: 1 }}>
                  Zone
                  <select className="input" value={rule.value} onChange={(e) => update({ value: e.target.value })}>
                    <option value="">Choose…</option>
                    {lookups.zones.map((z) => (
                      <option key={z.id} value={z.id}>{z.name}</option>
                    ))}
                  </select>
                </label>
              ) : null}
              {kind?.input === 'day' ? (
                <label className="field" style={{ flex: 1 }}>
                  Day
                  <select className="input" value={rule.value} onChange={(e) => update({ value: e.target.value })}>
                    <option value="">Choose…</option>
                    {DAYS.map((d, n) => (
                      <option key={d} value={String(n)}>{d}</option>
                    ))}
                  </select>
                </label>
              ) : null}
              <button type="button" className="btn btn-sm" aria-label={`Remove rule ${i + 1}`}
                onClick={() => set({ rules: form.rules.filter((_, j) => j !== i) })}>
                Remove
              </button>
            </div>
          );
        })}
      </section>

      <div className="card card-pad" style={{ position: 'sticky', bottom: 0, zIndex: 2 }}>
        {touched && errors.length > 0 ? (
          <div className="notice notice-error" role="alert">
            <ul style={{ margin: 0, paddingLeft: 16 }}>
              {errors.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          </div>
        ) : null}
        {serverErrors.length > 0 ? (
          <div className="notice notice-error" role="alert">
            {serverErrors.join(' ')}
          </div>
        ) : null}
        <div className="inline" style={{ justifyContent: 'flex-end' }}>
          <button type="button" className="btn" onClick={() => router.push('/promos')}>
            Cancel
          </button>
          <button type="submit" className="btn btn-primary" disabled={pending}>
            {pending ? 'Saving…' : promoId ? 'Save promo' : 'Create promo'}
          </button>
        </div>
      </div>
    </form>
  );
}
