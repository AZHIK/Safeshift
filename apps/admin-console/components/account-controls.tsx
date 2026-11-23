import {
  reactivateAccountAction,
  reinstateDriverAction,
  suspendAccountAction,
  suspendDriverAction,
} from '@/app/(console)/users/actions';
import { deleteAccountAction } from '@/app/(console)/data/actions';
import { formatDate, titleize } from '@/lib/format';

import { ConfirmSubmit } from './confirm-submit';
import { DataTable } from './data-table';
import { RowMenu } from '@/components/row-menu';

export type HistoryRow = {
  occurred_at: string;
  action: string;
  actor_name: string;
  old_value: Record<string, unknown> | null;
  new_value: Record<string, unknown> | null;
};

const ACTION_LABEL: Record<string, string> = {
  user_suspended: 'Account suspended',
  user_reactivated: 'Account reactivated',
  driver_suspended: 'Driver suspended',
  driver_reinstated: 'Driver reinstated',
  fleet_suspended: 'Fleet suspended',
  fleet_reactivated: 'Fleet reactivated',
};

/** Suspend or reactivate the whole account (sign-in, sessions, profile). */
export function AccountStatusPanel({
  profileId,
  name,
  isActive,
  deactivationReason,
  deactivatedAt,
  back,
}: {
  profileId: string;
  name: string;
  isActive: boolean;
  deactivationReason: string | null;
  deactivatedAt: string | null;
  back: string;
}) {
  return (
    <section className="card card-pad" aria-label="Account status">
      <h2 className="card-title">Account</h2>
      {isActive ? (
        <>
          <p className="card-sub">
            Suspending signs {name} out everywhere and blocks sign-in until reactivated. Drivers must not be mid-job.
          </p>
          <form action={suspendAccountAction} className="form" style={{ marginTop: 8 }}>
            <input type="hidden" name="profile_id" value={profileId} />
            <input type="hidden" name="back" value={back} />
            <label className="field">
              Reason (kept in the audit log)
              <textarea className="input" name="reason" rows={2} required minLength={3} maxLength={500}
                placeholder="e.g. Fraudulent chargebacks, ticket #482" />
            </label>
            <ConfirmSubmit message={`Suspend ${name}? They will be signed out and unable to sign in.`}>
              Suspend account
            </ConfirmSubmit>
          </form>
        </>
      ) : (
        <>
          <div className="notice notice-error" style={{ marginTop: 8 }}>
            Suspended{deactivatedAt ? ` since ${formatDate(deactivatedAt)}` : ''}
            {deactivationReason ? `: ${deactivationReason}` : ''}
          </div>
          <form action={reactivateAccountAction} className="form">
            <input type="hidden" name="profile_id" value={profileId} />
            <input type="hidden" name="back" value={back} />
            <label className="field">
              Note (optional)
              <input className="input" name="note" maxLength={500} placeholder="Why the suspension is lifted" />
            </label>
            <button className="btn btn-primary" type="submit">
              Reactivate account
            </button>
          </form>
        </>
      )}
    </section>
  );
}

/** Driver-only suspension: no dispatch, but the account stays usable. */
export function DriverStatusPanel({
  driverId,
  name,
  verificationStatus,
  suspensionReason,
  suspendedAt,
  back,
}: {
  driverId: string;
  name: string;
  verificationStatus: string;
  suspensionReason: string | null;
  suspendedAt: string | null;
  back: string;
}) {
  const suspended = verificationStatus === 'suspended';
  return (
    <section className="card card-pad" aria-label="Driving status">
      <h2 className="card-title">Driving</h2>
      <p className="card-sub">
        Status: <strong>{titleize(verificationStatus)}</strong>. Only verified drivers are offered jobs.
      </p>
      {suspended ? (
        <>
          <div className="notice notice-error">
            Suspended from driving{suspendedAt ? ` since ${formatDate(suspendedAt)}` : ''}
            {suspensionReason ? `: ${suspensionReason}` : ''}
          </div>
          <form action={reinstateDriverAction} className="form">
            <input type="hidden" name="driver_id" value={driverId} />
            <input type="hidden" name="back" value={back} />
            <label className="field">
              Note (optional)
              <input className="input" name="note" maxLength={500} />
            </label>
            <button className="btn btn-primary" type="submit">
              Reinstate driver
            </button>
          </form>
        </>
      ) : (
        <form action={suspendDriverAction} className="form" style={{ marginTop: 8 }}>
          <input type="hidden" name="driver_id" value={driverId} />
          <input type="hidden" name="back" value={back} />
          <label className="field">
            Reason
            <textarea className="input" name="reason" rows={2} required minLength={3} maxLength={500}
              placeholder="e.g. Unsafe driving reported on job #…" />
          </label>
          <ConfirmSubmit message={`Suspend ${name} from driving? They go offline and get no jobs.`}>
            Suspend from driving
          </ConfirmSubmit>
        </form>
      )}
    </section>
  );
}

export function StatusHistory({ rows }: { rows: HistoryRow[] }) {
  return (
    <section className="card" aria-label="Status history">
      <div className="card-pad" style={{ paddingBottom: 0 }}>
        <h2 className="card-title">Status history</h2>
      </div>
      <DataTable
        columns={['When', 'What', 'By', 'Details']}
        empty="No suspensions or reactivations."
        actions={rows.map((_, i) => (
          <RowMenu key={i} items={[{ kind: 'link', label: 'Open audit log', href: '/audit' }]} />
        ))}
        rows={rows.map((r, i) => [
          <span key={`w${i}`} className="small nowrap">
            {formatDate(r.occurred_at)}
          </span>,
          ACTION_LABEL[r.action] ?? titleize(r.action),
          r.actor_name,
          <span key={`d${i}`} className="small">
            {String(r.new_value?.reason ?? r.new_value?.note ?? r.old_value?.reason ?? '')}
          </span>,
        ])}
      />
    </section>
  );
}

/** Permanently deletes the account (or erases it when it has history). */
export function DeleteAccountPanel({ profileId, name }: { profileId: string; name: string }) {
  return (
    <section className="card card-pad" aria-label="Delete account">
      <h2 className="card-title">Delete account</h2>
      <p className="card-sub">
        Accounts with no trips, payments or tickets are removed completely. Otherwise {name}&apos;s name, phone and email
        are erased and sign-in is blocked for good, while trips and payments stay for the records. This cannot be undone.
      </p>
      <form action={deleteAccountAction} className="form" style={{ marginTop: 8 }}>
        <input type="hidden" name="profile_id" value={profileId} />
        <label className="field">
          Reason (kept in the audit log)
          <textarea className="input" name="reason" rows={2} required minLength={3} maxLength={500} />
        </label>
        <ConfirmSubmit message={`Delete ${name}'s account? This cannot be undone.`}>Delete account</ConfirmSubmit>
      </form>
    </section>
  );
}
