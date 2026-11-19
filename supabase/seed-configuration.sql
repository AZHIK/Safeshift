-- SafeShift configuration data and scheduled jobs.
-- Run after schema migrations and the environment-specific seed.
-- Safe to rerun where statements use their existing conflict guards.

set search_path = public, extensions;


-- From migration 0035_phase_2_rls.sql
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('verify_vehicle',          'Approve or reject vehicle and vehicle-document verification', 'trust_safety'),
  ('manage_document_types',   'Manage country document catalogues and checklists',          'trust_safety'),
  ('manage_vehicle_catalog',  'Manage vehicle types, makes, models and equipment',          'operations'),
  ('manage_cargo_catalog',    'Manage cargo categories, types, restrictions and packaging',  'operations'),
  ('view_all_vehicles',       'View all vehicle records',                                   'operations'),
  ('view_all_fleets',         'View all fleet records',                                     'operations'),
  ('assign_vehicles',         'Assign drivers to vehicles',                                 'operations'),
  ('view_fleet_reports',      'View generated fleet reports',                               'operations'),
  ('view_reminders',          'View scheduled document-expiry reminders',                   'trust_safety')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', p.permission_key
from public.admin_permissions_catalog p
where p.permission_key in (
  'verify_vehicle', 'manage_document_types', 'manage_vehicle_catalog',
  'manage_cargo_catalog', 'view_all_vehicles', 'view_all_fleets',
  'assign_vehicles', 'view_fleet_reports', 'view_reminders'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('verification_admin', 'verify_vehicle'),
  ('verification_admin', 'view_all_vehicles'),
  ('verification_admin', 'view_reminders'),
  ('verification_admin', 'manage_document_types'),
  ('operations_admin',  'manage_vehicle_catalog'),
  ('operations_admin',  'manage_cargo_catalog'),
  ('operations_admin',  'view_all_vehicles'),
  ('operations_admin',  'view_all_fleets'),
  ('operations_admin',  'assign_vehicles'),
  ('operations_admin',  'view_fleet_reports')
on conflict do nothing;


-- From migration 0049_phase_3_rls.sql
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_pricing',            'Create pricing plans and publish plan versions',        'pricing'),
  ('manage_regulated_tariffs',  'Manage regulated tariff frameworks and legal bands',    'compliance'),
  ('view_promotions',           'View all promo codes and redemption records',           'operations')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', p.permission_key
from public.admin_permissions_catalog p
where p.permission_key in (
  'manage_pricing', 'manage_regulated_tariffs', 'view_promotions'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('finance_admin',   'manage_pricing'),
  ('finance_admin',   'manage_regulated_tariffs'),
  ('finance_admin',   'view_promotions'),
  ('operations_admin','view_promotions'),
  ('support_agent',   'view_promotions'),
  ('analyst',         'view_promotions')
on conflict do nothing;


-- From migration 0073_phase_4_rls.sql
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('view_all_quotes',              'View every quote request and quote',                  'operations'),
  ('manage_surge',                 'Create and modify demand surge multipliers',          'pricing'),
  ('view_all_jobs',                'View every job and operational record',               'operations'),
  ('assign_drivers',               'Assign drivers and vehicles to jobs',                 'operations'),
  ('manage_cancellation_policies', 'Manage country cancellation policies',                'operations'),
  ('manage_dispatch',              'Manage dispatch rules and matching configuration',    'operations'),
  ('manage_ratings',               'Manage rating categories and moderation',             'support'),
  ('view_all_ratings',             'View every rating and rating report',                 'support'),
  ('view_all_disputes',            'View every dispute, including internal notes',        'support'),
  ('resolve_disputes',             'Resolve disputes and grant compensation',             'support')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', p.permission_key
from public.admin_permissions_catalog p
where p.permission_key in (
  'view_all_quotes', 'manage_surge', 'view_all_jobs', 'assign_drivers',
  'manage_cancellation_policies', 'manage_dispatch', 'manage_ratings',
  'view_all_ratings', 'view_all_disputes', 'resolve_disputes'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('operations_admin', 'view_all_quotes'),
  ('operations_admin', 'manage_surge'),
  ('operations_admin', 'view_all_jobs'),
  ('operations_admin', 'assign_drivers'),
  ('operations_admin', 'manage_cancellation_policies'),
  ('operations_admin', 'manage_dispatch'),
  ('operations_admin', 'view_all_ratings'),
  ('operations_admin', 'view_all_disputes'),
  ('support_agent',    'view_all_quotes'),
  ('support_agent',    'view_all_jobs'),
  ('support_agent',    'manage_ratings'),
  ('support_agent',    'view_all_ratings'),
  ('support_agent',    'view_all_disputes'),
  ('support_agent',    'resolve_disputes'),
  ('finance_admin',    'view_all_quotes'),
  ('finance_admin',    'view_all_jobs'),
  ('finance_admin',    'manage_cancellation_policies'),
  ('finance_admin',    'view_all_disputes'),
  ('analyst',          'view_all_quotes'),
  ('analyst',          'view_all_jobs'),
  ('analyst',          'view_all_ratings'),
  ('analyst',          'view_all_disputes'),
  ('verification_admin','view_all_jobs'),
  ('verification_admin','view_all_ratings')
on conflict do nothing;


-- From migration 0091_phase_5_phase4_closures.sql
update public.commission_ledger
   set is_refunded = false
 where is_refunded is null;


-- From migration 0094_phase_5_rls.sql
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_payments',           'Manage payment providers and payment configuration', 'finance'),
  ('view_all_payment_methods',  'View every saved payment method',                    'finance'),
  ('process_refunds',           'Create and process refunds',                         'finance'),
  ('view_all_payments',         'View every payment attempt',                         'finance'),
  ('view_payment_webhooks',     'View raw provider webhook logs',                     'finance'),
  ('view_all_refunds',          'View every refund',                                  'finance'),
  ('view_all_wallets',          'View every wallet and wallet ledger',                'finance'),
  ('manage_commission',         'Manage commission rules',                            'finance'),
  ('view_all_commissions',      'View every commission ledger entry',                 'finance'),
  ('manage_taxes',              'Manage country tax rates',                           'compliance'),
  ('view_payouts',              'View payout batches and driver payouts',             'finance'),
  ('process_payouts',           'Create and execute payouts',                         'finance'),
  ('view_invoices',             'View all business invoices',                         'finance'),
  ('manage_invoices',           'Generate and manage business invoices',              'finance'),
  ('view_fleet_billing',        'View fleet commission accruals',                     'finance')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', p.permission_key
from public.admin_permissions_catalog p
where p.permission_key in (
  'manage_payments', 'view_all_payment_methods', 'process_refunds', 'view_all_payments',
  'view_payment_webhooks', 'view_all_refunds', 'view_all_wallets', 'manage_commission',
  'view_all_commissions', 'manage_taxes', 'view_payouts', 'process_payouts',
  'view_invoices', 'manage_invoices', 'view_fleet_billing'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('finance_admin', 'manage_payments'),
  ('finance_admin', 'view_all_payment_methods'),
  ('finance_admin', 'process_refunds'),
  ('finance_admin', 'view_all_payments'),
  ('finance_admin', 'view_payment_webhooks'),
  ('finance_admin', 'view_all_refunds'),
  ('finance_admin', 'view_all_wallets'),
  ('finance_admin', 'manage_commission'),
  ('finance_admin', 'view_all_commissions'),
  ('finance_admin', 'manage_taxes'),
  ('finance_admin', 'view_payouts'),
  ('finance_admin', 'process_payouts'),
  ('finance_admin', 'view_invoices'),
  ('finance_admin', 'manage_invoices'),
  ('finance_admin', 'view_fleet_billing'),
  ('operations_admin', 'view_all_payment_methods'),
  ('operations_admin', 'view_all_payments'),
  ('operations_admin', 'view_all_wallets'),
  ('operations_admin', 'view_payouts'),
  ('operations_admin', 'view_invoices'),
  ('operations_admin', 'view_fleet_billing'),
  ('support_agent', 'view_all_payment_methods'),
  ('support_agent', 'view_all_payments'),
  ('support_agent', 'view_all_refunds'),
  ('support_agent', 'view_all_wallets'),
  ('support_agent', 'view_invoices'),
  ('analyst', 'view_all_payments'),
  ('analyst', 'view_all_commissions'),
  ('analyst', 'view_all_wallets'),
  ('analyst', 'view_payouts'),
  ('analyst', 'view_invoices'),
  ('analyst', 'view_fleet_billing')
on conflict do nothing;


-- From migration 0095_phase_5_pg_cron_schedules.sql
do $$
declare
  v_job record;
begin
  for v_job in
    select jobname from cron.job where jobname like 'safeshift_%'
  loop
    perform cron.unschedule(v_job.jobname);
  end loop;

  perform cron.schedule(
    'safeshift_expire_offers',
    '30 seconds',
    'SELECT public.expire_stale_offers()'
  );

  perform cron.schedule(
    'safeshift_quote_cleanup',
    '0 3 * * *',
    'SELECT public.quote_cleanup()'
  );

  perform cron.schedule(
    'safeshift_acceptance_stats',
    '0 2 * * *',
    'SELECT public.recompute_all_driver_acceptance_stats()'
  );

  perform cron.schedule(
    'safeshift_wallet_verify',
    '0 4 * * *',
    'SELECT public.wallet_balance_verify()'
  );
end $$;


-- From migration 0114_phase_6_rls.sql
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_notifications',      'Manage notification templates and send configuration', 'communication'),
  ('view_incidents',            'View safety incidents',                               'safety'),
  ('manage_incidents',          'Assign, update, and resolve safety incidents',        'safety'),
  ('manage_prohibited_items',   'Manage jurisdiction prohibited-item catalogues',      'safety'),
  ('manage_support',            'Manage support categories and support configuration', 'support'),
  ('view_all_tickets',          'View every support ticket and internal note',         'support'),
  ('manage_tickets',            'Assign and update support tickets',                   'support'),
  ('view_data_access',          'View PDPC data access logs',                          'compliance'),
  ('view_retention',            'View data retention policies',                        'compliance'),
  ('manage_retention',          'Manage and execute data retention policies',          'compliance'),
  ('manage_data_requests',      'Process GDPR/PDPC data subject requests',             'compliance'),
  ('view_analytics',            'View batch analytics and operational dashboards',     'analytics'),
  ('manage_analytics',          'Run analytics batch functions',                       'analytics')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select v.role_name, v.permission_key
  from (values
    ('super_admin',        'manage_notifications'),
    ('super_admin',        'view_incidents'),
    ('super_admin',        'manage_incidents'),
    ('super_admin',        'manage_prohibited_items'),
    ('super_admin',        'manage_support'),
    ('super_admin',        'view_all_tickets'),
    ('super_admin',        'manage_tickets'),
    ('super_admin',        'view_data_access'),
    ('super_admin',        'view_retention'),
    ('super_admin',        'manage_retention'),
    ('super_admin',        'manage_data_requests'),
    ('super_admin',        'view_analytics'),
    ('super_admin',        'manage_analytics'),
    ('operations_admin',   'manage_notifications'),
    ('operations_admin',   'view_incidents'),
    ('operations_admin',   'manage_incidents'),
    ('operations_admin',   'manage_prohibited_items'),
    ('operations_admin',   'view_all_tickets'),
    ('operations_admin',   'manage_tickets'),
    ('operations_admin',   'view_analytics'),
    ('verification_admin', 'view_incidents'),
    ('verification_admin', 'view_analytics'),
    ('support_agent',      'view_incidents'),
    ('support_agent',      'view_all_tickets'),
    ('support_agent',      'manage_tickets'),
    ('support_agent',      'manage_support'),
    ('support_agent',      'manage_data_requests'),
    ('finance_admin',      'view_analytics'),
    ('analyst',            'view_analytics'),
    ('analyst',            'view_data_access'),
    ('analyst',            'view_retention')
  ) as v(role_name, permission_key)
 where not exists (
   select 1
     from public.admin_role_permissions existing
    where existing.role_name = v.role_name
      and existing.permission_key = v.permission_key
 );


-- From migration 0116_phase_6_pg_cron_schedules.sql
do $$
declare
  j record;
begin
  for j in
    select jobid
      from cron.job
     where jobname in (
       'safeshift_compute_daily_metrics',
       'safeshift_compute_zone_metrics',
       'safeshift_compute_driver_metrics',
       'safeshift_compute_customer_metrics',
       'safeshift_capture_demand',
       'safeshift_retention'
     )
  loop
    perform cron.unschedule(j.jobid);
  end loop;
end;
$$;

select cron.schedule(
  'safeshift_compute_daily_metrics',
  '15 1 * * *',
  $$select public.compute_daily_metrics(current_date - 1);$$
);

select cron.schedule(
  'safeshift_compute_zone_metrics',
  '20 1 * * *',
  $$select public.compute_zone_metrics(current_date - 1);$$
);

select cron.schedule(
  'safeshift_compute_driver_metrics',
  '25 1 * * *',
  $$select public.compute_driver_metrics(current_date - 1);$$
);

select cron.schedule(
  'safeshift_compute_customer_metrics',
  '30 1 * * *',
  $$select public.compute_customer_metrics(current_date - 1);$$
);

select cron.schedule(
  'safeshift_capture_demand',
  '*/5 * * * *',
  $$select public.capture_demand_snapshot();$$
);

select cron.schedule(
  'safeshift_retention',
  '0 5 * * *',
  $$select public.apply_retention_policies();$$
);


-- From migration 0119_phase_7_edge_function_support.sql
insert into public.edge_function_config (function_name, url) values
  ('scheduled-daily-metrics', null),
  ('scheduled-demand-capture', null),
  ('scheduled-retention', null)
on conflict (function_name) do nothing;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'safeshift_healthcheck') then
    perform vault.create_secret(
      'ok',
      'safeshift_healthcheck',
      'Non-sensitive Phase 7 health probe'
    );
  end if;
end $$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('data-exports', 'data-exports', false, 52428800, array['application/zip'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('send_sms',          'Send transactional SMS',                         'communication'),
  ('send_email',        'Send transactional email',                       'communication'),
  ('send_push',         'Send push notifications',                        'communication'),
  ('send_notification', 'Dispatch notifications across channels',         'communication')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select v.role_name, v.permission_key
  from (values
    ('super_admin',      'send_sms'),
    ('super_admin',      'send_email'),
    ('super_admin',      'send_push'),
    ('super_admin',      'send_notification'),
    ('operations_admin', 'send_sms'),
    ('operations_admin', 'send_email'),
    ('operations_admin', 'send_push'),
    ('operations_admin', 'send_notification'),
    ('support_agent',    'send_sms'),
    ('support_agent',    'send_email'),
    ('support_agent',    'send_push')
  ) as v(role_name, permission_key)
 where not exists (
   select 1
     from public.admin_role_permissions existing
    where existing.role_name = v.role_name
      and existing.permission_key = v.permission_key
 );

do $$
declare
  j record;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    for j in
      select jobid from cron.job where jobname = 'safeshift_cleanup_idempotency'
    loop
      perform cron.unschedule(j.jobid);
    end loop;

    perform cron.schedule(
      'safeshift_cleanup_idempotency',
      '0 6 * * *',
      $cron$select public.cleanup_idempotency_keys();$cron$
    );
  end if;
end $$;


-- From migration 0122_phase_8_storage_policies.sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('driver-documents', 'driver-documents', false, 20971520,
   array['image/jpeg','image/png','image/webp','application/pdf']),
  ('vehicle-documents', 'vehicle-documents', false, 20971520,
   array['image/jpeg','image/png','image/webp','application/pdf']),
  ('job-evidence', 'job-evidence', false, 20971520,
   array['image/jpeg','image/png','image/webp','application/pdf']),
  ('chat-attachments', 'chat-attachments', false, 26214400,
   array['image/jpeg','image/png','image/webp','application/pdf','audio/mpeg','audio/mp4'])
on conflict (id) do nothing;


-- From migration 0124_phase_9_recurring_job_scheduler.sql
do $$
declare
  v_job record;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    for v_job in
      select jobid from cron.job where jobname = 'safeshift_generate_scheduled_jobs'
    loop
      perform cron.unschedule(v_job.jobid);
    end loop;

    perform cron.schedule(
      'safeshift_generate_scheduled_jobs',
      '17 * * * *',
      $cron$select public.generate_recurring_scheduled_jobs(24);$cron$
    );
  end if;
end $$;


-- From migration 0126_phase_9_admin_console_support.sql
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('view_verifications',       'View driver, vehicle, and business verification queues', 'trust_safety'),
  ('manage_verifications',     'Assign and process verification requests',                'trust_safety'),
  ('manage_business_verifications', 'Approve or reject business account verification',     'trust_safety'),
  ('view_fleet',               'View a fleet owned by the signed-in fleet owner',           'operations'),
  ('manage_fleet_vehicles',    'Add, edit, and retire fleet vehicles',                      'operations'),
  ('manage_fleet_drivers',     'Invite and remove fleet drivers',                           'operations'),
  ('view_fleet_earnings',      'View fleet earnings and billing events',                    'finance'),
  ('manage_tariffs',           'Manage regulated tariff frameworks',                        'pricing'),
  ('manage_promos',            'Manage promo codes and redemption rules',                   'operations'),
  ('view_support_tickets',     'View support tickets and messages',                         'support'),
  ('manage_support_tickets',   'Reply to, assign, and resolve support tickets',             'support'),
  ('view_payouts',             'View payout batches and payout items',                      'finance'),
  ('manage_payouts',           'Create and approve payout batches',                         'finance'),
  ('view_all_businesses',      'View all business account records',                         'support')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', permission_key
from public.admin_permissions_catalog
where permission_key in (
  'view_verifications', 'manage_verifications', 'manage_business_verifications',
  'view_fleet', 'manage_fleet_vehicles', 'manage_fleet_drivers', 'view_fleet_earnings',
  'manage_tariffs', 'manage_promos', 'view_support_tickets', 'manage_support_tickets',
  'view_payouts', 'manage_payouts', 'view_all_businesses'
)
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('verification_admin', 'view_verifications'),
  ('verification_admin', 'manage_verifications'),
  ('verification_admin', 'manage_business_verifications'),
  ('operations_admin',   'view_verifications'),
  ('operations_admin',   'manage_verifications'),
  ('operations_admin',   'view_fleet'),
  ('operations_admin',   'manage_fleet_vehicles'),
  ('operations_admin',   'manage_fleet_drivers'),
  ('operations_admin',   'view_fleet_earnings'),
  ('operations_admin',   'manage_tariffs'),
  ('operations_admin',   'manage_promos'),
  ('operations_admin',   'view_all_businesses'),
  ('support_agent',      'view_support_tickets'),
  ('support_agent',      'manage_support_tickets'),
  ('support_agent',      'view_all_businesses'),
  ('finance_admin',      'view_payouts'),
  ('finance_admin',      'manage_payouts'),
  ('finance_admin',      'view_fleet_earnings'),
  ('analyst',            'view_support_tickets'),
  ('analyst',            'view_payouts'),

  ('fleet_owner',        'view_fleet'),
  ('fleet_owner',        'manage_fleet_vehicles'),
  ('fleet_owner',        'manage_fleet_drivers'),
  ('fleet_owner',        'view_fleet_earnings')
on conflict do nothing;


-- From migration 0127_phase_9_seed_updates.sql
insert into public.admin_roles (profile_id, role_name, country_id, city_id, is_active, granted_by)
select 'f0000000-0000-4000-8000-000000000001'::uuid,
       'fleet_owner',
       '33333333-0000-4000-8000-000000000001'::uuid,
       null,
       true,
       'a0000000-0000-4000-8000-000000000001'::uuid
where exists (select 1 from public.profiles where id = 'f0000000-0000-4000-8000-000000000001'::uuid)
  and not exists (
    select 1 from public.admin_roles
     where profile_id = 'f0000000-0000-4000-8000-000000000001'::uuid
       and role_name = 'fleet_owner'
  );

insert into public.admin_role_permissions (role_name, permission_key)
select 'fleet_owner', permission_key
from public.admin_permissions_catalog
where permission_key in ('view_fleet', 'manage_fleet_vehicles', 'manage_fleet_drivers',
                         'view_fleet_earnings')
on conflict do nothing;

insert into public.support_categories (country_id, code, name, description, display_order, is_active)
select c.id, v.code, v.name, v.description, v.display_order, true
from public.countries c
cross join (values
  ('business_account', 'Business account', 'Business registration, verification, and invoicing.', 60),
  ('safety', 'Safety concern', 'Safety, SOS, trip sharing, and emergency support.', 70),
  ('driver_onboarding', 'Driver onboarding', 'Driver documents, verification, and vehicle checks.', 80),
  ('trip_issue', 'Trip issue', 'Live trip, delivery code, or route issue.', 90)
) as v(code, name, description, display_order)
where c.id = '33333333-0000-4000-8000-000000000001'::uuid
on conflict (country_id, code) do nothing;

insert into public.feature_flags (flag_key, country_id, city_id, profile_id, is_enabled, rollout_percentage, description) values
  ('phase9_driver_onboarding', null, null, null, true, 100, 'Guided driver onboarding and document capture.'),
  ('phase9_business_accounts', null, null, null, true, 100, 'Business account self-service and recurring jobs.'),
  ('phase9_safety_suite', null, null, null, true, 100, 'Emergency contacts, SOS, and trip sharing.'),
  ('phase9_admin_console', null, null, null, true, 100, 'Next.js operations console for admins and fleet owners.')
on conflict (flag_key, country_id, city_id, profile_id) do nothing;


-- From migration 0131_catalog_icons.sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('catalog-icons', 'catalog-icons', true, 262144,
  array['image/svg+xml','image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

update public.vehicle_types
   set icon_url = 'vehicle/' || code || '.svg'
 where icon_url is null;

update public.cargo_types
   set icon_url = 'cargo/' || code || '.svg'
 where icon_url is null;


-- From migration 0132_phase_10_admin_config_permissions.sql
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_configuration', 'Open the whole operator configuration section (umbrella for every configuration table)', 'platform')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('super_admin',        'manage_configuration'),
  ('operations_admin',   'manage_vehicle_catalog'),
  ('operations_admin',   'manage_cargo_catalog'),
  ('operations_admin',   'manage_document_types'),
  ('operations_admin',   'manage_dispatch'),
  ('operations_admin',   'manage_cancellation_policies'),
  ('verification_admin', 'manage_document_types'),
  ('support_agent',      'manage_support')
on conflict do nothing;


-- From migration 0133_phase_11_countries_management.sql
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('manage_countries', 'Add the countries the platform operates in and retire the ones it does not', 'platform')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('super_admin',      'manage_countries'),
  ('operations_admin', 'manage_countries')
on conflict do nothing;


-- From migration 0135_phase_11_country_phone_code.sql
update public.countries c
   set phone_code = catalogue.phone_code
  from (
    select 'TZ'::text as iso_code, '+255'::text as phone_code
    union all select 'KE', '+254'
    union all select 'UG', '+256'
  ) as catalogue
 where c.iso_code = catalogue.iso_code
   and (c.phone_code is null or c.phone_code <> catalogue.phone_code);


-- From migration 0136_phase_11_country_catalogue_rows.sql
insert into public.currencies (id, code, name, symbol, decimal_places, is_active) values
  ('11111111-0000-4000-8000-000000000001', 'TZS', 'Tanzanian Shilling', 'TSh', 2, true),
  ('11111111-0000-4000-8000-000000000002', 'KES', 'Kenyan Shilling',    'KSh', 2, true),
  ('11111111-0000-4000-8000-000000000003', 'UGX', 'Ugandan Shilling',   'USh', 0, true)
on conflict (code) do update
  set name = excluded.name,
      symbol = excluded.symbol,
      decimal_places = excluded.decimal_places,
      is_active = true;

insert into public.languages (id, code, name, native_name, is_active) values
  ('22222222-0000-4000-8000-000000000001', 'en', 'English', 'English', true),
  ('22222222-0000-4000-8000-000000000002', 'sw', 'Swahili', 'Kiswahili', true)
on conflict (code) do update
  set name = excluded.name,
      native_name = excluded.native_name,
      is_active = true;

insert into public.countries (
  id, iso_code, name, default_currency_id, default_timezone, default_language_id,
  regulatory_framework, tax_registration_required, phone_code, is_active, launched_at
) values
  ('33333333-0000-4000-8000-000000000001', 'TZ', 'Tanzania',
   '11111111-0000-4000-8000-000000000001', 'Africa/Dar_es_Salaam',
   '22222222-0000-4000-8000-000000000002', 'LATRA', true, '+255', true, now()),
  ('33333333-0000-4000-8000-000000000002', 'KE', 'Kenya',
   '11111111-0000-4000-8000-000000000002', 'Africa/Nairobi',
   '22222222-0000-4000-8000-000000000001', 'NTSA', true, '+254', false, null),
  ('33333333-0000-4000-8000-000000000003', 'UG', 'Uganda',
   '11111111-0000-4000-8000-000000000003', 'Africa/Kampala',
   '22222222-0000-4000-8000-000000000001', 'UNRA', true, '+256', false, null)
on conflict (iso_code) do update
  set name = excluded.name,
      default_currency_id = excluded.default_currency_id,
      default_timezone = excluded.default_timezone,
      default_language_id = excluded.default_language_id,
      regulatory_framework = excluded.regulatory_framework,
      tax_registration_required = excluded.tax_registration_required,
      phone_code = excluded.phone_code;


-- Country settings formerly held in public.countries.config.
insert into public.country_configurations (country_id, config_key, config_value, description)
select c.id, v.config_key, v.config_value::jsonb, 'Seeded country configuration'
from public.countries c
join (values
  ('TZ', 'mobile_money_providers', '["mpesa", "tigo_pesa", "airtel_money", "halopesa"]'),
  ('TZ', 'pdpc_registration_required', 'true'),
  ('KE', 'mobile_money_providers', '["mpesa"]'),
  ('UG', 'mobile_money_providers', '["mtn_momo", "airtel_money"]')
) as v(iso_code, config_key, config_value) on v.iso_code = c.iso_code
on conflict (country_id, config_key) do nothing;

-- From migration 0137_phase_11_catalog_icon_size.sql
update storage.buckets
   set file_size_limit = 524288
 where id = 'catalog-icons';


-- From migration 0139_expand_dar_es_salaam_service_boundary.sql
update public.cities
   set boundary = extensions.ST_GeogFromText(
         'SRID=4326;POLYGON(('
         '39.007030 -6.790543, 39.054128 -6.790076, 39.054347 -6.842875, '
         '39.071253 -6.867684, 39.118821 -6.880036, 39.108846 -6.915069, '
         '39.088076 -6.923149, 39.094144 -6.933371, 39.059600 -6.973104, '
         '39.074478 -6.979623, 39.065205 -7.013962, 39.050895 -7.028325, '
         '39.023073 -7.023264, 39.030203 -7.046482, 39.068367 -7.031407, '
         '39.069703 -7.057316, 39.113054 -7.073113, 39.115121 -7.093877, '
         '39.151625 -7.019664, 39.174412 -7.011036, 39.170167 -6.995146, '
         '39.192502 -6.982367, 39.220554 -6.994276, 39.244801 -6.950880, '
         '39.269737 -6.943809, 39.277778 -6.957692, 39.298209 -6.948134, '
         '39.314347 -6.959666, 39.327560 -6.947989, 39.359884 -6.969983, '
         '39.384870 -6.967965, 39.384893 -6.996721, 39.405613 -7.009641, '
         '39.409984 -7.065282, 39.393039 -7.085732, 39.417688 -7.125585, '
         '39.407082 -7.168957, 39.422036 -7.151831, 39.435191 -7.168101, '
         '39.451479 -7.156455, 39.444185 -7.181051, 39.487985 -7.165577, '
         '39.502764 -7.186706, 39.520869 -7.169983, 39.525896 -7.129568, '
         '39.555073 -7.131213, 39.540750 -7.079344, 39.546200 -6.988183, '
         '39.519963 -6.968561, 39.476054 -6.865627, 39.366618 -6.853295, '
         '39.314141 -6.815157, 39.294539 -6.825032, 39.306999 -6.852076, '
         '39.285897 -6.869816, 39.300310 -6.852600, 39.286841 -6.822526, '
         '39.301389 -6.817010, 39.281555 -6.796200, 39.285913 -6.740756, '
         '39.276181 -6.732738, 39.268350 -6.759693, 39.245798 -6.750394, '
         '39.223678 -6.669063, 39.150000 -6.577524, 39.121477 -6.566206, '
         '39.080664 -6.602921, 39.060939 -6.720523, 39.007030 -6.790543'
         '))'
       ),
       updated_at = now()
 where id = '55555555-0000-4000-8000-000000000001'
   and name = 'Dar es Salaam';


-- From migration 0140_courier_flow_fixes.sql
do $$
declare
  v_job record;
begin
  for v_job in
    select jobid from cron.job where jobname = 'safeshift_dispatch_tick'
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;
end;
$$;

select cron.schedule(
  'safeshift_dispatch_tick',
  '* * * * *',
  $$select public.dispatch_tick();$$
);

insert into public.edge_function_config (function_name, url)
values ('push-send', null)
on conflict (function_name) do nothing;

update public.drivers d
   set current_vehicle_id = a.vehicle_id
  from public.vehicle_assignments a
 where a.driver_id = d.id
   and a.is_active
   and a.unassigned_at is null
   and d.current_vehicle_id is null;

