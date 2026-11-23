import { describe, expect, it } from 'vitest';

import { auditEntryItems, type AuditEntry } from '@/components/configuration/audit-history-button';

const entry: AuditEntry = {
  entry_id: 'e1',
  created_at: '2026-11-01T10:00:00Z',
  actor_id: 'u1',
  actor_name: 'Asha',
  action: 'update',
  old_value: { rate: 1 },
  new_value: { rate: 2 },
  source: 'console',
};

describe('auditEntryItems', () => {
  it('links the actor and never offers edit or delete', () => {
    const items = auditEntryItems(entry);
    expect(items[0]).toEqual({ kind: 'link', label: 'View actor', href: '/users/u1' });
    expect(items.find((i) => i.label === 'Edit or delete')?.kind).toBe('disabled');
    expect(items.some((i) => i.kind === 'form')).toBe(false);
  });

  it('omits the actor link for system entries', () => {
    expect(auditEntryItems({ ...entry, actor_id: null }).some((i) => i.label === 'View actor')).toBe(false);
  });
});
