import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { RowMenu } from '@/components/row-menu';
import { StatusBadge } from '@/components/status-badge';
import { titleize } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type TableRow = { table_name: string; approx_rows: number; writable: boolean; write_block: string | null };

export default async function DataPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  await requireArea('data');
  const q = ((await searchParams).q ?? '').trim().toLowerCase();
  const { data, error } = await (await createClient()).rpc('admin_record_tables');
  const tables = ((data ?? []) as TableRow[]).filter(
    (t) => !q || t.table_name.includes(q.replaceAll(' ', '_')),
  );

  return (
    <>
      <PageHeader
        title="All data"
        description="Every table in the platform database. View, add, edit and delete records; money and audit records stay append-only and are handled on their own screens."
      />
      <form className="card card-pad form-row" method="get" style={{ marginBottom: 16 }}>
        <div className="field" style={{ flex: 1 }}>
          <label htmlFor="q">Find a table</label>
          <input className="input" id="q" name="q" defaultValue={q} placeholder="e.g. vehicle, zone, ticket" />
        </div>
        <button className="btn btn-primary" type="submit">Search</button>
      </form>
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Table', 'Rows (approx.)', 'Editing']}
          rows={tables.map((t) => [
            <Link key="t" href={`/data/${t.table_name}`}>
              <strong>{titleize(t.table_name)}</strong>
              <div className="small muted mono">{t.table_name}</div>
            </Link>,
            Number(t.approx_rows).toLocaleString(),
            t.writable ? (
              <StatusBadge key="w" value="active" />
            ) : (
              <span key="w" className="small muted" title={t.write_block ?? ''}>
                Append-only
              </span>
            ),
          ])}
          actions={tables.map((t) => (
            <RowMenu
              key={t.table_name}
              label={`Actions for ${t.table_name}`}
              items={[
                { kind: 'link', label: 'Browse records', href: `/data/${t.table_name}` },
                t.writable
                  ? { kind: 'link', label: 'Add a record', href: `/data/${t.table_name}/new` }
                  : { kind: 'disabled', label: 'Add a record', note: t.write_block ?? 'Append-only' },
              ]}
            />
          ))}
          empty="No tables match."
        />
      </div>
    </>
  );
}
