import type { JobStatus } from './enums.js';

/** Normal forward transitions. Terminal states have no normal forward path. */
export const JOB_STATUS_TRANSITIONS: Record<JobStatus, readonly JobStatus[]> = {
  requested: ['quoted', 'matched'],
  quoted: ['matched'],
  matched: ['accepted'],
  accepted: ['heading_to_pickup'],
  heading_to_pickup: ['arrived'],
  arrived: ['loading'],
  loading: ['in_transit'],
  in_transit: ['delivered', 'disputed'],
  delivered: ['completed', 'disputed'],
  completed: ['disputed'],
  cancelled: [],
  disputed: [],
};

/** Statuses that make a job effectively terminal for normal dispatch. */
export const TERMINAL_JOB_STATUSES = [
  'completed',
  'cancelled',
] as const satisfies readonly JobStatus[];

/** Statuses that block normal completion and need staff oversight. */
export const ESCALATED_JOB_STATUSES = ['disputed'] as const satisfies readonly JobStatus[];
