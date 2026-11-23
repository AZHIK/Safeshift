import Link from 'next/link';
import { PageHeader } from '@/components/page-header';
import { DataTable } from '@/components/data-table';
import { Notice } from '@/components/notice';
import { getCallerPermissions } from '@/lib/configuration/guard';
import { requireArea } from '@/lib/guard';
import { formatMoney,formatDate } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { prepareInvoice } from './actions';
export default async function Invoices({searchParams}:{searchParams:Promise<Record<string,string>>}){
 await requireArea('invoices');
 const db=await createClient(),{permissions}=await getCallerPermissions();
 const [list,accounts]=await Promise.all([db.from('invoices').select('id,invoice_number,status,total,currency_code,created_at').order('created_at',{ascending:false}).limit(50),db.rpc('admin_billable_accounts')]);
 const select=<label className="field">Business account<select required className="input" defaultValue="" name="account"><option value="" disabled>Select account</option>{(accounts.data??[]).map((a:{id:string;name:string})=><option value={a.id} key={a.id}>{a.name}</option>)}</select></label>;
 return <><PageHeader records={['invoices']} title="Business invoices" description="Review completed business jobs, issue invoices and track fiscal receipts."/><Notice searchParams={await searchParams}/>
 {permissions.has('manage_invoices')&&<div className="section-stack"><form action={prepareInvoice} className="card card-pad form"><h2>Prepare invoice</h2>{select}<label className="field">From (UTC)<input type="date" className="input" name="start" required/></label><label className="field">Through (UTC)<input type="date" className="input" name="end" required/></label><button className="btn btn-primary">Generate draft</button></form>
 <details className="card card-pad"><summary>Allocate a one-off business job</summary><form action={prepareInvoice} className="form">{select}<label className="field">Completed job ID<input className="input" name="job" required/></label><label className="field">Billing evidence<input className="input" name="reason" minLength={3} required/></label><button className="btn">Allocate job</button></form></details></div>}
 <h2>Recent invoices</h2>{list.error?<p role="alert">Could not load invoices.</p>:<DataTable columns={['Number','Status','Total','Created']} rows={(list.data??[]).map(i=>[<Link key={i.id} href={'/invoices/'+i.id}>{i.invoice_number}</Link>,i.status,formatMoney(i.total,i.currency_code),formatDate(i.created_at)])}/>}</>;
}
