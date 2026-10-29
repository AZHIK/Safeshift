import Link from 'next/link';

import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function SupportPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  await requireArea('support');
  const params = await searchParams;
  const status = params.status ?? '';
  const supabase = await createClient();
  let query = supabase
    .from('support_tickets')
    .select('id, ticket_number, subject, status, priority, created_at, updated_at, opened_by, assigned_to, support_categories(name), support_ticket_messages(id)')
    .order('created_at', { ascending: false })
    .limit(100);
  if (status) query = query.eq('status', status);
  const { data, error } = await query;

  return (
    <>
      <PageHeader
        title="Support tickets"
        description="Account, payment, app, trip, and verification support. Disputes are handled separately."
        actions={
          <>
            <Link className="btn" href="/support?status=open">Open</Link>
            <Link className="btn" href="/support?status=in_progress">In progress</Link>
            <Link className="btn" href="/support?status=waiting_customer">Waiting customer</Link>
            <Link className="btn" href="/support">All</Link>
          </>
        }
      />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      <div className="card">
        <DataTable
          columns={['Ticket', 'Subject', 'Category', 'Status', 'Priority', 'Messages', 'Updated', '']}
          rows={(data ?? []).map((ticket) => {
            const category = ticket.support_categories as { name?: string } | null;
            return [
              <div key="t"><span className="mono">{ticket.ticket_number}</span><div className="small muted">{shortId(ticket.opened_by)}</div></div>,
              ticket.subject,
              category?.name ?? 'Support',
              <StatusBadge key="s" value={ticket.status} />,
              <StatusBadge key="p" value={ticket.priority} />,
              ticket.support_ticket_messages?.length ?? 0,
              <span className="small muted" key="u">{formatDate(ticket.updated_at)}</span>,
              <Link className="btn btn-sm" href={`/support/${ticket.id}`} key="o">Open</Link>,
            ];
          })}
          empty="No support tickets match this filter."
        />
      </div>
    </>
  );
}
