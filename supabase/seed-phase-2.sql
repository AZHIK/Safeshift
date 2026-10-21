-- ============================================================================
-- PHASE 2 SEED — run after seed.sql.
-- This file is intended for a local/service-role database reset; service-role
-- execution bypasses RLS, which is required for server-only workflow tables.
-- ============================================================================

begin;

-- Tanzania and Dar es Salaam identifiers are created by Phase 1 seed.sql.
-- ---------------------------------------------------------------------------
-- 1. Permission catalogue additions used by Phase 2 RLS and operations.
-- ---------------------------------------------------------------------------
insert into public.admin_permissions_catalog (permission_key, description, category) values
  ('verify_vehicle', 'Approve or reject vehicle and vehicle-document verification', 'trust_safety'),
  ('manage_document_types', 'Manage country document catalogues and checklists', 'trust_safety'),
  ('manage_vehicle_catalog', 'Manage vehicle types, makes, models and equipment', 'operations'),
  ('manage_cargo_catalog', 'Manage cargo categories, types and restrictions', 'operations'),
  ('view_all_vehicles', 'View all vehicle records', 'operations'),
  ('view_all_fleets', 'View all fleet records', 'operations'),
  ('assign_vehicles', 'Assign drivers to vehicles', 'operations'),
  ('view_fleet_reports', 'View generated fleet reports', 'operations'),
  ('view_reminders', 'View scheduled document-expiry reminders', 'trust_safety')
on conflict (permission_key) do nothing;

insert into public.admin_role_permissions (role_name, permission_key)
select 'super_admin', permission_key
from public.admin_permissions_catalog
where permission_key in ('verify_vehicle', 'manage_document_types', 'manage_vehicle_catalog', 'manage_cargo_catalog', 'view_all_vehicles', 'view_all_fleets', 'assign_vehicles', 'view_fleet_reports', 'view_reminders')
on conflict do nothing;

insert into public.admin_role_permissions (role_name, permission_key) values
  ('verification_admin', 'verify_vehicle'),
  ('verification_admin', 'view_reminders'),
  ('verification_admin', 'view_all_vehicles'),
  ('verification_admin', 'manage_document_types'),
  ('operations_admin', 'manage_vehicle_catalog'),
  ('operations_admin', 'manage_cargo_catalog'),
  ('operations_admin', 'view_all_vehicles'),
  ('operations_admin', 'view_all_fleets'),
  ('operations_admin', 'assign_vehicles'),
  ('operations_admin', 'view_fleet_reports')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Documents and vehicle reference data.
-- ---------------------------------------------------------------------------
insert into public.document_types (id, country_id, code, name, description, applies_to, is_required, has_expiry, validity_days) values
  ('20000000-0000-4000-8000-000000000001', null, 'driving_licence', 'Driving licence', 'Valid transport driving licence.', 'driver', true, true, 3650),
  ('20000000-0000-4000-8000-000000000002', null, 'national_id', 'National ID', 'Government-issued national identity document.', 'driver', true, true, 3650),
  ('20000000-0000-4000-8000-000000000003', null, 'police_clearance', 'Police clearance', 'Police clearance certificate.', 'driver', false, true, 365),
  ('20000000-0000-4000-8000-000000000004', null, 'vehicle_registration', 'Vehicle registration', 'Vehicle registration certificate.', 'vehicle', true, true, 365),
  ('20000000-0000-4000-8000-000000000005', null, 'insurance_certificate', 'Insurance certificate', 'Current vehicle insurance cover.', 'vehicle', true, true, 365),
  ('20000000-0000-4000-8000-000000000006', null, 'vehicle_inspection', 'Vehicle inspection', 'Roadworthiness inspection certificate.', 'vehicle', true, true, 180),
  ('20000000-0000-4000-8000-000000000007', null, 'business_licence', 'Business licence', 'Registered business licence.', 'business', true, true, 365),
  ('20000000-0000-4000-8000-000000000008', null, 'tin_certificate', 'TIN certificate', 'Taxpayer identification certificate.', 'business', true, false, null),
  ('20000000-0000-4000-8000-000000000009', null, 'road_service_licence', 'Road service licence', 'Commercial road service licence.', 'vehicle', true, true, 365),
  ('20000000-0000-4000-8000-000000000010', '33333333-0000-4000-8000-000000000001', 'latra_permit', 'LATRA permit', 'Tanzania LATRA operating permit.', 'vehicle', false, true, 365);

