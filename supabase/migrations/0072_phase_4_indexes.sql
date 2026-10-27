-- ============================================================================
-- SafeShift — Phase 4 / Migration 0072
-- Query-path indexes for quotes, dispatch, tracking, ratings and disputes.
--
-- Partial indexes keep active-job and pending-offer lookups small. Geographic
-- columns use GIST so dispatch can answer ST_DWithin radius questions.
-- Indexes on partitioned parents (job_events, driver_locations) automatically
-- cascade to every current and future partition.
-- ============================================================================

-- Quote analytics and customer history.
create index idx_quote_requests_customer_requested
  on public.quote_requests (customer_id, requested_at desc);

create index idx_quote_requests_city_requested
  on public.quote_requests (city_id, requested_at desc);

create index idx_quote_requests_vehicle_type
  on public.quote_requests (vehicle_type_id);

create index idx_quote_requests_pickup_gist
  on public.quote_requests using gist (pickup_location);

create index idx_quote_requests_destination_gist
  on public.quote_requests using gist (destination_location);

create index idx_quotes_request
  on public.quotes (quote_request_id);

create index idx_quotes_created
  on public.quotes (created_at desc);

create index idx_quotes_expires
  on public.quotes (expires_at);

create index idx_quotes_promo_code
  on public.quotes (promo_code_id)
  where promo_code_id is not null;

-- Surge selection scans a narrow active window.
create index idx_surge_city_window
  on public.surge_multipliers (city_id, starts_at, ends_at);

create index idx_surge_zone_window
  on public.surge_multipliers (service_zone_id, starts_at, ends_at)
  where service_zone_id is not null;

create index idx_surge_vehicle_window
  on public.surge_multipliers (vehicle_type_id, starts_at, ends_at)
  where vehicle_type_id is not null;

-- Job lookup by participant, state and dispatch queue.
create index idx_jobs_customer_created
  on public.jobs (customer_id, created_at desc);

create index idx_jobs_driver_status
  on public.jobs (driver_id, status);

create index idx_jobs_status_created
  on public.jobs (status, created_at desc);

create index idx_jobs_city_status
  on public.jobs (city_id, status);

create index idx_jobs_scheduled_active
  on public.jobs (scheduled_at)
  where status in (
    'requested', 'quoted', 'matched', 'accepted',
    'heading_to_pickup', 'arrived', 'loading', 'in_transit'
  );

create index idx_jobs_quote
  on public.jobs (quote_id);

-- Stops and manifest.
create index idx_job_stops_location_gist
  on public.job_stops using gist (location);

create index idx_job_items_job
  on public.job_items (job_id);

-- Evidence and lifecycle.
create index idx_job_evidence_job
  on public.job_evidence (job_id);

create index idx_job_evidence_stop
  on public.job_evidence (stop_id)
  where stop_id is not null;

create index idx_job_status_history_job_created
  on public.job_status_history (job_id, created_at desc);

create index idx_job_status_history_location_gist
  on public.job_status_history using gist (location)
  where location is not null;

create index idx_job_events_job_created
  on public.job_events (job_id, created_at desc);

create index idx_job_events_type_created
  on public.job_events (event_type, created_at desc);

create index idx_job_events_location_gist
  on public.job_events using gist (location)
  where location is not null;

-- Cancellations and tracking.
create index idx_driver_locations_driver_recorded
  on public.driver_locations (driver_id, recorded_at desc);

create index idx_driver_locations_job_recorded
  on public.driver_locations (job_id, recorded_at desc)
  where job_id is not null;

create index idx_driver_locations_location_gist
  on public.driver_locations using gist (location);

-- Matching and offers.
create index idx_matching_attempts_job_started
  on public.matching_attempts (job_id, started_at desc);

create index idx_job_offers_driver_response
  on public.job_offers (driver_id, response, expires_at);

create index idx_job_offers_job_sequence
  on public.job_offers (job_id, offer_sequence);

create index idx_job_offers_pending
  on public.job_offers (expires_at)
  where response = 'pending';

create index idx_driver_acceptance_stats_updated
  on public.driver_acceptance_stats (updated_at desc);

-- Ratings and reports.
create index idx_rating_categories_role_order
  on public.rating_categories (applies_to_role, display_order);

create index idx_ratings_rated_created
  on public.ratings (rated_profile_id, created_at desc);

create index idx_ratings_job
  on public.ratings (job_id);

create index idx_rating_reports_status_created
  on public.rating_reports (status, created_at desc);

-- Disputes and conversation.
create index idx_disputes_job
  on public.disputes (job_id);

create index idx_disputes_status_priority_created
  on public.disputes (status, priority, created_at desc);

create index idx_disputes_raised_by_created
  on public.disputes (raised_by, created_at desc);

create index idx_dispute_messages_dispute_created
  on public.dispute_messages (dispute_id, created_at);

create index idx_dispute_attachments_dispute
  on public.dispute_attachments (dispute_id);

create index idx_dispute_attachments_message
  on public.dispute_attachments (message_id)
  where message_id is not null;

create index idx_dispute_resolutions_dispute_created
  on public.dispute_resolutions (dispute_id, created_at);

-- Recurring jobs.
create index idx_recurring_templates_business_active
  on public.recurring_job_templates (business_account_id, is_active);

create index idx_recurring_templates_vehicle
  on public.recurring_job_templates (vehicle_type_id);

create index idx_scheduled_jobs_status_due
  on public.scheduled_jobs (status, scheduled_for)
  where status = 'pending';

create index idx_scheduled_jobs_quote_request
  on public.scheduled_jobs (quote_request_id)
  where quote_request_id is not null;

create index idx_scheduled_jobs_job
  on public.scheduled_jobs (job_id)
  where job_id is not null;
