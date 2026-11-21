-- New lifecycle steps requested by the courier flow:
--   arrived -> cargo_verified -> loading -> in_transit
--           -> arrived_destination -> delivered -> completed
-- Enum values must be committed before functions can reference them, so this
-- migration only changes the types and constraints.

alter type public.job_status add value if not exists 'cargo_verified' before 'loading';
alter type public.job_status add value if not exists 'arrived_destination' before 'delivered';

alter table public.job_events
  drop constraint if exists job_events_type_check;

alter table public.job_events
  add constraint job_events_type_check check (
    event_type in (
      'created',
      'driver_assigned',
      'driver_arrived',
      'cargo_verified',
      'pickup_completed',
      'in_transit',
      'arrived_destination',
      'delivered',
      'completed',
      'cancelled',
      'route_deviation',
      'prolonged_stop',
      'sos',
      'chat_message',
      'call_made',
      'note'
    )
  );
