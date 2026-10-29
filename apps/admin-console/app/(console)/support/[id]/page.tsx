import Link from 'next/link';
import { notFound } from 'next/navigation';

import { replyTicketAction, updateTicketAction } from '@/app/actions/admin';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export default async function SupportDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('support');
  const { id } = await params;
  const query = await searchParams;
  const supabase = await createClient();
  const { data: ticket, error } = await supabase
    .from('support_tickets')
    .select('*, support_categories(name), support_ticket_messages(*)')
    .eq('id', id)
    .maybeSingle();
  if (!ticket && !error) notFound();

  const messages = [...(ticket?.support_ticket_messages ?? [])].sort(
    (a, b) => Number(a.id) - Number(b.id),
  );
  const category = ticket?.support_categories as { name?: string } | null;

  return (
    <>
      <PageHeader
        title={ticket ? String(ticket.subject) : 'Ticket'}
        description={ticket ? `${ticket.ticket_number} · ${category?.name ?? 'Support'} · opened ${formatDate(ticket.created_at)}` : undefined}
        actions={<Link className="btn" href="/support">Back to queue</Link>}
      />
      <Notice searchParams={query} />
      {error ? <div className="notice notice-error">{error.message}</div> : null}
      {!ticket ? <div className="card table-empty">Ticket not found.</div> : (
        <div className="split">
          <div className="section-stack">
            <div className="card card-pad">
              <div className="inline" style={{ justifyContent: 'space-between', width: '100%' }}>
                <div>
                  <div className="small muted">Opened by</div>
                  <span className="mono">{shortId(ticket.opened_by)}</span>
                </div>
                <div>
                  <div className="small muted">Assigned to</div>
                  <span className="mono">{ticket.assigned_to ? shortId(ticket.assigned_to) : 'Unassigned'}</span>
                </div>
                <StatusBadge value={ticket.status} />
                <StatusBadge value={ticket.priority} />
              </div>
              {ticket.related_job_id ? <p className="small">Related job: <span className="mono">{shortId(ticket.related_job_id)}</span></p> : null}
              {ticket.related_dispute_id ? <p className="small">Related dispute: <span className="mono">{shortId(ticket.related_dispute_id)}</span></p> : null}
            </div>
            <div className="card card-pad">
              <h2 className="card-title">Conversation</h2>
              <p className="card-sub">Internal notes are highlighted and only visible to staff.</p>
              <div className="message-list" style={{ marginTop: 12 }}>
                {messages.length === 0 ? <div className="table-empty">No messages yet.</div> : messages.map((message) => (
                  <div className={`message ${message.is_internal_note ? 'internal' : ''}`} key={message.id}>
                    <div className="message-meta">
                      {message.is_internal_note ? 'Internal note · ' : ''}
                      {shortId(message.sender_profile_id)} · {formatDate(message.created_at)}
                    </div>
                    {message.message}
                  </div>
                ))}
              </div>
            </div>
            <div className="card card-pad">
              <h2 className="card-title">Reply</h2>
              <form action={replyTicketAction} className="form" style={{ marginTop: 10 }}>
                <input type="hidden" name="ticket_id" value={ticket.id} />
                <textarea className="input" name="message" placeholder="Write a reply to the customer…" required />
                <label className="inline small"><input type="checkbox" name="internal" /> Internal note</label>
                <button className="btn btn-primary" type="submit">Send reply</button>
              </form>
            </div>
          </div>
          <div className="card card-pad">
            <h2 className="card-title">Manage ticket</h2>
            <form action={updateTicketAction} className="form" style={{ marginTop: 10 }}>
              <input type="hidden" name="ticket_id" value={ticket.id} />
              <div className="field">
                <label>Status</label>
                <select className="input" name="status" defaultValue={ticket.status}>
                  {['open', 'in_progress', 'waiting_customer', 'resolved', 'closed'].map((value) => (
                    <option value={value} key={value}>{titleize(value)}</option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label>Priority</label>
                <select className="input" name="priority" defaultValue={ticket.priority}>
                  {['low', 'normal', 'high', 'urgent'].map((value) => (
                    <option value={value} key={value}>{titleize(value)}</option>
                  ))}
                </select>
              </div>
              <label className="inline small"><input type="checkbox" name="assign_to_me" /> Assign to me</label>
              <button className="btn btn-primary" type="submit">Save changes</button>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
