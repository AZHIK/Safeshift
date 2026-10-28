-- ============================================================================
-- 0113 — Phase 6: indexes
-- ============================================================================
-- Unique indexes are declared as table constraints in the table migrations.
-- This migration adds the remaining lookup, partial, and reconciliation indexes.
-- Indexes on partitioned parents automatically create child indexes.
-- ============================================================================

create index idx_push_tokens_profile_active
  on public.push_tokens (profile_id)
  where is_active = true;

create index idx_push_tokens_token_active
  on public.push_tokens (token)
  where is_active = true;

create index idx_notification_templates_code_channel_active
  on public.notification_templates (code, channel)
  where is_active = true;

create index idx_notification_log_profile_created
  on public.notification_log (profile_id, created_at desc);

create index idx_notification_log_status_open
  on public.notification_log (status)
  where status in ('pending', 'failed');

create index idx_notification_log_reference
  on public.notification_log (reference_type, reference_id);

create index idx_notification_log_public_id
  on public.notification_log (public_id);

create index idx_chat_threads_last_message_active
  on public.chat_threads (last_message_at desc)
  where status = 'active';

create index idx_chat_messages_thread_created
  on public.chat_messages (thread_id, created_at desc);

create index idx_chat_messages_sender_created
  on public.chat_messages (sender_profile_id, created_at desc);

create index idx_chat_attachments_message
  on public.chat_attachments (message_id);

create index idx_chat_attachments_thread
  on public.chat_attachments (thread_id);

create index idx_chat_read_receipts_profile
  on public.chat_read_receipts (profile_id);

create unique index emergency_contacts_one_primary_key
  on public.emergency_contacts (profile_id)
  where is_primary = true;

create index idx_emergency_contacts_profile
  on public.emergency_contacts (profile_id);

create index idx_incidents_open_severity
  on public.incidents (status, severity)
  where status in ('open', 'investigating');

create index idx_incidents_job
  on public.incidents (job_id)
  where job_id is not null;

create index idx_incidents_reported_created
  on public.incidents (reported_by, created_at desc);

create index idx_incidents_assigned
  on public.incidents (assigned_to)
  where assigned_to is not null;

create index idx_incident_actions_incident_created
  on public.incident_actions (incident_id, created_at desc);

create index idx_blocked_users_blocker
  on public.blocked_users (blocker_profile_id);

create index idx_prohibited_items_country_active
  on public.prohibited_items (country_id)
  where is_active = true;

create index idx_support_categories_country_order
  on public.support_categories (country_id, display_order)
  where is_active = true;

create index idx_support_tickets_opened_created
  on public.support_tickets (opened_by, created_at desc);

create index idx_support_tickets_active_status_priority
  on public.support_tickets (status, priority)
  where status in ('open', 'in_progress', 'waiting_customer');

create index idx_support_tickets_assigned
  on public.support_tickets (assigned_to)
  where assigned_to is not null;

create index idx_support_ticket_messages_ticket_created
  on public.support_ticket_messages (ticket_id, created_at);

create index idx_data_access_log_target_created
  on public.data_access_log (target_profile_id, created_at desc);

create index idx_data_access_log_accessor_created
  on public.data_access_log (accessor_profile_id, created_at desc);

create index idx_data_access_log_unauthorized
  on public.data_access_log (created_at desc)
  where was_authorized = false;

create index idx_data_subject_requests_active
  on public.data_subject_requests (status)
  where status in ('received', 'identity_verifying', 'in_progress');

create index idx_data_subject_requests_requester
  on public.data_subject_requests (requester_profile_id);

create index idx_daily_metrics_country_date
  on public.daily_metrics (country_id, metric_date desc);

create index idx_zone_metrics_zone_date
  on public.zone_metrics (service_zone_id, metric_date desc);

create index idx_driver_metrics_driver_date
  on public.driver_metrics (driver_id, metric_date desc);

create index idx_customer_metrics_customer_date
  on public.customer_metrics (customer_id, metric_date desc);

create index idx_demand_snapshots_zone_time
  on public.demand_snapshots (service_zone_id, snapshot_at desc);
