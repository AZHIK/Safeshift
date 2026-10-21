-- ============================================================================
-- SafeShift — Phase 2 / Migration 0034
-- Access paths and partial uniqueness for verification, catalogue and fleet work.
-- ============================================================================

create unique index driver_documents_one_current_idx on public.driver_documents (driver_id, document_type_id) where is_current;
create index driver_documents_current_idx on public.driver_documents (driver_id, is_current) where is_current;
create index driver_documents_type_idx on public.driver_documents (document_type_id);
create index driver_documents_status_idx on public.driver_documents (verification_status);
create index driver_documents_expires_idx on public.driver_documents (expires_at);

create unique index vehicle_documents_one_current_idx on public.vehicle_documents (vehicle_id, document_type_id) where is_current;
create index vehicle_documents_current_idx on public.vehicle_documents (vehicle_id, is_current) where is_current;
create index vehicle_documents_type_idx on public.vehicle_documents (document_type_id);
create index vehicle_documents_status_idx on public.vehicle_documents (verification_status);
create index vehicle_documents_expires_idx on public.vehicle_documents (expires_at);

create index document_types_active_applies_to_idx on public.document_types (applies_to) where is_active;

create index verification_requests_queue_idx on public.verification_requests (status, priority) where status in ('pending', 'in_review');
create index verification_requests_assignee_idx on public.verification_requests (assigned_to, status);
create index verification_requests_driver_idx on public.verification_requests (driver_id);
create index verification_requests_vehicle_idx on public.verification_requests (vehicle_id);
create index verification_requests_business_idx on public.verification_requests (business_account_id);
create index verification_history_request_created_idx on public.verification_history (verification_request_id, created_at desc);
create index verification_history_driver_idx on public.verification_history (driver_id);
create index verification_history_vehicle_idx on public.verification_history (vehicle_id);
create index document_expiry_reminders_pending_idx on public.document_expiry_reminders (scheduled_for) where sent_at is null;
create index document_expiry_reminders_driver_document_idx on public.document_expiry_reminders (driver_document_id);
create index document_expiry_reminders_vehicle_document_idx on public.document_expiry_reminders (vehicle_document_id);

create index vehicle_types_active_idx on public.vehicle_types (is_active) where is_active;
create index vehicle_models_type_idx on public.vehicle_models (vehicle_type_id);
create index vehicles_country_idx on public.vehicles (country_id);
create index vehicles_owner_profile_idx on public.vehicles (owner_profile_id);
create index vehicles_owner_fleet_idx on public.vehicles (owner_fleet_id);
create index vehicles_owner_business_idx on public.vehicles (owner_business_account_id);
create index vehicles_type_idx on public.vehicles (vehicle_type_id);
create index vehicles_verification_status_idx on public.vehicles (verification_status);
create index vehicles_active_idx on public.vehicles (is_active) where is_active;

create index cargo_categories_parent_idx on public.cargo_categories (parent_category_id);
create index cargo_types_category_idx on public.cargo_types (category_id);
create index cargo_types_active_idx on public.cargo_types (is_active) where is_active;
create index cargo_restrictions_cargo_type_idx on public.cargo_restrictions (cargo_type_id);
create index cargo_restrictions_type_idx on public.cargo_restrictions (restriction_type);

create index fleets_country_idx on public.fleets (country_id);
create index fleets_owner_profile_idx on public.fleets (owner_profile_id);
create index fleets_active_idx on public.fleets (is_active) where is_active;
create unique index fleet_members_one_active_driver_idx on public.fleet_members (driver_id) where is_active;
create index fleet_members_fleet_idx on public.fleet_members (fleet_id);
create unique index fleet_vehicles_one_active_vehicle_idx on public.fleet_vehicles (vehicle_id) where is_active;
create index fleet_vehicles_fleet_idx on public.fleet_vehicles (fleet_id);
create unique index vehicle_assignments_one_active_vehicle_idx on public.vehicle_assignments (vehicle_id) where is_active;
create unique index vehicle_assignments_one_active_driver_idx on public.vehicle_assignments (driver_id) where is_active;
create index vehicle_assignments_assigned_at_idx on public.vehicle_assignments (assigned_at desc);
create index fleet_reports_fleet_generated_idx on public.fleet_reports (fleet_id, generated_at desc);

