-- ============================================================================
-- SafeShift — Phase 1 / Migration 0002
-- Enumerated types used across Phase 1.
--
-- Enums are intentionally narrow. Later phases add new enums (job_status,
-- payment_status, vehicle_class, dispute_status, ...) in their own migrations.
-- ============================================================================

-- Who a person is on the platform. A profile has exactly one primary role;
-- additional capabilities (business membership, admin grants) live in
-- separate tables.
create type public.user_role as enum (
  'customer',
  'driver',
  'business',
  'admin',
  'fleet_owner'
);

-- Driver trust lifecycle. Only `verified` is dispatch-eligible.
create type public.driver_verification_status as enum (
  'pending',
  'verified',
  'rejected',
  're_verification_due',
  'suspended'
);

-- Risk tier gates job eligibility and the level of oversight applied.
create type public.driver_risk_tier as enum (
  'standard',
  'enhanced',
  'restricted'
);

-- Canonical audit actions for the append-only audit trail. Entity-specific
-- detail belongs in old_value/new_value JSON, not in new enum values.
create type public.audit_action as enum (
  'insert',
  'update',
  'delete',
  'login',
  'logout',
  'verification_approved',
  'verification_rejected',
  'payout_changed',
  'pricing_changed',
  'admin_override',
  'consent_granted',
  'consent_revoked',
  'user_suspended',
  'user_reactivated'
);
