import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { loadProfileSummaries } from '@/lib/profile-summaries';
import { entityHref } from '@/lib/entity-links';
import { loadAuditedNames } from '@/lib/record-labels';
import { createClient } from '@/lib/supabase/server';
import { RecordActions } from '@/components/record-actions';

export const dynamic = 'force-dynamic';

export default async function AuditPage() {
  await requireArea('audit');
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('admin_actions_log')
    .select(
      'id, admin_profile_id, admin_role, permission_used, action, entity_type, entity_id, old_value, new_value, ip_address, created_at',
    )
    .order('created_at', { ascending: false })
    .limit(200);

  const [profiles, entityName] = await Promise.all([
    loadProfileSummaries(
      supabase,
      (data ?? []).map((entry) => entry.admin_profile_id),
    ),
    loadAuditedNames(data ?? []),
  ]);

  return (
    <>
      <PageHeader records={['audit']}
        title="Audit log"
        description="Immutable admin action trail. Verification decisions, pricing changes, refunds, and account interventions are recorded here."
      />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['When', 'Admin', 'Role', 'Action', 'Entity', 'Permission', 'IP']}
          rows={(data ?? []).map((entry) => {
            const admin = profiles.get(entry.admin_profile_id);
            return [
              <span className="small muted nowrap" key="d">
                {formatDate(entry.created_at)}
              </span>,
              <div className="small" key="a">
                {admin?.full_name ?? shortId(entry.admin_profile_id)}
                <div className="muted">{admin?.email ?? ''}</div>
              </div>,
              titleize(entry.admin_role),
              <div key="ac">
                <strong>{titleize(entry.action)}</strong>
                {entry.new_value ? (
                  <div
                    className="small muted mono"
                    style={{ maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis' }}
                  >
                    {JSON.stringify(entry.new_value)}
                  </div>
                ) : null}
              </div>,
              <span className="small" key="e">
                {entityName(entry.entity_type, entry.entity_id) ?? titleize(entry.entity_type ?? '—')}
                <div className={entityName(entry.entity_type, entry.entity_id) ? 'muted' : 'mono muted'}>
                  {entityName(entry.entity_type, entry.entity_id)
                    ? titleize(entry.entity_type ?? '')
                    : shortId(entry.entity_id)}
                </div>
              </span>,
              <span className="mono small" key="p">
                {entry.permission_used ?? '—'}
              </span>,
              <span className="mono small" key="ip">
                {entry.ip_address ?? '—'}
              </span>,
            ];
          })}
          actions={(data ?? []).map((entry) => {
            const href = entityHref(entry.entity_type, entry.entity_id);
            return (
              <RecordActions
                key={entry.id}
                table="admin_actions_log"
                id={entry.id}
                items={[
                  ...(href ? [{ kind: 'link' as const, label: 'Open changed record', href }] : []),
                  ...(entry.admin_profile_id ? [{ kind: 'link' as const, label: 'Open admin', href: `/users/${entry.admin_profile_id}` }] : []),
                ]}
              />
            );
          })}
          empty="No admin actions recorded yet."
        />
      </div>
    </>
  );
}
