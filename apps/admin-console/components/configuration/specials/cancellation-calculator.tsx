'use client';

import { useMemo, useState } from 'react';

export type CancellationPolicyRow = {
  id: string;
  name: string;
  applies_to_role: string;
  free_cancellation_window_minutes: number;
  fee_type: string;
  fee_value: number;
  currency_code: string | null;
  fee_tiers: unknown;
  is_active: boolean;
};

type Tier = { minutes_before_pickup: number; fee: number };

function readTiers(raw: unknown): Tier[] {
  if (!raw) return [];
  let parsed: unknown = raw;
  if (typeof raw === 'string') {
    try {
      parsed = JSON.parse(raw);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(parsed)) return [];
  return parsed
    .map((tier) => {
      if (!tier || typeof tier !== 'object') return null;
      const entry = tier as Record<string, unknown>;
      const minutes = Number(entry.minutes_before_pickup ?? entry.minutes ?? 0);
      const fee = Number(entry.fee ?? entry.amount ?? 0);
      if (!Number.isFinite(minutes) || !Number.isFinite(fee)) return null;
      return { minutes_before_pickup: minutes, fee };
    })
    .filter((tier): tier is Tier => tier !== null);
}

/**
 * Works out the cancellation fee a policy would charge.
 *
 * The rules are the ones the platform applies: the free window wins, then
 * the flat fee, then a percentage of the quote, then the tier whose
 * threshold is the closest one still covered.
 */
export function calculateFee(
  policy: CancellationPolicyRow,
  minutesBeforePickup: number,
  quoteAmount: number,
): { fee: number; explanation: string } {
  const window = Number(policy.free_cancellation_window_minutes ?? 0);

  if (minutesBeforePickup >= window) {
    return {
      fee: 0,
      explanation: `Cancelled ${minutesBeforePickup} minutes before pickup, inside the free window of ${window} minutes.`,
    };
  }

  if (policy.fee_type === 'flat') {
    const fee = Number(policy.fee_value ?? 0);
    return {
      fee,
      explanation: `Flat fee of ${policy.currency_code ?? 'TZS'} ${fee.toLocaleString()} (${minutesBeforePickup} minutes before pickup, outside the ${window} minute window).`,
    };
  }

  if (policy.fee_type === 'percentage_of_quote') {
    const percentage = Number(policy.fee_value ?? 0);
    const fee = (Number(quoteAmount ?? 0) * percentage) / 100;
    return {
      fee,
      explanation: `${percentage}% of a ${quoteAmount.toLocaleString()} quote is ${fee.toLocaleString()}.`,
    };
  }

  const tiers = readTiers(policy.fee_tiers);
  if (tiers.length === 0) {
    return { fee: 0, explanation: 'This tiered policy has no tiers configured.' };
  }

  const covered = tiers
    .filter((tier) => minutesBeforePickup >= tier.minutes_before_pickup)
    .sort((a, b) => b.minutes_before_pickup - a.minutes_before_pickup);
  const tier =
    covered[0] ??
    tiers.reduce((lowest, entry) =>
      entry.minutes_before_pickup < lowest.minutes_before_pickup ? entry : lowest,
    );

  return {
    fee: tier.fee,
    explanation: `Tier for ${tier.minutes_before_pickup} minutes before pickup: ${tier.fee.toLocaleString()}.`,
  };
}

/**
 * The cancellation fee calculator.
 *
 * It lets an operator check the fee a policy would charge before the policy
 * goes live, without creating a booking.
 */
export function CancellationCalculator({ policies }: { policies: CancellationPolicyRow[] }) {
  const active = policies.filter((policy) => policy.is_active);
  const [selectedId, setSelectedId] = useState(active[0]?.id ?? policies[0]?.id ?? '');
  const [minutes, setMinutes] = useState(30);
  const [quote, setQuote] = useState(50000);

  const policy = policies.find((entry) => entry.id === selectedId) ?? null;
  const result = useMemo(
    () => (policy ? calculateFee(policy, minutes, quote) : null),
    [policy, minutes, quote],
  );

  if (policies.length === 0) {
    return (
      <div className="card card-pad">
        <h3 className="card-title">Fee calculator</h3>
        <p className="card-sub">No policies to test yet.</p>
      </div>
    );
  }

  return (
    <div className="card card-pad">
      <h3 className="card-title">Fee calculator</h3>
      <p className="card-sub">
        Check what a policy would charge before it goes live. Nothing here changes any data.
      </p>

      <div className="form" style={{ marginTop: 12 }}>
        <div className="field">
          <label htmlFor="calculator-policy">Policy</label>
          <select
            className="input"
            id="calculator-policy"
            onChange={(event) => setSelectedId(event.target.value)}
            value={selectedId}
          >
            {policies.map((entry) => (
              <option key={entry.id} value={entry.id}>
                {entry.name}
                {entry.is_active ? '' : ' (inactive)'}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <label htmlFor="calculator-minutes">Minutes before pickup</label>
          <input
            className="input"
            id="calculator-minutes"
            min={0}
            onChange={(event) => setMinutes(Number(event.target.value))}
            type="number"
            value={minutes}
          />
        </div>

        <div className="field">
          <label htmlFor="calculator-quote">Quote amount</label>
          <input
            className="input"
            id="calculator-quote"
            min={0}
            onChange={(event) => setQuote(Number(event.target.value))}
            type="number"
            value={quote}
          />
        </div>

        {result ? (
          <div className="calculator-result">
            <div className="small muted">Fee that would be charged</div>
            <div className="calculator-amount">
              {policy?.currency_code ?? 'TZS'} {result.fee.toLocaleString()}
            </div>
            <div className="small muted">{result.explanation}</div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
