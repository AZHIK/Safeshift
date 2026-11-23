import type { SupabaseClient } from '@supabase/supabase-js';
import type { AdminSession } from './auth';

// Each list exposes only explicitly selected columns. Queries use the staff session and table RLS.
type RecordList = { table:string; area:string; title:string; columns:string[]; date:string; detail?:string };
function list(table:string, area:string, title:string, columns:string, date='created_at', detail?:string):RecordList {
  return {table,area,title,columns:columns.split(' '),date,detail};
}
export const records:Record<string,RecordList> = {
  jobs:list('jobs','jobs','Jobs','id status customer_id driver_id city_id final_amount final_currency_code payment_status created_at','created_at','/jobs/'),
  users:list('profiles','users','Accounts','id primary_role is_active default_country_id created_at','created_at','/users/'),
  drivers:list('drivers','drivers','Drivers','id verification_status home_city_id is_available total_trips rating created_at','created_at','/drivers/'),
  fleets:list('fleets','fleets','Fleets','id name registration_number is_active verified_at created_at'),
  support:list('support_tickets','support','Support tickets','id ticket_number subject status priority assigned_to sla_due_at created_at','created_at','/support/'),
  disputes:list('disputes','disputes','Disputes','id job_id dispute_type status priority created_at'),
  incidents:list('incidents','incidents','Incidents','id job_id incident_type severity status occurred_at','occurred_at'),
  alerts:list('trip_alerts','incidents','Trip alerts','id job_id alert_type status created_at'),
  verifications:list('verification_requests','verifications','Verification requests','id request_type driver_id vehicle_id status priority submitted_at','submitted_at'),
  payments:list('payments','payments','Payments','id job_id customer_id payment_type provider_reference provider_status amount currency_code initiated_at','initiated_at','/payments/'),
  payouts:list('payout_batches','payouts','Payout batches','id country_id status driver_count total_amount currency_code period_start period_end created_at','created_at','/payouts/'),
  transfers:list('payouts','payouts','Driver payouts','id batch_id driver_id net_amount currency_code status provider_reference created_at'),
  pricing:list('pricing_plans','pricing','Pricing plans','id name code country_id city_id vehicle_type_id is_active created_at','created_at','/pricing/'),
  tariffs:list('regulated_tariffs','pricing','Regulated tariffs','id name regulatory_body approval_reference currency_code effective_from effective_to is_active','effective_from'),
  promos:list('promo_codes','promos','Promos','id code name discount_type discount_value valid_from valid_to is_active created_at','created_at','/promos/'),
  analytics:list('daily_metrics','analytics','Daily metrics','id country_id city_id metric_date jobs_created jobs_completed jobs_cancelled active_drivers gross_booking_value net_revenue currency_code','metric_date'),
  audit:list('admin_actions_log','audit','Audit log','id admin_profile_id admin_role action entity_type entity_id permission_used created_at'),
  'data-requests':list('data_subject_requests','data-requests','Data requests','id request_number requester_profile_id request_type status assigned_to requested_at','requested_at'),
  consent:list('consent_records','consent','Consent ledger','id profile_id consent_type consent_version granted granted_at revoked_at created_at'),
  governance:list('government_requests','governance','Government requests','id country_id authority reference status period_start period_end created_at'),
  announcements:list('announcements','announcements','Announcement history','id country_id city_id audience title recipient_count created_at'),
  invoices:list('invoices','invoices','Invoices','id business_account_id invoice_number status subtotal tax_amount total currency_code issued_at created_at','created_at','/invoices/'),
};

export const PAGE_SIZE=50;
export function recordFilters(list:RecordList, query:URLSearchParams) {
  const member=(name:string,fallback:string)=>list.columns.includes(query.get(name)??'') ? query.get(name)! : fallback;
  const date=(name:string)=> {
    const raw=query.get(name)??'';
    if(!raw) return '';
    if(!/^\d{4}-\d{2}-\d{2}$/.test(raw) || !Number.isFinite(Date.parse(raw)) || new Date(raw).toISOString().slice(0,10)!==raw) throw Error('Enter a valid date.');
    return raw;
  };
  const start=date('start'),end=date('end');
  if(start && end && start>end) throw Error('End date must be on or after the start date.');
  return {field:member('field',list.columns[0]),q:(query.get('q')??'').trim(),sort:member('sort',list.date),ascending:query.get('dir')==='asc',page:Math.min(1_000_000,Math.max(1,Math.trunc(Number(query.get('page')))||1)),start,end};
}
export async function readRecords(db:SupabaseClient,list:RecordList,filters:ReturnType<typeof recordFilters>,session:AdminSession,offset:number,size:number) {
  let query=db.from(list.table).select(list.columns.join(','),{count:'exact'});
  if(list.table==='fleets' && session.role==='fleet_owner') query=query.eq('owner_profile_id',session.userId);
  if(filters.q) query=query.eq(filters.field,filters.q);
  if(filters.start) query=query.gte(list.date, filters.start);
  if(filters.end) query=query.lt(list.date,new Date(Date.parse(filters.end)+86400000).toISOString().slice(0,10));
  query=query.order(filters.sort,{ascending:filters.ascending});
  if(filters.sort!=='id') query=query.order('id',{ascending:true});
  const {data,error,count}=await query.range(offset,offset+size-1);
  if(error) throw Error('Could not load records. Check the filter value and your access.');
  return {rows:(data??[]) as unknown as Record<string,unknown>[],count:count??0};
}
