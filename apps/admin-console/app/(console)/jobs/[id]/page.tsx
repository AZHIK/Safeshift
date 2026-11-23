import { notFound,redirect } from 'next/navigation';
import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { Notice } from '@/components/notice';
import { formatDate,formatMoney,titleize } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { getCallerPermissions } from '@/lib/configuration/guard';
import { createClient } from '@/lib/supabase/server';
import { RecordActions } from '@/components/record-actions';
import { RowMenu } from '@/components/row-menu';
async function save(id:string,f:FormData){
  'use server';
  await requireArea('jobs');const db=await createClient();
  const result=f.has('driver') ? await db.rpc('admin_assign_job',{p_job:id,p_driver:f.get('driver'),p_reason:f.get('reason')}) :
    await db.rpc('admin_update_job',{p_job:id,p_reason:f.get('reason'),p_amount:f.get('amount')||null});
  redirect('/jobs/'+encodeURIComponent(id)+'?'+(result.error?'error='+encodeURIComponent(result.error.message):'ok=Change saved.'));
}
export default async function Job({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<Record<string,string>>}){
 const {id}=await params;await requireArea('jobs');const db=await createClient();const {permissions}=await getCallerPermissions();
 const [job,history,candidates,changes]=await Promise.all([
  db.from('jobs').select('id,status,driver_id,customer_id,final_amount,final_currency_code,payment_status,distance_km,created_at,quotes(quote_requests(pickup_address,destination_address))').eq('id',id).maybeSingle(),
  db.from('job_status_history').select('id,to_status,reason,created_at').eq('job_id',id).order('created_at'),
  db.rpc('admin_job_candidates',{p_job:id}),db.rpc('admin_audit_history',{p_entity_type:'jobs',p_entity_id:id,p_permission:'view_all_jobs',p_limit:100})
 ]);
 if(job.error) return <p role="alert">Could not load this job.</p>;
 const j=job.data;if(!j) notFound();
 const route=(j.quotes as unknown as {quote_requests:{pickup_address:string;destination_address:string}})?.quote_requests;
 return <><PageHeader title={'Job '+id} description={titleize(j.status)+' · '+formatMoney(j.final_amount,j.final_currency_code)} actions={<RecordActions table="jobs" id={id} label="Job actions" items={[...(j.customer_id?[{kind:'link' as const,label:'Open customer',href:'/users/'+j.customer_id}]:[]),...(j.driver_id?[{kind:'link' as const,label:'Open driver',href:'/drivers/'+j.driver_id}]:[])]}/>}/><Notice searchParams={await searchParams}/>
 <div className="section-stack"><section className="card card-pad"><p>{route?.pickup_address} → {route?.destination_address} · {j.distance_km} km</p><p>Customer · {j.customer_id}</p><p>Driver · {j.driver_id??'Unassigned'}</p></section>
 <h2>Status history</h2><DataTable columns={['When','Status','Reason']} rows={(history.data??[]).map(h=>[formatDate(h.created_at),titleize(h.to_status),h.reason])} actions={(history.data??[]).map(h=><RecordActions key={h.id} table="job_status_history" id={h.id}/>)}/>
 {permissions.has('assign_drivers') && ['requested','quoted','matched'].includes(j.status) && <form action={save.bind(null,id)} className="card card-pad form"><h2>Assign driver</h2><label className="field">Available driver<select className="input" name="driver" required defaultValue=""><option value="">Choose verified driver</option>{(candidates.data??[]).map((c:{id:string;name:string;registration:string})=><option key={c.id} value={c.id}>{c.name} · {c.registration}</option>)}</select></label>
 <label className="field">Reason<input className="input" name="reason" minLength={3} required/></label><button className="btn" disabled={!candidates.data?.length}>Assign</button></form>}
 {permissions.has('manage_dispatch') && <form className="card card-pad form" action={save.bind(null,id)}><label className="field">Internal job note<textarea className="input" name="reason" required minLength={3}/></label><button className="btn">Save note</button></form>}
 {permissions.has('adjust_pricing') && j.payment_status==='pending' && !['completed','cancelled','disputed'].includes(j.status) && <form className="card card-pad form" action={save.bind(null,id)}><label className="field">New fare ({j.final_currency_code})<input className="input" name="amount" type="number" min="0.01" step="0.01" required/></label><label className="field">Reason<input className="input" name="reason" required minLength={3}/></label><button className="btn">Adjust fare</button></form>}
 <h2>Operations history</h2><DataTable columns={['When','Action','Operator','Note']} rows={(changes.data??[]).map((r:{created_at:string;action:string;actor_name:string;new_value?:{staff_note?:string;reason?:string}})=>[formatDate(r.created_at),titleize(r.action),r.actor_name,r.new_value?.staff_note??r.new_value?.reason??'—'])} actions={(changes.data??[]).map((_:unknown,i:number)=><RowMenu key={i} items={[{kind:'link',label:'Open audit log',href:'/audit'}]}/>)}/>
 </div></>;
}
