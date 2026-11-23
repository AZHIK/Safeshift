'use client';

import { useState, useTransition } from 'react';

import { ConfirmSubmit } from '@/components/confirm-submit';
import type { PricingDraft } from '@/lib/pricing/draft';

import { discardDraftAction, previewQuoteAction, publishDraftAction } from '../../../actions';
import { DraftEditor, type EditorLookups } from './draft-editor';

type Breakdown = Record<string, unknown>;

const LINES: [string, string][] = [
  ['base_fare', 'Base fare'],
  ['distance_charge', 'Distance'],
  ['time_charge', 'Time'],
  ['weight_surcharge', 'Weight surcharge'],
  ['volume_surcharge', 'Volume surcharge'],
  ['cargo_surcharge', 'Cargo surcharge'],
  ['equipment_surcharge', 'Equipment'],
  ['waiting_charge', 'Waiting'],
  ['multi_stop_charge', 'Extra stops'],
  ['subtotal', 'Subtotal'],
  ['vat', 'VAT'],
  ['total', 'Total'],
];

/** "YYYY-MM-DDTHH:MM" in the browser's local time, for datetime-local inputs. */
function localInputValue(date: Date) {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export function VersionWorkspace({
  planId,
  versionId,
  isDraft,
  initial,
  currency,
  lookups,
}: {
  planId: string;
  versionId: string;
  isDraft: boolean;
  initial: PricingDraft;
  currency: string;
  lookups: EditorLookups;
}) {
  const [dirty, setDirty] = useState(false);

  return (
    <div className="split">
      <DraftEditor
        versionId={versionId}
        initial={initial}
        readOnly={!isDraft}
        currency={currency}
        lookups={lookups}
        onDirtyChange={setDirty}
      />
      <div className="section-stack">
        <PreviewPanel versionId={versionId} currency={currency} lookups={lookups} dirty={dirty} />
        {isDraft ? <PublishPanel planId={planId} versionId={versionId} dirty={dirty} /> : null}
      </div>
    </div>
  );
}

function PreviewPanel({
  versionId,
  currency,
  lookups,
  dirty,
}: {
  versionId: string;
  currency: string;
  lookups: EditorLookups;
  dirty: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [result, setResult] = useState<Breakdown | null>(null);
  const [error, setError] = useState<string | null>(null);

  function run(formData: FormData) {
    const n = (k: string) => Number(formData.get(k) || 0);
    setError(null);
    startTransition(async () => {
      const at = String(formData.get('at') || '');
      const response = await previewQuoteAction(versionId, {
        distance_km: n('distance_km'),
        duration_min: n('duration_min'),
        weight_kg: n('weight_kg'),
        volume_m3: n('volume_m3'),
        cargo_type_id: String(formData.get('cargo_type_id') || '') || null,
        equipment_ids: formData.getAll('equipment_ids').map(String),
        zone_id: String(formData.get('zone_id') || '') || null,
        at: at ? new Date(at).toISOString() : new Date().toISOString(),
      });
      if (response.ok) setResult(response.quote);
      else {
        setResult(null);
        setError(response.error);
      }
    });
  }

  const format = (value: unknown) =>
    new Intl.NumberFormat(undefined, { style: 'currency', currency, maximumFractionDigits: 0 }).format(Number(value ?? 0));

  return (
    <section className="card card-pad" aria-label="Fare preview">
      <h2 className="card-title">Fare preview</h2>
      <p className="card-sub">Prices a sample trip with this version{dirty ? ' as last saved' : ''}.</p>
      {dirty ? <div className="notice notice-info">Save the draft to preview your latest changes.</div> : null}
      <form action={run} className="form" style={{ marginTop: 8 }}>
        <div className="form-grid">
          <label className="field">
            Distance km
            <input className="input" name="distance_km" type="number" min="0" step="0.1" defaultValue="12" />
          </label>
          <label className="field">
            Duration min
            <input className="input" name="duration_min" type="number" min="0" step="1" defaultValue="35" />
          </label>
          <label className="field">
            Weight kg
            <input className="input" name="weight_kg" type="number" min="0" step="1" defaultValue="300" />
          </label>
          <label className="field">
            Volume m³
            <input className="input" name="volume_m3" type="number" min="0" step="0.1" defaultValue="2" />
          </label>
        </div>
        <label className="field">
          Cargo type
          <select className="input" name="cargo_type_id" defaultValue="">
            <option value="">General</option>
            {lookups.cargoTypes.map((o) => (
              <option key={o.id} value={o.id}>{o.name}</option>
            ))}
          </select>
        </label>
        {lookups.zones.length > 0 ? (
          <label className="field">
            Zone
            <select className="input" name="zone_id" defaultValue="">
              <option value="">Any</option>
              {lookups.zones.map((o) => (
                <option key={o.id} value={o.id}>{o.name}</option>
              ))}
            </select>
          </label>
        ) : null}
        <label className="field">
          Trip time
          <input className="input" name="at" type="datetime-local" defaultValue={localInputValue(new Date())} />
        </label>
        <button className="btn" type="submit" disabled={pending}>
          {pending ? 'Pricing…' : 'Preview fare'}
        </button>
      </form>
      {error ? <div className="notice notice-error" role="alert">{error}</div> : null}
      {result ? (
        <table className="audit-table" style={{ marginTop: 12, width: '100%' }} aria-label="Fare breakdown">
          <tbody>
            {LINES.filter(([key]) => key === 'total' || key === 'subtotal' || Number(result[key] ?? 0) !== 0).map(
              ([key, label]) => (
                <tr key={key} style={key === 'total' ? { fontWeight: 700 } : undefined}>
                  <td>{label}</td>
                  <td style={{ textAlign: 'right' }}>{format(result[key])}</td>
                </tr>
              ),
            )}
            {Number(result.time_multiplier ?? 1) !== 1 || Number(result.zone_multiplier ?? 1) !== 1 ? (
              <tr>
                <td>Multipliers</td>
                <td style={{ textAlign: 'right' }}>
                  time ×{Number(result.time_multiplier ?? 1)} · zone ×{Number(result.zone_multiplier ?? 1)}
                </td>
              </tr>
            ) : null}
            {result.is_capped ? (
              <tr>
                <td colSpan={2} className="small">
                  Capped by the regulated tariff (maximum {format(result.regulated_max_fare)}).
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      ) : null}
    </section>
  );
}

function PublishPanel({ planId, versionId, dirty }: { planId: string; versionId: string; dirty: boolean }) {
  const [mode, setMode] = useState<'now' | 'later'>('now');
  const [when, setWhen] = useState(() => localInputValue(new Date(Date.now() + 24 * 3600 * 1000)));
  const iso = mode === 'later' && when ? new Date(when).toISOString() : '';

  return (
    <section className="card card-pad" aria-label="Publish">
      <h2 className="card-title">Publish</h2>
      <p className="card-sub">Once published, this version cannot be edited. The current version stays in force until it starts.</p>
      {dirty ? <div className="notice notice-info">Save the draft before publishing.</div> : null}
      <form action={publishDraftAction} className="form" style={{ marginTop: 8 }}>
        <input type="hidden" name="plan_id" value={planId} />
        <input type="hidden" name="version_id" value={versionId} />
        <input type="hidden" name="effective_from" value={iso} />
        <label className="field-check">
          <input type="radio" name="mode" checked={mode === 'now'} onChange={() => setMode('now')} />
          Start now
        </label>
        <label className="field-check">
          <input type="radio" name="mode" checked={mode === 'later'} onChange={() => setMode('later')} />
          Schedule
        </label>
        {mode === 'later' ? (
          <label className="field">
            Starts at (your local time)
            <input className="input" type="datetime-local" value={when} min={localInputValue(new Date())}
              onChange={(e) => setWhen(e.target.value)} required />
          </label>
        ) : null}
        <ConfirmSubmit
          className="btn btn-primary"
          disabled={dirty}
          message={
            mode === 'now'
              ? 'Publish this version now? New bookings will be priced with it immediately.'
              : `Schedule this version for ${when.replace('T', ' ')}?`
          }
        >
          {mode === 'now' ? 'Publish now' : 'Schedule'}
        </ConfirmSubmit>
      </form>
      <form action={discardDraftAction} style={{ marginTop: 12 }}>
        <input type="hidden" name="plan_id" value={planId} />
        <input type="hidden" name="version_id" value={versionId} />
        <ConfirmSubmit className="btn btn-sm" message="Discard this draft? Its changes will be lost.">
          Discard draft
        </ConfirmSubmit>
      </form>
    </section>
  );
}
