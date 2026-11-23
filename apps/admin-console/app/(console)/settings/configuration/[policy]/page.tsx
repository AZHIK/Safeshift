import { notFound } from 'next/navigation';
import { ConfigurationClient } from '@/components/configuration/configuration-client';
import { PageHeader } from '@/components/page-header';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { loadOptionsFor } from '@/lib/configuration/options';
import { policyResources } from '@/lib/configuration/resources/policies';
import { toView } from '@/lib/configuration/view';
import { createClient } from '@/lib/supabase/server';
import * as actions from './actions';

export default async function PolicyPage({ params }: { params: Promise<{policy:string}> }) {
  const {policy} = await params;
  if (!Object.hasOwn(policyResources, policy)) notFound();
  const resource = policyResources[policy];
  await requireConfigurationPermission(resource.permission);
  const client = await createClient();
  const [options,initial] = await Promise.all([loadOptionsFor(client,resource), actions.list(policy,{page:1,pageSize:25})]);
  return <><PageHeader title={resource.pluralTitle} description={resource.description}/>
    {!initial.success && <p role="alert">Could not load these records.</p>}
    <ConfigurationClient view={toView(resource)} options={options} countries={options.countries}
      initialRows={initial.rows} initialPage={initial.page} initialTotal={initial.total}
      actions={{list:actions.list.bind(null,policy),create:actions.create.bind(null,policy),update:actions.update.bind(null,policy),
        remove:actions.remove.bind(null,policy),deactivate:actions.deactivate.bind(null,policy),audit:actions.audit.bind(null,policy)}}/>
  </>;
}
