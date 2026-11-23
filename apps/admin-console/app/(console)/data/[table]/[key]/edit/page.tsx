import Link from 'next/link';
import { notFound } from 'next/navigation';

import { PageHeader } from '@/components/page-header';
import { RecordFields } from '@/components/record-form';
import { decodeKey, isTableName, type RecordColumn, requireRecordTable } from '@/lib/data-records';
import { loadRecordNames, loadReferenceChoices } from '@/lib/record-labels';
import { titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

import { updateRecordAction } from '../../../actions';

export const dynamic = 'force-dynamic';

export default async function EditRecordPage({ params }: { params: Promise<{ table: string; key: string }> }) {
  const { table, key: token } = await params;
  const key = decodeKey(token);
  if (!isTableName(table) || !key) notFound();
  await requireRecordTable(table);
  const supabase = await createClient();
  const [cols, row, tables] = await Promise.all([
    supabase.rpc('admin_record_columns', { p_table: table }),
    supabase.rpc('admin_record_get', { p_table: table, p_key: key }),
    supabase.rpc('admin_record_tables'),
  ]);
  if (row.error?.code === 'P0002' || cols.error?.code === '42P01') notFound();
  const block = ((tables.data ?? []) as { table_name: string; write_block: string | null }[]).find(
    (t) => t.table_name === table,
  )?.write_block;
  const back = `/data/${table}/${token}`;
  const columns = (cols.data ?? []) as RecordColumn[];
  const values = (row.data ?? {}) as Record<string, unknown>;
  const [references, names] = await Promise.all([
    block ? {} : loadReferenceChoices(table, columns, values),
    key.id ? loadRecordNames(table, [key.id]) : Promise.resolve({} as Record<string, string>),
  ]);

  return (
    <>
      <PageHeader title={`Edit ${titleize(table)} record`} description={(key.id && names[key.id]) || Object.values(key).join(' · ')}
        actions={<Link className="btn" href={back}>Cancel</Link>} />
      {row.error ? <div className="notice notice-error">{row.error.message}</div> : null}
      {block ? (
        <div className="notice notice-error">{block}</div>
      ) : (
        <form action={updateRecordAction} className="card card-pad form">
          <input type="hidden" name="table" value={table} />
          <input type="hidden" name="key" value={token} />
          <RecordFields columns={columns} values={values} mode="edit" table={table} references={references} />
          <div className="inline" style={{ gap: 8 }}>
            <button className="btn btn-primary" type="submit">Save changes</button>
            <Link className="btn" href={back}>Cancel</Link>
          </div>
        </form>
      )}
    </>
  );
}
