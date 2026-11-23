import Link from 'next/link';
import { notFound } from 'next/navigation';

import { PageHeader } from '@/components/page-header';
import { RecordFields } from '@/components/record-form';
import { isTableName, type RecordColumn, requireRecordTable } from '@/lib/data-records';
import { titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

import { createRecordAction } from '../../actions';

export const dynamic = 'force-dynamic';

export default async function NewRecordPage({ params }: { params: Promise<{ table: string }> }) {
  const { table } = await params;
  if (!isTableName(table)) notFound();
  await requireRecordTable(table);
  const supabase = await createClient();
  const [cols, tables] = await Promise.all([
    supabase.rpc('admin_record_columns', { p_table: table }),
    supabase.rpc('admin_record_tables'),
  ]);
  if (cols.error?.code === '42P01') notFound();
  const block = ((tables.data ?? []) as { table_name: string; write_block: string | null }[]).find(
    (t) => t.table_name === table,
  )?.write_block;

  return (
    <>
      <PageHeader title={`Add to ${titleize(table)}`} actions={<Link className="btn" href={`/data/${table}`}>Cancel</Link>} />
      {cols.error ? <div className="notice notice-error">{cols.error.message}</div> : null}
      {block ? (
        <div className="notice notice-error">{block}</div>
      ) : (
        <form action={createRecordAction} className="card card-pad form">
          <input type="hidden" name="table" value={table} />
          <RecordFields columns={(cols.data ?? []) as RecordColumn[]} mode="create" />
          <div className="inline" style={{ gap: 8 }}>
            <button className="btn btn-primary" type="submit">Create record</button>
            <Link className="btn" href={`/data/${table}`}>Cancel</Link>
          </div>
        </form>
      )}
    </>
  );
}
