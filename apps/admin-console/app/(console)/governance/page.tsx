import { redirect } from 'next/navigation';
import { PageHeader } from '@/components/page-header';
import { Notice } from '@/components/notice';
import { requireArea } from '@/lib/guard';
import { getCallerPermissions } from '@/lib/configuration/guard';
import { createClient } from '@/lib/supabase/server';

async function save(form:FormData) {
  'use server';
  await requireArea('governance');
  const db=await createClient();
  const result=form.get('request') ? await db.rpc('admin_review_government_request',{p_id:form.get('request'),p_decision:form.get('decision'),p_note:form.get('note')}) :
    await db.rpc('admin_open_government_request',{p_country:form.get('country'),p_authority:form.get('authority'),p_reference:form.get('reference'),p_basis:form.get('basis'),p_start:form.get('start'),p_end:form.get('end')});
  redirect('/governance?'+(result.error?'error=Could not save. Check scope, reference and current request status.':'ok=Request saved.'));
}

export default async function Governance({searchParams}:{searchParams:Promise<Record<string,string>>}) {
  await requireArea('governance');
  const {permissions}=await getCallerPermissions();
  const db=await createClient();
  const [countries,requests]=await Promise.all([db.from('countries').select('id,name').order('name'),db.from('government_requests').select('id,country_id,authority,reference,legal_basis,period_start,period_end,status,review_note,last_export_at').order('created_at',{ascending:false}).limit(50)]);
  const scope=<><label className="field">Country<select className="input" name="country" required defaultValue=""><option value="">Choose country</option>{countries.data?.map(c=><option value={c.id} key={c.id}>{c.name}</option>)}</select></label>
    <label className="field">From<input type="date" className="input" name="start" required/></label><label className="field">Through<input type="date" className="input" name="end" required/></label></>;
  return <><PageHeader title="Regulatory reporting" description="Country reports cover completed trips, participating drivers and vehicles, safety incidents and recorded commission by currency."/><Notice searchParams={await searchParams}/>
    <div className="section-stack">
      {permissions.has('export_regulator_reports') && <form action="/governance/export" method="post" className="card card-pad form"><h2>Operating report</h2>{scope}<button className="btn">Download CSV</button></form>}
      {permissions.has('manage_data_requests') && <form action={save} className="card card-pad form"><h2>Government request intake</h2>{scope}
        <label className="field">Requesting authority<input className="input" name="authority" required/></label><label className="field">Authority reference<input className="input" name="reference" required/></label>
        <label className="field">Legal basis for the operating report<textarea className="input" name="basis" required minLength={3}/></label><button className="btn">Submit for review</button></form>}
      {(permissions.has('manage_data_requests') || permissions.has('review_government_requests')) && <section><h2>Government requests</h2>
      {requests.error && <p role="alert">Could not load the requests.</p>}
      {requests.data?.length===0 && <p>No requests recorded.</p>}
      {requests.data?.map(r=><article className="card card-pad" key={r.id}><h3>{r.authority} · {r.reference}</h3>
        <p>{countries.data?.find(c=>c.id===r.country_id)?.name} · {r.period_start} through {r.period_end} · {r.status}</p><p>{r.legal_basis}</p>{r.review_note && <p>Review decision · {r.review_note}</p>}
        {r.status==='pending' && permissions.has('review_government_requests') && <form className="form" action={save}>
          <input type="hidden" name="request" value={r.id}/><label className="field">Review reason<input className="input" name="note" required minLength={3}/></label><div><button className="btn" name="decision" value="approved">Approve</button> <button className="btn" name="decision" value="rejected">Reject</button></div></form>}
        {['approved','exported'].includes(r.status) && permissions.has('manage_data_requests') && <form method="post" action="/governance/export"><input type="hidden" name="request" value={r.id}/><button className="btn">Download approved report</button></form>}
      </article>)}</section>}
    </div></>;
}
