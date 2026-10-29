import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { loadProfileSummaries } from '@/lib/profile-summaries';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function AuditPage() {
  await requireArea('audit');
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('admin_actions_log')
    .select('id, admin_profile_id, admin_role, permission_used, action, entity_type, entity_id, old_value, new_value, ip_address, created_at')
    .order('created_at', { ascending: false })
    .limit(200);

  const profiles = await loadProfileSummaries(supabase, (data ?? []).map((entry) => entry.admin_profile_id));

  return (
    <>
      <PageHeader title="Audit log" description="Immutable admin action trail. Verification decisions, pricing changes, refunds, and account interventions are recorded here." />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['When', 'Admin', 'Role', 'Action', 'Entity', 'Permission', 'IP']}
          rows={(data ?? []).map((entry) => {
            const admin = profiles.get(entry.admin_profile_id);
            return [
              <span className="small muted nowrap" key="d">{formatDate(entry.created_at)}</span>,
              <div className="small" key="a">{admin?.full_name ?? shortId(entry.admin_profile_id)}<div className="muted">{admin?.email ?? ''}</div></div>,
              titleize(entry.admin_role),
              <div key="ac"><strong>{titleize(entry.action)}</strong>{entry.new_value ? <div className="small muted mono" style={{ maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis' }}>{JSON.stringify(entry.new_value)}</div> : null}</div>,
              <span className="small" key="e">{entry.entity_type ?? '—'}<div className="mono muted">{shortId(entry.entity_id)}</div></span>,
              <span className="mono small" key="p">{entry.permission_used ?? '—'}</span>,
              <span className="mono small" key="ip">{entry.ip_address ?? '—'}</span>,
            ];
          })}
          empty="No admin actions recorded yet."
        />
      </div>
    </>
  );
}
