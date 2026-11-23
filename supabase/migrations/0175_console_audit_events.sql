alter type public.audit_action add value if not exists 'role_created';
alter type public.audit_action add value if not exists 'ticket_triaged';
alter type public.audit_action add value if not exists 'announcement_sent';
alter type public.audit_action add value if not exists 'regulator_export';
alter type public.audit_action add value if not exists 'government_request_opened';
alter type public.audit_action add value if not exists 'government_request_reviewed';
alter type public.audit_action add value if not exists 'government_request_exported';
