'use server';
import { redirect } from 'next/navigation';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { createClient } from '@/lib/supabase/server';

export async function prepareInvoice(form:FormData) {
  await requireConfigurationPermission('manage_invoices');
  const db=await createClient();
  const account=form.get('account');
  if(form.has('job')){
    const {error}=await db.rpc('admin_allocate_business_job',{p_account:account,p_job:form.get('job'),p_reason:form.get('reason')});
    redirect('/invoices?'+(error?'error=Could not allocate this job. Check membership, territory and prior billing.':'ok=Business job allocated.'));
  }
  const start=String(form.get('start')),end=String(form.get('end'));
  if(!/^\d{4}-\d{2}-\d{2}$/.test(start)||!/^\d{4}-\d{2}-\d{2}$/.test(end)||start>end||!Number.isFinite(Date.parse(end)))redirect('/invoices?error=Enter a valid date range.');
  const {error,data}=await db.rpc('generate_invoice',{p_business_account_id:account,p_period_start:start+'T00:00:00Z',p_period_end:new Date(Date.parse(end)+86400000).toISOString()});
  if(error)redirect('/invoices?error=Could not generate a draft. Check for unbilled business jobs in the period.');
  redirect('/invoices/'+data);
}
export async function issueInvoice(id:string) {
  await requireConfigurationPermission('manage_invoices');
  const db=await createClient();
  const {error}=await db.rpc('admin_issue_invoice',{p_invoice:id});
  redirect('/invoices/'+encodeURIComponent(id)+'?'+(error?'error=Could not issue this invoice.':'ok=Invoice issued to business members.'));
}
