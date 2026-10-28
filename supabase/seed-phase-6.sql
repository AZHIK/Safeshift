-- ============================================================================
-- PHASE 6 SEED — run after seed-phase-5.sql.
-- ============================================================================
-- Fixed UUID prefixes:
--   7a… user_devices        7b… push_tokens
--   7c… notification_templates
--   7d… notification_preferences
--   7e… chat_threads        7f… incidents
--   8a… blocked_users       8b… prohibited_items
--   8c… support_categories  8d… support_tickets
--   8e… retention_policies  8f… data_subject_requests
--   9a… emergency_contacts  9b… chat_attachments
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Devices and push tokens
-- ----------------------------------------------------------------------------
insert into public.user_devices (
  id, profile_id, device_id, device_type, device_name, os_version,
  app_version, push_token, push_provider, last_seen_at
) values
  ('7a000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001',
   'phase6-customer-device', 'android', 'Tecno Camon', 'Android 14',
   '6.0.0', 'fcm-customer-phase6', 'fcm', now() - interval '5 minutes'),
  ('7a000000-0000-4000-8000-000000000002',
   'd0000000-0000-4000-8000-000000000001',
   'phase6-driver-device', 'android', 'Samsung A15', 'Android 14',
   '6.0.0', 'fcm-driver-phase6', 'fcm', now() - interval '2 minutes')
on conflict (profile_id, device_id) do nothing;

insert into public.push_tokens (
  id, profile_id, device_id, token, provider, platform,
  app_version, is_active, last_used_at
) values
  ('7b000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001',
   '7a000000-0000-4000-8000-000000000001',
   'fcm-customer-phase6', 'fcm', 'android', '6.0.0', true, now() - interval '5 minutes'),
  ('7b000000-0000-4000-8000-000000000002',
   'd0000000-0000-4000-8000-000000000001',
   '7a000000-0000-4000-8000-000000000002',
   'fcm-driver-phase6', 'fcm', 'android', '6.0.0', true, now() - interval '2 minutes')
on conflict (profile_id, device_id) do nothing;

