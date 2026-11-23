import {randomUUID} from 'node:crypto';
import {redirect} from 'next/navigation';
import {requireConfigurationPermission} from '@/lib/configuration/guard';
import {createClient} from '@/lib/supabase/server';
async function onboard(f:FormData){'use server';await requireConfigurationPermission('manage_fleets');const db=await createClient();
 const {error}=await db.rpc('admin_onboard_fleet',{p_id:f.get('id'),p_city:f.get('city'),p_name:f.get('name'),p_registration:f.get('registration'),p_owner:f.get('owner')});
 redirect('/fleets?'+(error?'error='+encodeURIComponent('Could not onboard fleet: '+error.message):'ok=Fleet onboarded.'));}
async function review(id:string,op:string,f:FormData){'use server';await requireConfigurationPermission(op==='verify'?'manage_fleets':'manage_commission');const db=await createClient();
 const {error}=await db.rpc('admin_review_fleet',{p_id:id,p_operation:op,p_rate:f.get('rate')||null,p_reason:f.get('reason')});
 redirect('/fleets?'+(error?'error='+encodeURIComponent('Could not save fleet decision: '+error.message):'ok=Fleet updated.'));}
export async function FleetOnboarding(){
 const db=await createClient();const {data}=await db.from('cities').select('id,name').eq('is_active',true).order('name');
 return <details className="card card-pad"><summary>Onboard fleet</summary><form action={onboard} className="form"><input type="hidden" name="id" value={randomUUID()}/><label className="field">Fleet name<input className="input" name="name" required/></label><label className="field">Primary city<select className="input" name="city" required>{data?.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select></label><label className="field">Owner profile ID<input name="owner" className="input" required/></label><label className="field">Registration number<input className="input" name="registration" required/></label><button className="btn">Create fleet</button></form></details>;
}
export function FleetReview({id,mayVerify,mayBill,rate}:{id:string;mayVerify:boolean;mayBill:boolean;rate:number|null}){
 return <>{mayVerify&&<form className="form" action={review.bind(null,id,'verify')}><label className="field">Verification evidence<input className="input" name="reason" minLength={3} required/></label><button className="btn">Verify fleet</button></form>}
 {mayBill&&<details><summary>Edit fleet commission</summary><form className="form" action={review.bind(null,id,'commission')}><label className="field">Override percentage (leave blank for default)<input className="input" name="rate" type="number" min="0" max="100" step=".01" defaultValue={rate??''}/></label><label className="field">Reason<input name="reason" className="input" minLength={3} required/></label><button className="btn">Save billing terms</button></form></details>}</>;
}
