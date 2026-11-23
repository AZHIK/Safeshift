import Link from 'next/link';
import { notFound } from 'next/navigation';

import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { RecordActions } from '@/components/record-actions';
import { CellValue } from '@/components/cell-value';
import { isTableName, keyOf, type RecordColumn, requireRecordTable } from '@/lib/data-records';
import { titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

const PAGE = 50;
const SHOWN = 7;

export default async function TableRecordsPage({
  params,
  searchParams,
}: {
  params: Promise<{ table: string }>;
  searchParams: Promise<{ q?: string; page?: string; sort?: string; dir?: string }>;
}) {
  const { table } = await params;
  if (!isTableName(table)) notFound();
  await requireRecordTable(table);
  const sp = await searchParams;
  const q = (sp.q ?? '').trim();
  const page = Math.max(1, Number(sp.page) || 1);
  const asc = sp.dir === 'asc';
  const supabase = await createClient();
  const [cols, list] = await Promise.all([
    supabase.rpc('admin_record_columns', { p_table: table }),
    supabase.rpc('admin_record_list', {
      p_table: table,
      p_search: q || null,
      p_order: sp.sort ?? null,
      p_desc: !asc,
      p_limit: PAGE,
      p_offset: (page - 1) * PAGE,
    }),
  ]);
  if (cols.error?.code === '42P01') notFound();
  const error = cols.error?.message ?? list.error?.message ?? null;
  const columns = (cols.data ?? []) as RecordColumn[];
  const result = (list.data ?? {}) as {
    rows?: Record<string, unknown>[];
    total?: number;
    order?: string;
    primary_key?: string[];
    write_block?: string | null;
  };
  const rows = result.rows ?? [];
  const total = result.total ?? 0;
  const pk = result.primary_key ?? columns.filter((c) => c.is_primary_key).map((c) => c.column_name);
  // Readable columns first: names and statuses before ids and timestamps.
  const shown = columns
    .filter((c) => !/json|\[\]/.test(c.data_type))
    .sort((a, b) => Number(a.is_primary_key) - Number(b.is_primary_key))
    .slice(0, SHOWN);

  function href(next: Record<string, string | number | null>) {
    const p = new URLSearchParams();
    const merged = { q, page, sort: sp.sort ?? null, dir: sp.dir ?? null, ...next };
    for (const [k, v] of Object.entries(merged)) if (v !== null && v !== '' && !(k === 'page' && v === 1)) p.set(k, String(v));
    return `/data/${table}${p.size ? `?${p}` : ''}`;
  }

  return (
    <>
      <PageHeader
        title={titleize(table)}
        description={result.write_block ?? `${total.toLocaleString()} record${total === 1 ? '' : 's'} in ${table}.`}
        actions={
          <>
            <Link className="btn" href="/data">All tables</Link>
            {result.write_block ? null : (
              <Link className="btn btn-primary" href={`/data/${table}/new`}>Add record</Link>
            )}
          </>
        }
      />
      <form className="card card-pad form-row" method="get" style={{ marginBottom: 16 }}>
        <div className="field" style={{ flex: 1 }}>
          <label htmlFor="q">Search any field</label>
          <input className="input" id="q" name="q" defaultValue={q} />
        </div>
        <div className="field">
          <label htmlFor="sort">Sort by</label>
          <select className="input" id="sort" name="sort" defaultValue={result.order ?? ''}>
            {columns.map((c) => (
              <option key={c.column_name} value={c.column_name}>{titleize(c.column_name)}</option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="dir">Order</label>
          <select className="input" id="dir" name="dir" defaultValue={asc ? 'asc' : 'desc'}>
            <option value="desc">Newest / highest first</option>
            <option value="asc">Oldest / lowest first</option>
          </select>
        </div>
        <button className="btn btn-primary" type="submit">Apply</button>
        {q ? <Link className="btn" href={`/data/${table}`}>Clear</Link> : null}
      </form>
      {error ? <div className="notice notice-error">{error}</div> : null}
      <div className="card">
        <DataTable
          columns={shown.map((c) => titleize(c.column_name))}
          rows={rows.map((row) => shown.map((c) => <CellValue key={c.column_name} value={row[c.column_name]} />))}
          actions={rows.map((row, i) => (
            <RecordActions key={i} table={table} recordKey={keyOf(row, pk)} />
          ))}
          empty={q ? 'No matching records.' : 'This table is empty.'}
        />
      </div>
      {total > PAGE ? (
        <div className="inline" style={{ gap: 8, marginTop: 12, justifyContent: 'flex-end' }}>
          <span className="small muted">
            Page {page} of {Math.ceil(total / PAGE)}
          </span>
          {page > 1 ? <Link className="btn btn-sm" href={href({ page: page - 1 })}>Previous</Link> : null}
          {page * PAGE < total ? <Link className="btn btn-sm" href={href({ page: page + 1 })}>Next</Link> : null}
        </div>
      ) : null}
    </>
  );
}
