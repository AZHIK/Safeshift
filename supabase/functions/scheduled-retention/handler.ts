import { type AuthDeps, defaultAuthDeps, requireServiceRole } from '../_shared/auth.ts';
import { serviceClient, type SupabaseClient } from '../_shared/db.ts';
import { success } from '../_shared/response.ts';
import type { RequestContext } from '../_shared/types/index.ts';

export interface ScheduledRetentionDeps {
  auth?: AuthDeps;
  service?: SupabaseClient;
  now?: () => Date;
}

interface RetentionRow {
  table_name: string;
  rows_deleted: number | string;
}

interface StorageEntry {
  name: string;
  id: string | null;
  created_at: string | null;
}

const EXPORT_RETENTION_DAYS = 30;
const STORAGE_PAGE_SIZE = 1_000;

async function listAll(
  bucket: ReturnType<SupabaseClient['storage']['from']>,
  prefix: string,
): Promise<StorageEntry[]> {
  const entries: StorageEntry[] = [];
  for (let offset = 0;; offset += STORAGE_PAGE_SIZE) {
    const { data, error } = await bucket.list(prefix, {
      limit: STORAGE_PAGE_SIZE,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    });
    if (error) throw error;
    const page = (data ?? []) as StorageEntry[];
    entries.push(...page);
    if (page.length < STORAGE_PAGE_SIZE) break;
  }
  return entries;
}

function isExpired(entry: StorageEntry, cutoff: number): boolean {
  if (!entry.created_at) return false;
  const createdAt = Date.parse(entry.created_at);
  return Number.isFinite(createdAt) && createdAt < cutoff;
}

async function cleanupExpiredExportObjects(
  service: SupabaseClient,
  now: Date,
): Promise<number> {
  const bucket = service.storage.from('data-exports');
  const cutoff = now.getTime() - EXPORT_RETENTION_DAYS * 24 * 60 * 60 * 1_000;
  const paths: string[] = [];

  const root = await listAll(bucket, '');
  for (const entry of root) {
    if (entry.id) {
      if (isExpired(entry, cutoff)) paths.push(entry.name);
      continue;
    }

    const children = await listAll(bucket, entry.name);
    for (const child of children) {
      if (child.id && isExpired(child, cutoff)) {
        paths.push(`${entry.name}/${child.name}`);
      }
    }
  }

  let removed = 0;
  for (let index = 0; index < paths.length; index += 100) {
    const batch = paths.slice(index, index + 100);
    const { data, error } = await bucket.remove(batch);
    if (error) throw error;
    removed += data?.length ?? 0;
  }
  return removed;
}

export async function handle(
  req: Request,
  _ctx: RequestContext,
  deps: ScheduledRetentionDeps = {},
): Promise<Response> {
  await requireServiceRole(req, deps.auth ?? defaultAuthDeps());
  const service = deps.service ?? serviceClient();
  const now = deps.now ?? (() => new Date());
  const startedAt = now();

  const { data, error } = await service.rpc('apply_retention_policies');
  if (error) throw error;

  const policies = (data ?? []) as RetentionRow[];
  const rowsByTable: Record<string, number> = {};
  let totalRows = 0;
  for (const row of policies) {
    const count = Number(row.rows_deleted ?? 0);
    rowsByTable[row.table_name] = count;
    totalRows += count;
  }

  const { data: idempotencyDeleted, error: idempotencyError } = await service.rpc(
    'cleanup_idempotency_keys',
  );
  if (idempotencyError) throw idempotencyError;

  const storageObjectsDeleted = await cleanupExpiredExportObjects(service, startedAt);

  const { data: exportRecordsCleared, error: exportsError } = await service.rpc(
    'cleanup_expired_data_exports',
  );
  if (exportsError) throw exportsError;

  const { data: webhookEventsDeleted, error: webhookEventsError } = await service.rpc(
    'cleanup_payment_webhook_events',
  );
  if (webhookEventsError) throw webhookEventsError;

  return success({
    policies_applied: policies.length,
    rows_deleted_by_table: rowsByTable,
    total_rows_deleted: totalRows,
    idempotency_keys_deleted: Number(idempotencyDeleted ?? 0),
    expired_exports_deleted: storageObjectsDeleted,
    expired_export_records_cleared: Number(exportRecordsCleared ?? 0),
    webhook_events_deleted: Number(webhookEventsDeleted ?? 0),
    completed_at: now().toISOString(),
  });
}
