'use server';
import * as config from '@/lib/configuration/action-helpers';
import { policyResources } from '@/lib/configuration/resources/policies';
import type { AuditQuery } from '@/components/configuration/audit-history-button';
import type { ConfigFieldValues,ListFilters } from '@/lib/configuration/types';

function resource(slug:string) {
  if (!Object.hasOwn(policyResources,slug)) throw Error('Unknown policy');
  return policyResources[slug];
}
export async function list(slug:string,filters:ListFilters) {return config.listConfigurationRecords(resource(slug),filters);}
export async function create(slug:string,values:ConfigFieldValues) {return config.createConfigurationRecord(resource(slug),values);}
export async function update(slug:string,id:string,values:ConfigFieldValues) {return config.updateConfigurationRecord(resource(slug),id,values);}
export async function remove(slug:string,id:string) {
  const r=resource(slug);
  if (!r.hardDelete) return {success:false,error:'Deactivate this policy to retain its history.'};
  return config.deleteConfigurationRecord(r,id);
}
export async function deactivate(slug:string,id:string,reason:string) {
  const r=resource(slug);
  if (!r.softDelete) return {success:false,error:'This policy is controlled by its effective dates.'};
  return config.deactivateConfigurationRecord(r,id,reason);
}
export async function audit(slug:string,id:string,query:AuditQuery) {return config.configurationAuditHistory(resource(slug),id,query);}