insert into public.vehicle_makes (id, name, country_of_origin) values
  ('21000000-0000-4000-8000-000000000001', 'Toyota', 'Japan'),
  ('21000000-0000-4000-8000-000000000002', 'Isuzu', 'Japan'),
  ('21000000-0000-4000-8000-000000000003', 'Mitsubishi', 'Japan'),
  ('21000000-0000-4000-8000-000000000004', 'Hino', 'Japan'),
  ('21000000-0000-4000-8000-000000000005', 'Fuso', 'Japan'),
  ('21000000-0000-4000-8000-000000000006', 'Mercedes-Benz', 'Germany'),
  ('21000000-0000-4000-8000-000000000007', 'Nissan', 'Japan'),
  ('21000000-0000-4000-8000-000000000008', 'Suzuki', 'Japan');

insert into public.vehicle_types (id, country_id, code, name, capacity_kg_min, capacity_kg_max, capacity_m3_min, capacity_m3_max, requires_special_licence, requires_equipment, display_order) values
  ('22000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'small_van', 'Small van', 500, 1500, 3, 12, false, '{}', 10),
  ('22000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'pickup', 'Pickup', 1000, 2000, 4, 15, false, '{straps}', 20),
  ('22000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'medium_truck', 'Medium truck', 3000, 7000, 15, 35, false, '{straps,load_bars}', 30),
  ('22000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', 'large_truck', 'Large truck', 10000, 30000, 40, 80, false, '{straps,load_bars}', 40),
  ('22000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', 'refrigerated_truck', 'Refrigerated truck', 3000, 10000, 15, 45, true, '{refrigeration_unit,straps}', 50),
  ('22000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', 'flatbed', 'Flatbed', 5000, 20000, 20, 60, true, '{straps}', 60);

insert into public.vehicle_models (make_id, name, vehicle_type_id, year_start) values
  ('21000000-0000-4000-8000-000000000001', 'Hiace', '22000000-0000-4000-8000-000000000001', 1990),
  ('21000000-0000-4000-8000-000000000001', 'Dyna', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000001', 'Hilux', '22000000-0000-4000-8000-000000000002', 1990),
  ('21000000-0000-4000-8000-000000000002', 'Elf', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000002', 'NQR', '22000000-0000-4000-8000-000000000004', 1990),
  ('21000000-0000-4000-8000-000000000002', 'D-Max', '22000000-0000-4000-8000-000000000002', 2000),
  ('21000000-0000-4000-8000-000000000003', 'Canter', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000003', 'Fuso Fighter', '22000000-0000-4000-8000-000000000004', 1990),
  ('21000000-0000-4000-8000-000000000003', 'L200', '22000000-0000-4000-8000-000000000002', 1990),
  ('21000000-0000-4000-8000-000000000004', '300 Series', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000004', '500 Series', '22000000-0000-4000-8000-000000000004', 1990),
  ('21000000-0000-4000-8000-000000000005', 'Canter FE', '22000000-0000-4000-8000-000000000003', 1990),
  ('21000000-0000-4000-8000-000000000005', 'Fighter', '22000000-0000-4000-8000-000000000004', 1990),
  ('21000000-0000-4000-8000-000000000006', 'Sprinter', '22000000-0000-4000-8000-000000000001', 1995),
  ('21000000-0000-4000-8000-000000000006', 'Atego', '22000000-0000-4000-8000-000000000003', 1998),
  ('21000000-0000-4000-8000-000000000006', 'Actros', '22000000-0000-4000-8000-000000000004', 1996),
  ('21000000-0000-4000-8000-000000000007', 'NV200', '22000000-0000-4000-8000-000000000001', 2009),
  ('21000000-0000-4000-8000-000000000007', 'Navara', '22000000-0000-4000-8000-000000000002', 1997),
  ('21000000-0000-4000-8000-000000000008', 'Carry', '22000000-0000-4000-8000-000000000001', 1990),
  ('21000000-0000-4000-8000-000000000008', 'Super Carry', '22000000-0000-4000-8000-000000000001', 1990);

insert into public.vehicle_equipment_catalog (id, code, name, category) values
  ('23000000-0000-4000-8000-000000000001', 'straps', 'Tie-down straps', 'safety'),
  ('23000000-0000-4000-8000-000000000002', 'blankets', 'Moving blankets', 'protection'),
  ('23000000-0000-4000-8000-000000000003', 'dolly', 'Hand dolly', 'handling'),
  ('23000000-0000-4000-8000-000000000004', 'ramp', 'Loading ramp', 'handling'),
  ('23000000-0000-4000-8000-000000000005', 'load_bars', 'Load bars', 'safety'),
  ('23000000-0000-4000-8000-000000000006', 'refrigeration_unit', 'Refrigeration unit', 'specialty'),
  ('23000000-0000-4000-8000-000000000007', 'tail_lift', 'Tail lift', 'handling'),
  ('23000000-0000-4000-8000-000000000008', 'gloves', 'Protective gloves', 'safety');

-- ---------------------------------------------------------------------------
-- 3. Cargo catalogue.
-- ---------------------------------------------------------------------------
insert into public.cargo_categories (id, code, name, display_order) values
  ('24000000-0000-4000-8000-000000000001', 'household', 'Household', 10),
  ('24000000-0000-4000-8000-000000000002', 'commercial', 'Commercial', 20),
  ('24000000-0000-4000-8000-000000000003', 'industrial', 'Industrial', 30);

insert into public.cargo_types (id, country_id, category_id, code, name, requires_special_handling, requires_declared_value, requires_insurance, allowed_vehicle_type_codes, max_value_tzs, display_order) values
  ('25000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000001', 'household_goods', 'Household goods', false, false, false, '{}', null, 10),
  ('25000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000001', 'furniture', 'Furniture', false, false, false, '{small_van,pickup,medium_truck,large_truck}', null, 20),
  ('25000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000001', 'appliances', 'Appliances', false, true, false, '{small_van,pickup,medium_truck,large_truck}', null, 30),
  ('25000000-0000-4000-8000-000000000004', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'building_materials', 'Building materials', false, false, false, '{medium_truck,large_truck,flatbed}', null, 40),
  ('25000000-0000-4000-8000-000000000005', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'fresh_produce', 'Fresh produce', true, false, true, '{refrigerated_truck}', null, 50),
  ('25000000-0000-4000-8000-000000000006', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'refrigerated_goods', 'Refrigerated goods', true, false, false, '{refrigerated_truck}', null, 60),
  ('25000000-0000-4000-8000-000000000007', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'electronics', 'Electronics', false, true, true, '{small_van,pickup,medium_truck}', null, 70),
  ('25000000-0000-4000-8000-000000000008', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000003', 'machinery', 'Machinery', true, true, true, '{flatbed,large_truck}', null, 80),
  ('25000000-0000-4000-8000-000000000009', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000002', 'livestock', 'Livestock', true, false, true, '{}', null, 90),
  ('25000000-0000-4000-8000-000000000010', '33333333-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000003', 'hazardous_materials', 'Hazardous materials', true, true, true, '{flatbed,large_truck}', 5000000, 100);

insert into public.cargo_packaging_options (id, code, name, additional_fee_tzs, display_order) values
  ('26000000-0000-4000-8000-000000000001', 'boxed', 'Boxed', 0, 10),
  ('26000000-0000-4000-8000-000000000002', 'wrapped', 'Wrapped', 5000, 20),
  ('26000000-0000-4000-8000-000000000003', 'loose', 'Loose', 0, 30),
  ('26000000-0000-4000-8000-000000000004', 'palletized', 'Palletized', 10000, 40),
  ('26000000-0000-4000-8000-000000000005', 'containerized', 'Containerized', 25000, 50),
  ('26000000-0000-4000-8000-000000000006', 'bulk', 'Bulk', 15000, 60);

insert into public.cargo_restrictions (cargo_type_id, restriction_type, restricted_with_cargo_type_id, restriction_details, description) values
  ('25000000-0000-4000-8000-000000000010', 'cannot_combine', '25000000-0000-4000-8000-000000000005', '{}', 'Hazardous materials cannot be carried with fresh produce.'),
  ('25000000-0000-4000-8000-000000000010', 'requires_certificate', null, '{"certificate":"hazmat"}', 'Hazardous materials require a hazardous-goods certificate.'),
  ('25000000-0000-4000-8000-000000000009', 'requires_certificate', null, '{"certificate":"veterinary"}', 'Livestock requires a valid veterinary movement certificate.'),
  ('25000000-0000-4000-8000-000000000006', 'requires_special_vehicle', null, '{"vehicle_type":"refrigerated_truck"}', 'Refrigerated goods require a refrigerated vehicle.'),
  ('25000000-0000-4000-8000-000000000008', 'time_restricted', null, '{"hours":"22:00-05:00"}', 'Heavy machinery movements are restricted to approved night windows.');

-- ---------------------------------------------------------------------------
-- 4. Tanzania verification rules, fleet, vehicles and assignments.
-- ---------------------------------------------------------------------------
insert into public.verification_checklist_templates (id, country_id, request_type, required_document_codes, optional_document_codes, description) values
  ('27000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', 'driver_verification', '{driving_licence,national_id}', '{police_clearance}', 'Tanzania driver verification.'),
  ('27000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', 'vehicle_verification', '{vehicle_registration,insurance_certificate,vehicle_inspection}', '{latra_permit}', 'Tanzania vehicle verification.'),
  ('27000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', 'business_verification', '{business_licence,tin_certificate}', '{}', 'Tanzania business verification.');

insert into public.fleets (id, country_id, primary_city_id, name, trading_name, registration_number, tax_id, contact_email, contact_phone, owner_profile_id, commission_rate_override, verified_at, verified_by) values
  ('0f1e2d3c-4b5a-4968-8776-655443322110', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', 'Mariam Logistics Fleet', 'Mariam Logistics', 'BRELA-SS-2026-001', 'TIN-SS-2026-001', 'fleet@mariamlogistics.example', '+255714000001', 'f0000000-0000-4000-8000-000000000001', 10.00, now(), 'a0000000-0000-4000-8000-000000000001');

insert into public.vehicles (id, country_id, home_city_id, primary_driver_id, owner_type, owner_profile_id, owner_fleet_id, vehicle_type_id, make_id, model_id, year, registration_number, registration_country_id, color, capacity_kg, capacity_m3, photo_urls, verification_status, verified_at, verified_by) values
  ('28000000-0000-4000-8000-000000000001', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'fleet', null, '0f1e2d3c-4b5a-4968-8776-655443322110', '22000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', (select id from public.vehicle_models where make_id = '21000000-0000-4000-8000-000000000001' and name = 'Hiace'), 2019, 'T 123 ABC', '33333333-0000-4000-8000-000000000001', 'White', 1200, 10, '{vehicles/hiace-1.jpg}', 'verified', now(), 'a0000000-0000-4000-8000-000000000001'),
  ('28000000-0000-4000-8000-000000000002', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', 'individual', 'd0000000-0000-4000-8000-000000000002', null, '22000000-0000-4000-8000-000000000002', '21000000-0000-4000-8000-000000000001', (select id from public.vehicle_models where make_id = '21000000-0000-4000-8000-000000000001' and name = 'Hilux'), 2020, 'T 456 DEF', '33333333-0000-4000-8000-000000000001', 'Silver', 1500, 8, '{vehicles/hilux-1.jpg}', 'verified', now(), 'a0000000-0000-4000-8000-000000000001'),
  ('28000000-0000-4000-8000-000000000003', '33333333-0000-4000-8000-000000000001', '55555555-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000003', 'individual', 'd0000000-0000-4000-8000-000000000003', null, '22000000-0000-4000-8000-000000000003', '21000000-0000-4000-8000-000000000003', (select id from public.vehicle_models where make_id = '21000000-0000-4000-8000-000000000003' and name = 'Canter'), 2018, 'T 789 GHI', '33333333-0000-4000-8000-000000000001', 'Blue', 5000, 25, '{vehicles/canter-1.jpg}', 'verified', now(), 'a0000000-0000-4000-8000-000000000001');

insert into public.fleet_members (fleet_id, driver_id, role) values
  ('0f1e2d3c-4b5a-4968-8776-655443322110', 'd0000000-0000-4000-8000-000000000001', 'driver'),
  ('0f1e2d3c-4b5a-4968-8776-655443322110', 'd0000000-0000-4000-8000-000000000002', 'driver');
insert into public.fleet_vehicles (fleet_id, vehicle_id) values ('0f1e2d3c-4b5a-4968-8776-655443322110', '28000000-0000-4000-8000-000000000001');
insert into public.vehicle_assignments (vehicle_id, driver_id, assigned_by) values
  ('28000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001'),
  ('28000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000002'),
  ('28000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000003');
update public.drivers set current_vehicle_id = case id
  when 'd0000000-0000-4000-8000-000000000001' then '28000000-0000-4000-8000-000000000001'::uuid
  when 'd0000000-0000-4000-8000-000000000002' then '28000000-0000-4000-8000-000000000002'::uuid
  when 'd0000000-0000-4000-8000-000000000003' then '28000000-0000-4000-8000-000000000003'::uuid end,
  current_fleet_id = case when id in ('d0000000-0000-4000-8000-000000000001'::uuid, 'd0000000-0000-4000-8000-000000000002'::uuid) then '0f1e2d3c-4b5a-4968-8776-655443322110'::uuid else null end
where id in ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000003');

insert into public.vehicle_equipment (vehicle_id, equipment_id, quantity, condition, last_verified_at) values
  ('28000000-0000-4000-8000-000000000001', '23000000-0000-4000-8000-000000000001', 4, 'good', now()),
  ('28000000-0000-4000-8000-000000000001', '23000000-0000-4000-8000-000000000002', 6, 'good', now()),
  ('28000000-0000-4000-8000-000000000002', '23000000-0000-4000-8000-000000000001', 2, 'good', now()),
  ('28000000-0000-4000-8000-000000000002', '23000000-0000-4000-8000-000000000003', 1, 'fair', now()),
  ('28000000-0000-4000-8000-000000000003', '23000000-0000-4000-8000-000000000001', 8, 'good', now()),
  ('28000000-0000-4000-8000-000000000003', '23000000-0000-4000-8000-000000000004', 1, 'good', now()),
  ('28000000-0000-4000-8000-000000000003', '23000000-0000-4000-8000-000000000005', 2, 'good', now());

-- ---------------------------------------------------------------------------
-- 5. Verified documents, queue examples, history and pending reminders.
-- ---------------------------------------------------------------------------
insert into public.driver_documents (driver_id, document_type_id, document_number, issued_at, expires_at, file_path, verification_status, verified_at, verified_by) select d.id, dt.id, 'DL-' || right(d.id::text, 6), current_date - interval '1 year', current_date + interval '3 years', 'driver-documents/' || d.id || '/licence.pdf', 'verified', now(), 'a0000000-0000-4000-8000-000000000001' from public.drivers d cross join public.document_types dt where d.id in ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000003') and dt.code = 'driving_licence';
insert into public.driver_documents (driver_id, document_type_id, document_number, issued_at, expires_at, file_path, verification_status, verified_at, verified_by) select d.id, dt.id, 'NIDA-' || right(d.id::text, 6), current_date - interval '1 year', current_date + interval '5 years', 'driver-documents/' || d.id || '/national-id.pdf', 'verified', now(), 'a0000000-0000-4000-8000-000000000001' from public.drivers d cross join public.document_types dt where d.id in ('d0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000003') and dt.code = 'national_id';
insert into public.vehicle_documents (vehicle_id, document_type_id, document_number, issued_at, expires_at, file_path, verification_status, verified_at, verified_by) select v.id, dt.id, dt.code || '-' || right(v.id::text, 6), current_date - interval '1 month', current_date + case when dt.code = 'vehicle_inspection' then interval '5 months' else interval '11 months' end, 'vehicle-documents/' || v.id || '/' || dt.code || '.pdf', 'verified', now(), 'a0000000-0000-4000-8000-000000000001' from public.vehicles v cross join public.document_types dt where dt.code in ('vehicle_registration', 'insurance_certificate', 'vehicle_inspection');

insert into public.verification_requests (
  id, request_type, driver_id, vehicle_id, requested_by, assigned_to, assigned_at,
  status, priority, submitted_at, reviewed_at, decided_at, decision_notes, sla_due_at
) values
  ('29000000-0000-4000-8000-000000000001', 'driver_verification', 'd0000000-0000-4000-8000-000000000003', null, 'd0000000-0000-4000-8000-000000000003', null, null,
   'pending', 'normal', now() - interval '2 hours', null, null, null, now() + interval '22 hours'),
  ('29000000-0000-4000-8000-000000000002', 'vehicle_verification', null, '28000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000003', null, null,
   'pending', 'high', now() - interval '1 hour', null, null, null, now() + interval '11 hours'),
  ('29000000-0000-4000-8000-000000000003', 'driver_verification', 'd0000000-0000-4000-8000-000000000001', null, 'd0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', now() - interval '2 days',
   'approved', 'normal', now() - interval '2 days', now() - interval '1 day', now() - interval '1 day', 'All driver documents verified.', now() - interval '23 hours'),
  ('29000000-0000-4000-8000-000000000004', 'vehicle_verification', null, '28000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', now() - interval '2 days',
   'approved', 'normal', now() - interval '2 days', now() - interval '1 day', now() - interval '1 day', 'All vehicle documents verified.', now() - interval '23 hours');
insert into public.verification_history (verification_request_id, driver_id, vehicle_id, action, actor_id, notes) values
  ('29000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000001', null, 'submitted', 'd0000000-0000-4000-8000-000000000001', 'Driver submitted licence and national ID.'),
  ('29000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000001', null, 'assigned', 'a0000000-0000-4000-8000-000000000001', 'Assigned to verification queue.'),
  ('29000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000001', null, 'approved', 'a0000000-0000-4000-8000-000000000001', 'All driver documents verified.'),
  ('29000000-0000-4000-8000-000000000004', null, '28000000-0000-4000-8000-000000000001', 'submitted', 'f0000000-0000-4000-8000-000000000001', 'Fleet submitted vehicle documents.'),
  ('29000000-0000-4000-8000-000000000004', null, '28000000-0000-4000-8000-000000000001', 'assigned', 'a0000000-0000-4000-8000-000000000001', 'Assigned to verification queue.'),
  ('29000000-0000-4000-8000-000000000004', null, '28000000-0000-4000-8000-000000000001', 'approved', 'a0000000-0000-4000-8000-000000000001', 'All vehicle documents verified.');
insert into public.document_expiry_reminders (driver_document_id, reminder_type, scheduled_for, delivery_channel, delivery_status)
select dd.id, '30_days', dd.expires_at::timestamptz - interval '30 days', 'push', 'pending'
from public.driver_documents dd
where dd.driver_id = 'd0000000-0000-4000-8000-000000000001'
  and dd.document_type_id = '20000000-0000-4000-8000-000000000001'
union all
select dd.id, '30_days', dd.expires_at::timestamptz - interval '30 days', 'sms', 'pending'
from public.driver_documents dd
where dd.driver_id = 'd0000000-0000-4000-8000-000000000002'
  and dd.document_type_id = '20000000-0000-4000-8000-000000000002';

insert into public.document_expiry_reminders (vehicle_document_id, reminder_type, scheduled_for, delivery_channel, delivery_status)
select vd.id, '30_days', vd.expires_at::timestamptz - interval '30 days', 'email', 'pending'
from public.vehicle_documents vd
where vd.vehicle_id = '28000000-0000-4000-8000-000000000001'
  and vd.document_type_id = '20000000-0000-4000-8000-000000000006';

commit;
