/** Tables allowed in the Phase 6 Realtime publication. */
export const REALTIME_TABLES = [
  'jobs',
  'driver_locations',
  'job_events',
  'chat_messages',
  'notification_log',
] as const;

export type RealtimeTable = (typeof REALTIME_TABLES)[number];

/** The only Realtime table with a restricted column set. */
export const REALTIME_COLUMN_SUBSETS = {
  driver_locations: ['driver_id', 'job_id', 'location', 'heading', 'speed_kph', 'recorded_at'],
} as const satisfies Partial<Record<RealtimeTable, readonly string[]>>;

export type RealtimeEvent = 'INSERT' | 'UPDATE' | 'DELETE';

export interface RealtimeEnvelope<T extends RealtimeTable, R = Record<string, unknown>> {
  table: T;
  eventType: RealtimeEvent;
  new: R | null;
  old: Partial<R> | null;
}