-- ----------------------------------------------------------------------------
-- 2. Notification templates (18 = 12 push + 3 SMS + 3 email)
-- ----------------------------------------------------------------------------
insert into public.notification_templates (
  id, country_id, language_id, code, channel, title_template,
  body_template, variables, deep_link_template, is_active
) values
  -- Push — Swahili
  ('7c000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'job_offer', 'push', 'Kazi mpya karibu nawe', 'Kazi mpya ya {vehicle_type} iko karibu. ETA {eta_minutes} dakika. Gharama: {fare}.', array['vehicle_type','eta_minutes','fare'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'trip_started', 'push', 'Safari imeanza', 'Safari yako na dereva {driver_name} imeanza. Fuatilia moja kwa moja.', array['driver_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'trip_completed', 'push', 'Safari imekamilika', 'Mizigo yako imefika. Asante kwa kutumia SafeShift, {customer_name}.', array['customer_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'payment_received', 'push', 'Malipo yamepokelewa', 'Malipo ya {amount} {currency} kwa kazi {job_id} yamepokelewa.', array['amount','currency','job_id'], 'safeshift://payment/{payment_id}', true),
  ('7c000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'document_expiry', 'push', 'Hati inakaribia kuisha', 'Hati yako ya {document_name} inaisha tarehe {expiry_date}. Tafadhali sasisha.', array['document_name','expiry_date'], 'safeshift://profile/documents', true),
  ('7c000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'emergency_alert', 'push', 'Tahadhari ya usalama', 'Tukio la usalama limeripotiwa kwenye kazi {job_id}. Timu yetu inafuatilia.', array['job_id'], 'safeshift://incident/{incident_id}', true),
  -- Push — English
  ('7c000000-0000-4000-8000-000000000007', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'job_offer', 'push', 'New job nearby', 'A new {vehicle_type} job is nearby. ETA {eta_minutes} minutes. Payout: {fare}.', array['vehicle_type','eta_minutes','fare'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000008', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'trip_started', 'push', 'Trip started', 'Your trip with {driver_name} has started. Track it live.', array['driver_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000009', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'trip_completed', 'push', 'Trip completed', 'Your cargo has arrived. Thank you for using SafeShift, {customer_name}.', array['customer_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000010', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'payment_received', 'push', 'Payment received', 'Payment of {amount} {currency} for job {job_id} has been received.', array['amount','currency','job_id'], 'safeshift://payment/{payment_id}', true),
  ('7c000000-0000-4000-8000-000000000011', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'document_expiry', 'push', 'Document expiring', 'Your {document_name} expires on {expiry_date}. Please update it.', array['document_name','expiry_date'], 'safeshift://profile/documents', true),
  ('7c000000-0000-4000-8000-000000000012', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'emergency_alert', 'push', 'Safety alert', 'A safety incident was reported on job {job_id}. Our team is responding.', array['job_id'], 'safeshift://incident/{incident_id}', true),
  -- SMS — Swahili
  ('7c000000-0000-4000-8000-000000000013', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'job_offer', 'sms', null, 'SafeShift: Kazi mpya karibu. ETA {eta_minutes} dakika. Fungua app kukubali.', array['eta_minutes','job_id'], null, true),
  ('7c000000-0000-4000-8000-000000000014', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'trip_started', 'sms', null, 'SafeShift: Safari ya {job_id} imeanza. Fuatilia kwenye app.', array['job_id'], null, true),
  ('7c000000-0000-4000-8000-000000000015', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000002', 'payment_received', 'sms', null, 'SafeShift: Malipo ya {amount} {currency} yamepokelewa. Asante.', array['amount','currency'], null, true),
  -- Email — English
  ('7c000000-0000-4000-8000-000000000016', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'trip_completed', 'email', 'Your SafeShift trip is complete', 'Hello {customer_name}, your cargo for job {job_id} has arrived. Thank you for choosing SafeShift.', array['customer_name','job_id'], 'safeshift://job/{job_id}', true),
  ('7c000000-0000-4000-8000-000000000017', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'payment_received', 'email', 'Payment receipt', 'We received {amount} {currency} for job {job_id}. Your receipt is available in the app.', array['amount','currency','job_id'], 'safeshift://payment/{payment_id}', true),
  ('7c000000-0000-4000-8000-000000000018', '33333333-0000-4000-8000-000000000001', '22222222-0000-4000-8000-000000000001', 'document_expiry', 'email', 'Action required: document expiring', 'Your {document_name} expires on {expiry_date}. Please upload a replacement.', array['document_name','expiry_date'], 'safeshift://profile/documents', true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 3. Notification preferences (customer c1, push channel)
-- ----------------------------------------------------------------------------
insert into public.notification_preferences (
  id, profile_id, category, channel, is_enabled, quiet_hours_start,
  quiet_hours_end, timezone
) values
  ('7d000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'job_updates', 'push', true, null, null, 'Africa/Dar_es_Salaam'),
  ('7d000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', 'payment', 'push', true, null, null, 'Africa/Dar_es_Salaam'),
  ('7d000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', 'promotions', 'push', false, null, null, 'Africa/Dar_es_Salaam'),
  ('7d000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000001', 'safety_alerts', 'push', true, null, null, 'Africa/Dar_es_Salaam'),
  ('7d000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000001', 'chat', 'push', true, '22:00', '07:00', 'Africa/Dar_es_Salaam'),
  ('7d000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000001', 'system', 'push', true, null, null, 'Africa/Dar_es_Salaam')
on conflict (profile_id, category, channel) do nothing;

-- ----------------------------------------------------------------------------
-- 4. Chat threads
-- ----------------------------------------------------------------------------
insert into public.chat_threads (id, job_id, status, archived_at)
values
  ('7e000000-0000-4000-8000-000000000001',
   '4f000000-0000-4000-8000-000000000001', 'read_only', null),
  ('7e000000-0000-4000-8000-000000000002',
   '4f000000-0000-4000-8000-000000000002', 'active', null)
on conflict (job_id) do nothing;

do $$
declare
  v_m1 bigint;
  v_m2 bigint;
  v_m3 bigint;
  v_m4 bigint;
  v_m5 bigint;
  v_m6 bigint;
  v_m7 bigint;
  v_m8 bigint;
begin
  if not exists (
    select 1 from public.chat_messages
     where thread_id = '7e000000-0000-4000-8000-000000000001'
  ) then
    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body, metadata, created_at)
    values ('7e000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'text', 'Habari, dereva yuko njiani?', '{}', now() - interval '3 days' + interval '15 minutes')
    returning id into v_m1;

    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body, metadata, created_at)
    values ('7e000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'text', 'Ndiyo, nimefika Mlimani City.', '{}', now() - interval '3 days' + interval '20 minutes')
    returning id into v_m2;

    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body, metadata, created_at)
    values ('7e000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'text', 'Asante sana.', '{}', now() - interval '3 days' + interval '25 minutes')
    returning id into v_m3;

    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body, metadata, created_at)
    values ('7e000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'image', null, '{"caption":"Parcel at reception"}', now() - interval '3 days' + interval '30 minutes')
    returning id into v_m4;

    insert into public.chat_attachments (id, message_id, thread_id, storage_path, file_mime_type, file_size_bytes)
    values ('9b000000-0000-4000-8000-000000000001', v_m4, '7e000000-0000-4000-8000-000000000001', 'phase6/thread-1/receipt.jpg', 'image/jpeg', 240000)
    on conflict (id) do nothing;

    insert into public.chat_read_receipts (thread_id, profile_id, last_read_message_id, last_read_at)
    values
      ('7e000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', v_m3, now() - interval '3 days' + interval '26 minutes'),
      ('7e000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', v_m4, now() - interval '3 days' + interval '31 minutes')
    on conflict (thread_id, profile_id) do nothing;
  end if;

  if not exists (
    select 1 from public.chat_messages
     where thread_id = '7e000000-0000-4000-8000-000000000002'
  ) then
    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body, metadata, created_at)
    values ('7e000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000002', 'text', 'I have arrived at the pickup point.', '{}', now() - interval '110 minutes')
    returning id into v_m5;

    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body, metadata, created_at)
    values ('7e000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000003', 'text', 'Sawa, nakuja kwa dakika tano.', '{}', now() - interval '105 minutes')
    returning id into v_m6;

    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body, metadata, created_at)
    values ('7e000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000002', 'location', null, '{"lat":-6.7924,"lng":39.2083}', now() - interval '100 minutes')
    returning id into v_m7;

    insert into public.chat_messages (thread_id, sender_profile_id, message_type, body, metadata, created_at)
    values ('7e000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000003', 'text', 'Nimefika.', '{}', now() - interval '95 minutes')
    returning id into v_m8;

    insert into public.chat_attachments (id, message_id, thread_id, storage_path, file_mime_type, file_size_bytes)
    values ('9b000000-0000-4000-8000-000000000002', v_m8, '7e000000-0000-4000-8000-000000000002', 'phase6/thread-2/delivery.jpg', 'image/jpeg', 180000)
    on conflict (id) do nothing;

    insert into public.chat_read_receipts (thread_id, profile_id, last_read_message_id, last_read_at)
    values
      ('7e000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000002', v_m7, now() - interval '99 minutes'),
      ('7e000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000003', v_m8, now() - interval '94 minutes')
    on conflict (thread_id, profile_id) do nothing;
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- 5. Emergency contact
-- ----------------------------------------------------------------------------
insert into public.emergency_contacts (
  id, profile_id, name, phone, relationship, is_primary,
  notify_on_trip_start, notify_on_sos
) values
  ('9a000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001',
   'Mama Juma', '+255754000001', 'parent', true, true, true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 6. Incidents and actions
-- ----------------------------------------------------------------------------
insert into public.incidents (
  id, job_id, reported_by, incident_type, severity, status, description,
  location, occurred_at, assigned_to, resolved_at, resolution_summary
) values
  ('7f000000-0000-4000-8000-000000000001',
   '4f000000-0000-4000-8000-000000000002',
   'c0000000-0000-4000-8000-000000000002',
   'security', 'high', 'open',
   'Dereva alisimamishwa na watu wasiojulikana karibu na Tazara. Hakuna majeruhi.',
   extensions.st_setsrid(extensions.st_makepoint(39.2500, -6.8500), 4326)::extensions.geography,
   now() - interval '1 hour',
   'a0000000-0000-4000-8000-000000000003',
   null, null),
  ('7f000000-0000-4000-8000-000000000002',
   '4f000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000001',
   'damage', 'medium', 'resolved',
   'Kreti moja ilipasuka wakati wa upakuaji. Mizigo yote ilifika.',
   extensions.st_setsrid(extensions.st_makepoint(39.2080, -6.7920), 4326)::extensions.geography,
   now() - interval '3 days' + interval '50 minutes',
   'a0000000-0000-4000-8000-000000000002',
   now() - interval '2 days',
   'Dereva alitoa picha za uharibifu; fidia ndogo ilikubaliwa na mteja.')
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from public.incident_actions
     where incident_id = '7f000000-0000-4000-8000-000000000002'
  ) then
    insert into public.incident_actions (incident_id, action_type, actor_id, to_status, notes, metadata, created_at)
    values ('7f000000-0000-4000-8000-000000000002', 'created',
            'c0000000-0000-4000-8000-000000000001', 'open',
            'Incident reported from the delivery screen.',
            '{"source":"customer_app"}', now() - interval '3 days' + interval '51 minutes');

    insert into public.incident_actions (incident_id, action_type, actor_id, from_status, to_status, notes, metadata, created_at)
    values ('7f000000-0000-4000-8000-000000000002', 'resolved',
            'a0000000-0000-4000-8000-000000000002', 'investigating', 'resolved',
            'Photos reviewed and goodwill compensation agreed.',
            '{"compensation":"5000 TZS"}', now() - interval '2 days');
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- 7. Blocked user and prohibited items
-- ----------------------------------------------------------------------------
insert into public.blocked_users (
  id, blocker_profile_id, blocked_profile_id, reason, scope, job_id
) values
  ('8a000000-0000-4000-8000-000000000001',
   'c0000000-0000-4000-8000-000000000002',
   'd0000000-0000-4000-8000-000000000003',
   'Repeated late-arrival concerns on this job.', 'job_specific',
   '4f000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;

insert into public.prohibited_items (
  id, country_id, category, name, description, legal_reference, severity, is_active
) values
  ('8b000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'weapons', 'Firearms and ammunition', 'Firearms, ammunition, and military-grade weapons.', 'Tanzania Firearms and Ammunition Control Act', 'prohibited', true),
  ('8b000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'drugs', 'Narcotics and controlled substances', 'Illegal narcotics and controlled pharmaceutical substances.', 'Tanzania Drugs and Prevention of Illicit Traffic in Drugs Act', 'prohibited', true),
  ('8b000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'hazardous_materials', 'Explosives and hazardous chemicals', 'Explosives, flammable gases, and toxic industrial chemicals.', 'Tanzania Occupational Safety and Health Act', 'requires_licence', true),
  ('8b000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', 'live_animals', 'Live animals', 'Live animals require a licensed livestock carrier and veterinary permit.', 'Tanzania Animal Diseases Act', 'requires_licence', true),
  ('8b000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', 'cash', 'Large cash consignments', 'Cash above the regulatory threshold requires a licensed cash-in-transit provider.', 'Bank of Tanzania cash handling rules', 'requires_licence', true),
  ('8b000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', 'illegal_goods', 'Wildlife products', 'Protected wildlife products and trophies are prohibited.', 'Tanzania Wildlife Conservation Act', 'prohibited', true),
  ('8b000000-0000-4000-8000-000000000007', '33333333-0000-4000-8000-000000000001', 'illegal_goods', 'Ivory and elephant products', 'Raw or worked ivory and other elephant products are prohibited.', 'CITES and Tanzania Wildlife Conservation Act', 'prohibited', true),
  ('8b000000-0000-4000-8000-000000000008', '33333333-0000-4000-8000-000000000001', 'illegal_goods', 'Counterfeit goods', 'Counterfeit branded goods and unlicensed replicas.', 'Tanzania Fair Competition Act', 'prohibited', true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 8. Support categories, tickets, messages
-- ----------------------------------------------------------------------------
insert into public.support_categories (
  id, country_id, code, name, description, display_order, is_active
) values
  ('8c000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'account_access', 'Account access', 'Login, OTP, and account recovery issues.', 10, true),
  ('8c000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'payment_issue', 'Payment issue', 'Payments, refunds, and wallet problems.', 20, true),
  ('8c000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'app_bug', 'App bug', 'Crashes, display defects, and broken flows.', 30, true),
  ('8c000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', 'driver_behavior', 'Driver behaviour', 'Service quality and conduct concerns.', 40, true),
  ('8c000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', 'feature_request', 'Feature request', 'Product ideas and new capability requests.', 50, true)
on conflict (id) do nothing;

insert into public.support_tickets (
  id, country_id, ticket_number, opened_by, assigned_to, category_id,
  subject, status, priority, related_job_id, related_dispute_id,
  sla_due_at, resolved_at, closed_at, satisfaction_rating, created_at
) values
  ('8d000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001',
   'TKT-2026-000001', 'c0000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000003', '8c000000-0000-4000-8000-000000000002',
   'M-Pesa payment not reflected', 'open', 'high',
   '4f000000-0000-4000-8000-000000000001', null,
   now() + interval '4 hours', null, null, null, now() - interval '2 hours'),
  ('8d000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001',
   'TKT-2026-000002', 'c0000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000003', '8c000000-0000-4000-8000-000000000005',
   'Add scheduled pickups', 'closed', 'normal',
   null, null, now() - interval '6 days', now() - interval '5 days',
   now() - interval '4 days', 5, now() - interval '7 days')
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from public.support_ticket_messages
     where ticket_id = '8d000000-0000-4000-8000-000000000001'
  ) then
    insert into public.support_ticket_messages (ticket_id, sender_profile_id, message, is_internal_note, attachments, created_at)
    values
      ('8d000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
       'I paid with M-Pesa but the job still shows payment pending. The reference is QK72HD91.', false, '{}', now() - interval '2 hours'),
      ('8d000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003',
       'Checking the payment provider reference and will reconcile with finance.', true, '{}', now() - interval '110 minutes'),
      ('8d000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
       'Asante, I will wait for the update.', false, '{}', now() - interval '100 minutes');
  end if;

  if not exists (
    select 1 from public.support_ticket_messages
     where ticket_id = '8d000000-0000-4000-8000-000000000002'
  ) then
    insert into public.support_ticket_messages (ticket_id, sender_profile_id, message, is_internal_note, attachments, created_at)
    values
      ('8d000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000003',
       'It would help to schedule recurring pickup jobs from the app.', false, '{}', now() - interval '7 days'),
      ('8d000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003',
       'Thanks for the suggestion. We have added recurring jobs to the roadmap.', false, '{}', now() - interval '6 days');
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- 9. Data access log seed (purpose marker keeps counts repeatable)
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from public.data_access_log where purpose = 'phase6_seed'
  ) then
    insert into public.data_access_log (
      accessor_profile_id, accessor_role, target_profile_id,
      target_table, target_field, target_id, access_type,
      purpose, was_authorized, created_at
    ) values
      ('a0000000-0000-4000-8000-000000000001', 'admin', 'c0000000-0000-4000-8000-000000000001',
       'profiles', 'phone,email,full_name', 'c0000000-0000-4000-8000-000000000001', 'read',
       'phase6_seed', true, now() - interval '6 hours'),
      ('a0000000-0000-4000-8000-000000000002', 'admin', 'd0000000-0000-4000-8000-000000000001',
       'driver_documents', 'document_number,file_path', 'd0000000-0000-4000-8000-000000000001', 'read',
       'phase6_seed', true, now() - interval '5 hours'),
      ('a0000000-0000-4000-8000-000000000002', 'admin', 'd0000000-0000-4000-8000-000000000001',
       'vehicle_documents', 'document_number,file_path', 'd0000000-0000-4000-8000-000000000001', 'read',
       'phase6_seed', true, now() - interval '4 hours'),
      ('a0000000-0000-4000-8000-000000000003', 'admin', 'c0000000-0000-4000-8000-000000000002',
       'support_tickets', 'subject', '8d000000-0000-4000-8000-000000000001', 'read',
       'phase6_seed', true, now() - interval '3 hours'),
      ('a0000000-0000-4000-8000-000000000001', 'admin', 'c0000000-0000-4000-8000-000000000001',
       'profiles', 'phone,email,full_name', 'c0000000-0000-4000-8000-000000000001', 'export',
       'phase6_seed', true, now() - interval '2 hours');
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- 10. Retention policies
-- ----------------------------------------------------------------------------
insert into public.retention_policies (
  id, table_name, retention_period, action, is_active, notes
) values
  ('8e000000-0000-4000-8000-000000000001', 'driver_locations', interval '90 days', 'delete', true, 'Drop monthly partitions, then delete default-partition leftovers.'),
  ('8e000000-0000-4000-8000-000000000002', 'job_events', interval '5 years', 'delete', true, 'Partition-drop only because job_events is append-only.'),
  ('8e000000-0000-4000-8000-000000000003', 'audit_log', interval '7 years', 'delete', true, 'Private audit partitions; partition-drop only.'),
  ('8e000000-0000-4000-8000-000000000004', 'chat_messages', interval '2 years', 'delete', true, 'Post-completion retention approximated by message created_at; archived threads are never hard-deleted by chat UI.'),
  ('8e000000-0000-4000-8000-000000000005', 'notification_log', interval '24 months', 'delete', true, 'PDPC-aligned notification retention.'),
  ('8e000000-0000-4000-8000-000000000006', 'data_access_log', interval '7 years', 'delete', true, 'Seven-year PDPC accountability period.'),
  ('8e000000-0000-4000-8000-000000000007', 'demand_snapshots', interval '90 days', 'delete', true, 'Five-minute demand buckets outside 90 days are removed.'),
  ('8e000000-0000-4000-8000-000000000008', 'daily_metrics', interval '100 years', 'archive', true, 'Indefinite retention; archive action is a no-op in Phase 6.')
on conflict (table_name) do nothing;

-- ----------------------------------------------------------------------------
-- 11. Data subject request
-- ----------------------------------------------------------------------------
insert into public.data_subject_requests (
  id, request_number, requester_profile_id, request_type, status,
  reason, requested_at, assigned_to
) values
  ('8f000000-0000-4000-8000-000000000001', 'DSR-2026-000001',
   'c0000000-0000-4000-8000-000000000001', 'export', 'received',
   'Customer requested a copy of their account and trip history.',
   now() - interval '1 day', 'a0000000-0000-4000-8000-000000000001')
on conflict (request_number) do nothing;

-- ----------------------------------------------------------------------------
-- 12. Seven days of Dar es Salaam daily metrics
-- ----------------------------------------------------------------------------
insert into public.daily_metrics (
  metric_date, country_id, city_id, jobs_created, jobs_completed, jobs_cancelled,
  gross_booking_value, net_revenue, currency_code,
  active_customers, active_drivers, new_customers, new_drivers,
  avg_acceptance_rate, avg_completion_minutes, avg_cancellation_rate,
  avg_rating, computed_at
)
select
  current_date - g,
  '33333333-0000-4000-8000-000000000001',
  '55555555-0000-4000-8000-000000000001',
  20 + g,
  16 + g,
  1 + (g % 2),
  500000 + (g * 15000),
  60000 + (g * 1800),
  'TZS',
  15 + (g % 4),
  10 + (g % 3),
  2,
  g % 2,
  0.8600,
  42.00 + g,
  0.0500,
  4.60,
  now()
from generate_series(1, 7) as g
on conflict on constraint daily_metrics_scope_key do nothing;

-- ----------------------------------------------------------------------------
-- 13. Zone metrics, three zones × seven days
-- ----------------------------------------------------------------------------
insert into public.zone_metrics (
  metric_date, service_zone_id, demand_score, supply_available_minutes,
  avg_eta_minutes, surge_multiplier_avg, jobs_requested, jobs_fulfilled, computed_at
)
select
  current_date - g,
  z.id,
  (60 + g)::numeric(6,2),
  1200,
  12.00 + g,
  (1.0000 + (g * 0.0100))::numeric(6,4),
  25 + g,
  20 + g,
  now()
from generate_series(1, 7) as g
cross join (values
  ('66666666-0000-4000-8000-000000000001'::uuid),
  ('66666666-0000-4000-8000-000000000002'::uuid),
  ('66666666-0000-4000-8000-000000000003'::uuid)
) as z(id)
on conflict on constraint zone_metrics_scope_key do nothing;

-- ----------------------------------------------------------------------------
-- 14. Driver metrics, three drivers × seven days
-- ----------------------------------------------------------------------------
insert into public.driver_metrics (
  metric_date, driver_id, trips_completed, hours_online,
  earnings_gross, earnings_net, currency_code, acceptance_rate,
  on_time_rate, avg_rating, avg_distance_km, computed_at
)
select
  current_date - g,
  d.id,
  6 + (g % 4),
  6.50,
  120000 + (g * 5000),
  105000 + (g * 4500),
  'TZS',
  0.8800 + (g * 0.0100),
  0.9300,
  4.60,
  72.00 + g,
  now()
from generate_series(1, 7) as g
cross join (values
  ('d0000000-0000-4000-8000-000000000001'::uuid),
  ('d0000000-0000-4000-8000-000000000002'::uuid),
  ('d0000000-0000-4000-8000-000000000003'::uuid)
) as d(id)
on conflict on constraint driver_metrics_scope_key do nothing;

-- ----------------------------------------------------------------------------
-- 15. Customer metrics, three customers × seven days
-- ----------------------------------------------------------------------------
insert into public.customer_metrics (
  metric_date, customer_id, jobs_created, jobs_completed,
  total_spent, currency_code, avg_rating_given, last_active_at, computed_at
)
select
  current_date - g,
  c.id,
  1 + (g % 3),
  1 + (g % 2),
  35000 + (g * 2500),
  'TZS',
  4.50,
  now() - (g || ' days')::interval,
  now()
from generate_series(1, 7) as g
cross join (values
  ('c0000000-0000-4000-8000-000000000001'::uuid),
  ('c0000000-0000-4000-8000-000000000002'::uuid),
  ('c0000000-0000-4000-8000-000000000003'::uuid)
) as c(id)
on conflict on constraint customer_metrics_scope_key do nothing;

-- ----------------------------------------------------------------------------
-- 16. Demand snapshots: 3 zones × 144 five-minute buckets = 432 rows
-- ----------------------------------------------------------------------------
insert into public.demand_snapshots (
  snapshot_at, service_zone_id, active_job_requests,
  active_drivers, pending_offers, avg_wait_seconds, computed_at
)
select
  date_trunc('hour', now()) - (g * interval '5 minutes'),
  z.id,
  8 + (g % 11),
  5 + (g % 7),
  1 + (g % 3),
  120 + (g * 3),
  now()
from generate_series(0, 143) as g
cross join (values
  ('66666666-0000-4000-8000-000000000001'::uuid),
  ('66666666-0000-4000-8000-000000000002'::uuid),
  ('66666666-0000-4000-8000-000000000003'::uuid)
) as z(id)
on conflict on constraint demand_snapshots_scope_key do nothing;
