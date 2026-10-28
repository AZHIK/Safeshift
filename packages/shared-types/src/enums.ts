import { Constants } from './database.generated.js';

export const USER_ROLES = Constants.public.Enums.user_role;
export type UserRole = (typeof USER_ROLES)[number];

export const DRIVER_VERIFICATION_STATUSES = Constants.public.Enums.driver_verification_status;
export type DriverVerificationStatus = (typeof DRIVER_VERIFICATION_STATUSES)[number];

export const DRIVER_RISK_TIERS = Constants.public.Enums.driver_risk_tier;
export type DriverRiskTier = (typeof DRIVER_RISK_TIERS)[number];

export const JOB_STATUSES = Constants.public.Enums.job_status;
export type JobStatus = (typeof JOB_STATUSES)[number];

export const PAYMENT_STATUSES = Constants.public.Enums.payment_status;
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

export const PAYMENT_METHODS = Constants.public.Enums.payment_method;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

export const EVIDENCE_TYPES = Constants.public.Enums.evidence_type;
export type EvidenceType = (typeof EVIDENCE_TYPES)[number];

export const AUDIT_ACTIONS = Constants.public.Enums.audit_action;
export type AuditAction = (typeof AUDIT_ACTIONS)[number];
