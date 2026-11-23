import Link from 'next/link';
import { notFound } from 'next/navigation';

import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { formatDate } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { VERSION_SELECT, VERSION_STATUS_LABEL, draftFromVersion, versionStatus } from '@/lib/pricing/draft';
import { createClient } from '@/lib/supabase/server';

import { VersionWorkspace } from './version-workspace';

export const dynamic = 'force-dynamic';

type Plan = { id: string; name: string; country_id: string; city_id: string };
type Option = { id: string; name: string };

const toOptions = (rows: unknown[] | null): Option[] =>
  ((rows ?? []) as { id: string; name: string }[]).map((r) => ({ id: String(r.id), name: String(r.name) }));

export default async function PricingVersionPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string; versionId: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('pricing');
  const [{ id: planId, versionId }, query] = await Promise.all([params, searchParams]);
  const supabase = await createClient();

  const [{ data: planData }, { data: versionData, error }] = await Promise.all([
    supabase.from('pricing_plans').select('id, name, country_id, city_id').eq('id', planId).maybeSingle(),
    supabase.from('pricing_plan_versions').select(VERSION_SELECT).eq('id', versionId).eq('pricing_plan_id', planId).maybeSingle(),
  ]);
  if (error) {
    return (
      <>
        <PageHeader title="Pricing version" />
        <div className="notice notice-error">{error.message}</div>
      </>
    );
  }
  if (!planData || !versionData) notFound();

  const plan = planData as Plan;
  const version = versionData as unknown as Record<string, unknown> & {
    version_number: number;
    currency_code: string;
    effective_from: string;
    effective_to: string | null;
    published_at: string | null;
  };
  const status = versionStatus(version);
  const isDraft = status === 'draft';

  const [cargo, equipment, zones, vehicles, tariffs] = await Promise.all([
    supabase
      .from('cargo_types')
      .select('id, name')
      .eq('is_active', true)
      .or(`country_id.is.null,country_id.eq.${plan.country_id}`)
      .order('display_order'),
    supabase.from('vehicle_equipment_catalog').select('id, name').eq('is_active', true).order('name'),
    supabase.from('service_zones').select('id, name').eq('city_id', plan.city_id).eq('is_active', true).order('name'),
    supabase
      .from('vehicle_types')
      .select('id, name')
      .eq('is_active', true)
      .or(`country_id.is.null,country_id.eq.${plan.country_id}`)
      .order('display_order'),
    supabase
      .from('regulated_tariffs')
      .select('id, name')
      .eq('is_active', true)
      .or(`country_id.is.null,country_id.eq.${plan.country_id}`)
      .order('name'),
  ]);

  const inForce =
    status === 'draft'
      ? 'Not published yet'
      : `${formatDate(version.effective_from)}${version.effective_to ? ` – ${formatDate(version.effective_to)}` : ' onwards'}`;

  return (
    <>
      <PageHeader
        title={`${plan.name} · v${version.version_number}`}
        description={`${VERSION_STATUS_LABEL[status]} · ${inForce} · ${version.currency_code}`}
        actions={
          <Link className="btn" href={`/pricing/${plan.id}`}>
            Back to plan
          </Link>
        }
      />
      <Notice searchParams={query} />
      {!isDraft ? (
        <div className="notice notice-info">
          Published versions are read-only. To change rates, open a draft from the plan page.
        </div>
      ) : null}
      <VersionWorkspace
        planId={plan.id}
        versionId={versionId}
        isDraft={isDraft}
        initial={draftFromVersion(version)}
        currency={version.currency_code}
        lookups={{
          cargoTypes: toOptions(cargo.data),
          equipment: toOptions(equipment.data),
          zones: toOptions(zones.data),
          vehicleTypes: toOptions(vehicles.data),
          tariffs: toOptions(tariffs.data),
        }}
      />
    </>
  );
}
