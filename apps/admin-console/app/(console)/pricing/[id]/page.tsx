import Link from 'next/link';
import { notFound } from 'next/navigation';

import { ConfirmSubmit } from '@/components/confirm-submit';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { formatDate, formatMoney } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { VERSION_STATUS_LABEL, versionStatus, type VersionStatus } from '@/lib/pricing/draft';
import { createClient } from '@/lib/supabase/server';

import { createDraftAction, deletePricingPlanAction, updatePricingPlanAction } from '../actions';
import { RecordActions } from '@/components/record-actions';

export const dynamic = 'force-dynamic';

const STATUS_TONE: Record<VersionStatus, string> = {
  draft: 'amber',
  scheduled: 'violet',
  active: 'green',
  superseded: 'gray',
};

type Named = { name?: string | null } | null;
type Version = {
  id: string;
  version_number: number;
  currency_code: string;
  effective_from: string;
  effective_to: string | null;
  published_at: string | null;
  notes: string | null;
  pricing_plan_base_rates: { base_fare: number; per_km_rate: number; per_min_rate: number }[] | null;
};
type Plan = {
  id: string;
  code: string;
  name: string;
  description: string | null;
  is_active: boolean;
  countries: Named;
  cities: Named;
  service_zones: Named;
  vehicle_types: Named;
  pricing_plan_versions: Version[] | null;
};

export default async function PricingPlanPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('pricing');
  const [{ id }, query] = await Promise.all([params, searchParams]);
  const supabase = await createClient();

  const { data, error } = await supabase
    .from('pricing_plans')
    .select(
      'id, code, name, description, is_active, countries(name), cities(name), service_zones(name), vehicle_types(name), pricing_plan_versions(id, version_number, currency_code, effective_from, effective_to, published_at, notes, pricing_plan_base_rates(base_fare, per_km_rate, per_min_rate))',
    )
    .eq('id', id)
    .maybeSingle();
  if (error) {
    return (
      <>
        <PageHeader title="Pricing plan" />
        <div className="notice notice-error">{error.message}</div>
      </>
    );
  }
  if (!data) notFound();

  const plan = data as unknown as Plan;
  const now = new Date();
  const versions = [...(plan.pricing_plan_versions ?? [])]
    .sort((a, b) => b.version_number - a.version_number)
    .map((v) => ({ ...v, status: versionStatus(v, now) }));
  const draft = versions.find((v) => v.status === 'draft');
  const hasPublished = versions.some((v) => v.status !== 'draft');

  return (
    <>
      <PageHeader
        title={plan.name}
        description={`${plan.cities?.name ?? ''}, ${plan.countries?.name ?? ''} · ${plan.vehicle_types?.name ?? 'Any vehicle'}${plan.service_zones?.name ? ` · ${plan.service_zones.name}` : ''}`}
        actions={
          <>
            <Link className="btn" href="/pricing">
              All plans
            </Link>
            {draft ? (
              <Link className="btn btn-primary" href={`/pricing/${plan.id}/versions/${draft.id}`}>
                Continue draft v{draft.version_number}
              </Link>
            ) : hasPublished ? (
              <form action={createDraftAction}>
                <input type="hidden" name="plan_id" value={plan.id} />
                <button className="btn btn-primary" type="submit">
                  Change rates
                </button>
              </form>
            ) : null}
          </>
        }
      />
      <Notice searchParams={query} />

      <div className="split">
        <div className="card">
          <div className="card-pad" style={{ paddingBottom: 0 }}>
            <h2 className="card-title">Versions</h2>
            <p className="card-sub">
              Published versions never change. Quotes use the active version at booking time; a scheduled
              version takes over at its start.
            </p>
          </div>
          <DataTable
            columns={['Version', 'Status', 'In force', 'Base · per km · per min', 'Notes']}
            empty="This plan has no versions."
            actions={versions.map((v) => (
              <RecordActions
                key={v.id}
                table="pricing_plan_versions"
                id={v.id}
                generic="view"
                label={`Actions for v${v.version_number}`}
                items={[
                  { kind: 'link', label: v.status === 'draft' ? 'Edit prices' : 'View prices', href: `/pricing/${plan.id}/versions/${v.id}` },
                  ...(!draft && v.status !== 'draft'
                    ? [{
                        kind: 'form' as const,
                        label: v.status === 'superseded' ? 'Restore as draft' : 'Change prices (new draft)',
                        action: createDraftAction,
                        fields: { plan_id: plan.id, source_version_id: v.id },
                      }]
                    : []),
                ]}
              />
            ))}
            rows={versions.map((v) => {
              const rates = v.pricing_plan_base_rates?.[0];
              return [
                <strong key="n">v{v.version_number}</strong>,
                <span key="s" className={`badge badge-${STATUS_TONE[v.status]}`}>
                  {VERSION_STATUS_LABEL[v.status]}
                </span>,
                v.status === 'draft' ? (
                  <span key="w" className="muted">
                    Not published
                  </span>
                ) : (
                  <span key="w" className="nowrap">
                    {formatDate(v.effective_from)}
                    {v.effective_to ? ` – ${formatDate(v.effective_to)}` : ' onwards'}
                  </span>
                ),
                rates ? (
                  <span key="r" className="nowrap">
                    {formatMoney(rates.base_fare, v.currency_code)} · {formatMoney(rates.per_km_rate, v.currency_code)} ·{' '}
                    {formatMoney(rates.per_min_rate, v.currency_code)}
                  </span>
                ) : (
                  '—'
                ),
                <span key="notes" className="small truncate">
                  {v.notes ?? ''}
                </span>,
              ];
            })}
          />
        </div>

        <div className="section-stack">
          <div className="card card-pad">
            <h2 className="card-title">Plan details</h2>
            <form action={updatePricingPlanAction} className="form" style={{ marginTop: 12 }}>
              <input type="hidden" name="plan_id" value={plan.id} />
              <label className="field">
                Name
                <input className="input" name="name" defaultValue={plan.name} required />
              </label>
              <label className="field">
                Description
                <textarea className="input" name="description" defaultValue={plan.description ?? ''} rows={3} />
              </label>
              <label className="field-check">
                <input type="checkbox" name="is_active" defaultChecked={plan.is_active} />
                Active — inactive plans are never used to price bookings
              </label>
              <div className="small muted">
                Code <span className="mono">{plan.code}</span> and scope are fixed once created.
              </div>
              <button className="btn btn-primary" type="submit">
                Save details
              </button>
            </form>
          </div>

          <div className="card card-pad">
            <h2 className="card-title">Delete plan</h2>
            <p className="small muted">
              Only plans that have never priced a quote can be deleted. Deactivate the plan otherwise.
            </p>
            <form action={deletePricingPlanAction}>
              <input type="hidden" name="plan_id" value={plan.id} />
              <ConfirmSubmit message={`Delete "${plan.name}" and all its versions? This cannot be undone.`}>
                Delete plan
              </ConfirmSubmit>
            </form>
          </div>
        </div>
      </div>
    </>
  );
}
