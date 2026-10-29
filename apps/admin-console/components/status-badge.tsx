import { titleize } from '@/lib/format';

const tones: Record<string, string> = {
  active: 'green', verified: 'green', approved: 'green', completed: 'green',
  resolved: 'green', paid: 'green', delivered: 'green', enabled: 'green',
  pending: 'amber', in_review: 'amber', investigating: 'amber', waiting_customer: 'amber',
  acknowledged: 'amber', processing: 'amber', open: 'red', rejected: 'red',
  failed: 'red', cancelled: 'gray', closed: 'gray', paused: 'gray', disabled: 'gray',
  urgent: 'red', high: 'red', critical: 'red', medium: 'amber', low: 'blue',
};

export function StatusBadge({ value }: { value: unknown }) {
  const text = String(value ?? 'unknown');
  return <span className={`badge badge-${tones[text] ?? 'blue'}`}>{titleize(text)}</span>;
}
