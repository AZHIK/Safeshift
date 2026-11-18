'use client';

import { useState } from 'react';

export type ReferenceCount = {
  label: string;
  count: number;
  blocking?: boolean;
};

/**
 * The confirmation an operator has to pass before a configuration row is
 * deactivated.
 *
 * Deactivating a row changes what the apps offer immediately, so the
 * operator has to type DEACTIVATE and read what is attached to the row first.
 */
export function DeactivateConfirmDialog({
  open,
  recordName,
  singular,
  impact,
  references,
  onConfirm,
  onClose,
  busy = false,
  error,
}: {
  open: boolean;
  recordName: string;
  singular: string;
  impact?: string;
  references?: ReferenceCount[];
  onConfirm: (reason: string) => void;
  onClose: () => void;
  busy?: boolean;
  error?: string | null;
}) {
  const [confirmation, setConfirmation] = useState('');
  const [reason, setReason] = useState('');

  if (!open) return null;

  const ready = confirmation.trim().toUpperCase() === 'DEACTIVATE';
  const blocking = (references ?? []).filter((reference) => reference.blocking !== false);

  return (
    <div
      aria-modal="true"
      className="dialog-backdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !busy) onClose();
      }}
      role="dialog"
    >
      <div className="dialog">
        <div className="dialog-head">
          <div>
            <h2 className="dialog-title">Deactivate this {singular}?</h2>
            <p className="small muted">{recordName}</p>
          </div>
          <button
            aria-label="Close"
            className="btn btn-sm"
            disabled={busy}
            onClick={onClose}
            type="button"
          >
            ✕
          </button>
        </div>

        <div className="dialog-body">
          {error ? <div className="notice notice-error">{error}</div> : null}

          <div className="notice notice-info">
            {impact ??
              `This ${singular} will stop appearing in the apps straight away. Existing bookings keep it.`}
          </div>

          {blocking.length > 0 ? (
            <div className="notice notice-error">
              <strong>This {singular} is still in use.</strong>
              <ul className="small" style={{ margin: '6px 0 0', paddingLeft: 18 }}>
                {blocking.map((reference) => (
                  <li key={reference.label}>
                    {reference.count} {reference.label}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {(references ?? []).filter((reference) => reference.blocking === false).length > 0 ? (
            <p className="small muted">
              Also attached to:{' '}
              {(references ?? [])
                .filter((reference) => reference.blocking === false)
                .map((reference) => `${reference.count} ${reference.label}`)
                .join(', ')}
              .
            </p>
          ) : null}

          <div className="field">
            <label htmlFor="deactivate-reason">Reason (optional)</label>
            <textarea
              className="input"
              id="deactivate-reason"
              onChange={(event) => setReason(event.target.value)}
              placeholder="Recorded in the audit trail."
              rows={2}
              value={reason}
            />
          </div>

          <div className="field">
            <label htmlFor="deactivate-confirmation">
              Type <strong>DEACTIVATE</strong> to confirm
            </label>
            <input
              autoComplete="off"
              className="input"
              id="deactivate-confirmation"
              onChange={(event) => setConfirmation(event.target.value)}
              placeholder="DEACTIVATE"
              value={confirmation}
            />
          </div>
        </div>

        <div className="dialog-foot">
          <button className="btn" disabled={busy} onClick={onClose} type="button">
            Cancel
          </button>
          <button
            className="btn btn-danger"
            disabled={!ready || busy}
            onClick={() => onConfirm(reason.trim())}
            type="button"
          >
            {busy ? 'Deactivating…' : 'Deactivate'}
          </button>
        </div>
      </div>
    </div>
  );
}
