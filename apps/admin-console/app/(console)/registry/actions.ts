'use server';
import { redirect } from 'next/navigation';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { createClient } from '@/lib/supabase/server';

export async function changeProviderRequest(subject:string,kind:string,cancelId:string|null){
 const fiscal=kind==='fiscal_receipt';
 await requireConfigurationPermission(fiscal?'manage_invoices':'verify_driver');
 const db=await createClient();
 const result=cancelId?await db.rpc('admin_cancel_provider_request',{p_id:cancelId}):await db.rpc('admin_request_provider',{p_kind:kind,p_subject:subject});
 const path=fiscal?'/invoices/'+encodeURIComponent(subject):'/registry';
 redirect(path+'?'+(result.error?'error=Could not change this provider request. Check its status and your territory.':cancelId?'ok=Request cancelled.':'ok=Request queued for provider integration.'));
}
