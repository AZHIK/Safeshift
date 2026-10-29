import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  await requireArea('users');
  const params = await searchParams;
  const query = (params.q ?? '').trim();
  const supabase = await createClient();
  const result = await supabase.rpc('admin_search_profiles', { p_query: query, p_limit: 50 });
  const rows = (result.data ?? []) as Array<Record<string, unknown>>;
  const error = result.error?.message ?? null;

  return (
    <>
      <PageHeader
        title="Users"
        description="Search customers, drivers, business contacts, and staff. Leave the search blank for the most recent accounts."
      />
      <form className="card card-pad form-row" method="get" style={{ marginBottom: 16 }}>
        <div className="field" style={{ flex: 1 }}>
          <label htmlFor="q">Search name, phone, or email</label>
          <input className="input" id="q" name="q" defaultValue={query} placeholder="e.g. Juma or +255…" />
        </div>
        <button className="btn btn-primary" type="submit">Search</button>
        {query ? <Link className="btn" href="/users">Clear</Link> : null}
      </form>
      {error ? <div className="notice notice-error">{error}</div> : null}
      <div className="card">
        <DataTable
          columns={['Name', 'Role', 'Contact', 'Status', 'Joined', 'ID']}
          rows={rows.map((row) => [
            <div key="n">
              <strong>{String(row.full_name ?? row.display_name ?? 'Unnamed')}</strong>
              {row.display_name ? <div className="small muted">{String(row.display_name)}</div> : null}
            </div>,
            titleize(row.primary_role),
            <div key="c" className="small">{String(row.phone ?? '—')}<div className="muted">{String(row.email ?? '')}</div></div>,
            <StatusBadge key="s" value={row.is_active ? 'active' : 'disabled'} />,
            <span className="small muted" key="d">{formatDate(row.created_at)}</span>,
            <span className="mono" key="i">{shortId(row.profile_id)}</span>,
          ])}
          empty={query ? 'No matching users.' : 'No users found.'}
        />
      </div>
    </>
  );
}
