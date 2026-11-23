import type { ConfigField, ConfigResource } from '../types';

const select = (name: string,label: string,optionsKey: string,required=false): ConfigField => ({ name,label,optionsKey,required,type:'select' });
const choice = (name: string,label: string,values: string[]): ConfigField => ({ name,label,required:true,type:'select',options:values.map(value=>({value,label:value.replaceAll('_',' ')})) });
const number = (name: string,label: string,min: number,max?: number,required=true): ConfigField => ({name,label,type:'number',min,max,required,step:0.0001});
const date = (name: string,label: string,required=false): ConfigField => ({ name,label:label+' (UTC)',type:'datetime',required });
const active: ConfigField = {name:'is_active',label:'Active',type:'checkbox',defaultValue:true};
const effective = [date('effective_from','Starts',true),date('effective_to','Ends')];
const country = select('country_id','Country','countries',true);
const city = select('city_id','City','cities');
const zone = select('service_zone_id','Service zone','service_zones');
const vehicle = select('vehicle_type_id','Vehicle type','vehicle_types');
const reason: ConfigField = {name:'reason',label:'Reason',type:'text'};

export const policyResources: Record<string,ConfigResource> = {
  'saved-replies': {
    table:'support_saved_replies', singular:'saved reply', singularTitle:'Saved reply', pluralTitle:'Saved replies',
    description:'Reusable replies that support agents can edit before sending.', permission:'manage_support',group:'Support & Safety',
    softDelete:true,selectSpec:'*',searchColumns:['name','body'],defaultSort:{column:'name',ascending:true},
    columns:[{key:'name',label:'Name'},{key:'body',label:'Reply'},{key:'is_active',label:'Active',kind:'boolean'}],
    fields:[{name:'name',label:'Name',type:'text',required:true},{name:'body',label:'Reply',type:'textarea',required:true},active],
  },
  'tax-rates': {
    table:'tax_rates', singular:'tax rate',singularTitle:'Tax rate',pluralTitle:'Tax rates',description:'Country tax rates and their effective dates. Enter 0.18 for 18%.',
    permission:'manage_taxes',group:'Commercial',countryScoped:true,softDelete:true,
    selectSpec:'*,countries(name)',searchColumns:['name'],columns:[{key:'name',label:'Name'},{key:'countries_name',label:'Country'},{key:'rate',label:'Rate'},{key:'applies_to',label:'Applies to'},{key:'effective_from',label:'Starts',kind:'date'},{key:'is_active',label:'Active',kind:'boolean'}],
    fields:[country,{name:'name',label:'Name',type:'text',required:true},choice('tax_type','Tax type',['vat','withholding','service_tax','other']),choice('applies_to','Applies to',['customer_charge','driver_payout','platform_revenue']),number('rate','Rate (fraction)',0,1),...effective,{name:'notes',label:'Notes',type:'textarea'},active],
  },
  'commission-rules': {
    table:'commission_rules',singular:'commission rule',singularTitle:'Commission rule',pluralTitle:'Commission rules',description:'Set commission by driver, fleet, vehicle type, city or country. Empty scopes apply platform-wide.',
    permission:'manage_commission',group:'Commercial',softDelete:true,countryScoped:true,selectSpec:'*,countries(name),cities(name),fleets(name),vehicle_types(name)',
    columns:[{key:'commission_type',label:'Type'},{key:'commission_value',label:'Value'},{key:'countries_name',label:'Country'},{key:'cities_name',label:'City'},{key:'fleets_name',label:'Fleet'},{key:'effective_from',label:'Starts',kind:'date'},{key:'is_active',label:'Active',kind:'boolean'}],
    fields:[{...country,required:false},city,vehicle,select('fleet_id','Fleet','fleets'),{name:'driver_id',label:'Driver ID',type:'text'},choice('commission_type','Type',['percentage','flat_fee']),number('commission_value','Commission value',0),{...number('min_commission','Minimum',0),defaultValue:0},number('max_commission','Maximum',0,undefined,false),{name:'priority',label:'Priority',type:'number',defaultValue:0},...effective,active],
  },
  'surge': {
    table:'surge_multipliers',singular:'surge window',singularTitle:'Surge window',pluralTitle:'Surge windows',description:'Time-limited demand multipliers by city, service zone and vehicle type.',
    permission:'manage_surge',group:'Commercial',hardDelete:true,selectSpec:'*,cities(name),service_zones(name),vehicle_types(name)',searchColumns:['reason'],
    columns:[{key:'cities_name',label:'City'},{key:'service_zones_name',label:'Zone'},{key:'vehicle_types_name',label:'Vehicle'},{key:'multiplier',label:'Multiplier'},{key:'starts_at',label:'Starts',kind:'date'},{key:'ends_at',label:'Ends',kind:'date'}],
    fields:[{...city,required:true},zone,vehicle,number('multiplier','Multiplier',1,5),reason,date('starts_at','Starts',true),date('ends_at','Ends',true)],
  },
  'zone-overrides': {
    table:'zone_pricing_overrides',singular:'zone override',singularTitle:'Zone override',pluralTitle:'Zone price overrides',description:'Time-limited price adjustments for a service zone and optional plan version.',
    permission:'adjust_pricing',group:'Commercial',hardDelete:true,selectSpec:'*,service_zones(name),pricing_plan_versions(version_number)',searchColumns:['reason'],
    columns:[{key:'service_zones_name',label:'Service zone'},{key:'pricing_plan_id',label:'Plan version'},{key:'multiplier',label:'Multiplier'},{key:'effective_from',label:'Starts',kind:'date'}],
    fields:[{...zone,required:true},select('pricing_plan_id','Plan version','pricing_versions'),{...number('multiplier','Multiplier',0.01,5),step:0.01},reason,...effective],
  },
  'retention': {
    table:'retention_policies',singular:'retention policy',singularTitle:'Retention policy',pluralTitle:'Data retention',description:'Configure scheduled deletion for supported data sets. Historical run counts show the last execution.',
    permission:'manage_retention',group:'Governance',softDelete:true,selectSpec:'*',searchColumns:['table_name'],
    columns:[{key:'table_name',label:'Table'},{key:'action',label:'Action'},{key:'retention_period',label:'Keep for'},{key:'last_run_at',label:'Last run',kind:'date'},{key:'last_run_rows_affected',label:'Rows affected'},{key:'is_active',label:'Active',kind:'boolean'}],
    fields:[choice('table_name','Table',['driver_locations','job_events','audit_log','chat_messages','notification_log','data_access_log','demand_snapshots']),{name:'retention_period',label:'Keep for',type:'text',placeholder:'90 days',required:true},choice('action','Scheduled action',['delete']),{name:'notes',label:'Notes',type:'textarea'},active],
  },
};
