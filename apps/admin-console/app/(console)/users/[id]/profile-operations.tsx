import {redirect} from 'next/navigation';
import {getCallerPermissions,requireConfigurationPermission} from '@/lib/configuration/guard';
import {ConfirmSubmit} from '@/components/confirm-submit';
import {createClient} from '@/lib/supabase/server';
async function update(id:string,op:string,f:FormData){'use server';await requireConfigurationPermission(op==='edit_profile'?'manage_customers':'suspend_user');const db=await createClient();
 const {error}=await db.rpc('admin_update_account',{p_id:id,p_operation:op,p_reason:f.get('reason'),p_full_name:f.get('full_name'),p_display_name:f.get('display_name')});
 redirect('/users/'+encodeURIComponent(id)+'?'+(error?'error='+encodeURIComponent('Could not update this account: '+error.message):'ok=Account updated.'));}
export async function ProfileOperations({id,fullName,displayName}:{id:string;fullName:string|null;displayName:string|null}){
 const {permissions}=await getCallerPermissions();
 return <div className="section-stack">{permissions.has('manage_customers')&&<details className="card card-pad"><summary>Edit profile</summary><form action={update.bind(null,id,'edit_profile')} className="form"><label className="field">Full name<input name="full_name" className="input" required defaultValue={fullName??''}/></label><label className="field">Display name<input name="display_name" className="input" defaultValue={displayName??''}/></label><label className="field">Reason<input className="input" name="reason" required minLength={3}/></label><button className="btn">Save profile</button></form></details>}
 {permissions.has('suspend_user')&&<details className="card card-pad"><summary>End sign-in sessions</summary><form action={update.bind(null,id,'end_sessions')} className="form"><p>Existing access tokens expire at the end of their lifetime. Signing in again starts a new session.</p><label className="field">Reason<input name="reason" className="input" minLength={3} required/></label><ConfirmSubmit className="btn btn-danger" message="End this account’s refresh sessions?">End sessions</ConfirmSubmit></form></details>}</div>;
}
