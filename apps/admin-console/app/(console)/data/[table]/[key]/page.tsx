import Link from 'next/link';
import { notFound } from 'next/navigation';

import { CellValue } from '@/components/cell-value';
import { PageHeader } from '@/components/page-header';
import { RecordActions } from '@/components/record-actions';
import { decodeKey, encodeKey, isTableName, type RecordColumn, requireRecordTable } from '@/lib/data-records';
import { titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function RecordPage({ params }: { params: Promise<{ table: string; key: string }> }) {
  const { table, key: token } = await params;
  const key = decodeKey(token);
  if (!isTableName(table) || !key) notFound();
  await requireRecordTable(table);
  const supabase = await createClient();
  const [cols, row] = await Promise.all([
    supabase.rpc('admin_record_columns', { p_table: table }),
    supabase.rpc('admin_record_get', { p_table: table, p_key: key }),
  ]);
  if (row.error?.code === 'P0002' || cols.error?.code === '42P01') notFound();
  const columns = (cols.data ?? []) as RecordColumn[];
  const record = (row.data ?? {}) as Record<string, unknown>;

  return (
    <>
      <PageHeader
        title={`${titleize(table)} record`}
        description={Object.values(key).join(' · ')}
        actions={
          <>
            <Link className="btn" href={`/data/${table}`}>Back to {titleize(table)}</Link>
            <RecordActions table={table} recordKey={key} label="Record actions" />
          </>
        }
      />
      {row.error ? <div className="notice notice-error">{row.error.message}</div> : null}
      <div className="card card-pad">
        <dl className="record-fields">
          {columns.map((c) => {
            const value = record[c.column_name];
            const ref = c.references_table?.replace('public.', '');
            return (
              <div key={c.column_name} className="record-field">
                <dt className="small muted">{titleize(c.column_name)}</dt>
                <dd>
                  {ref && typeof value === 'string' && value ? (
                    <Link className="mono small" href={`/data/${ref}/${encodeKey({ id: value })}`}>{value}</Link>
                  ) : value !== null && typeof value === 'object' ? (
                    <pre className="mono small" style={{ whiteSpace: 'pre-wrap', margin: 0 }}>{JSON.stringify(value, null, 2)}</pre>
                  ) : typeof value === 'string' && /^[0-9a-f]{8}-/i.test(value) ? (
                    <span className="mono small">{value}</span>
                  ) : (
                    <CellValue value={value} />
                  )}
                </dd>
              </div>
            );
          })}
        </dl>
      </div>
    </>
  );
}
