import {notFound,redirect} from 'next/navigation';
import {DataTable} from '@/components/data-table';
import {PageHeader} from '@/components/page-header';
import {Notice} from '@/components/notice';
import {requireArea} from '@/lib/guard';
import {getCallerPermissions,requireConfigurationPermission} from '@/lib/configuration/guard';
import {createClient} from '@/lib/supabase/server';
import {formatDate,titleize} from '@/lib/format';
import { RecordActions } from '@/components/record-actions';
async function add(id:string,f:FormData){'use server';await requireConfigurationPermission('manage_incidents');const db=await createClient();const {error}=await db.rpc('admin_incident_action',{p_id:id,p_note:f.get('note'),p_contact:f.get('contact')||null});
 redirect('/incidents/'+encodeURIComponent(id)+'?'+(error?'error='+encodeURIComponent('Could not record this action: '+error.message):'ok=Action recorded.'));}
export default async function Incident({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<Record<string,string>>}){
 await requireArea('incidents');const {id}=await params;const {permissions}=await getCallerPermissions();const db=await createClient();
 const [info,timeline,contacts]=await Promise.all([db.from('incidents').select('id,incident_type,description,status,severity').eq('id',id).maybeSingle(),db.from('incident_actions').select('id,action_type,actor_id,notes,to_status,created_at').eq('incident_id',id).order('created_at'),db.rpc('admin_incident_contacts',{p_id:id})]);
 if(info.error||timeline.error)throw Error('Could not load incident');const i=info.data;if(!i)notFound();
 return <><PageHeader title={titleize(i.incident_type)+' incident'} description={titleize(i.severity)+' · '+titleize(i.status)} actions={<RecordActions table="incidents" id={i.id} label="Incident actions"/>}/><Notice searchParams={await searchParams}/><p>{i.description}</p><h2>Action timeline</h2><DataTable columns={['When','Action','Actor','Status','Notes']} rows={(timeline.data??[]).map(a=>[formatDate(a.created_at),titleize(a.action_type),a.actor_id,a.to_status,a.notes])} actions={(timeline.data??[]).map(a=><RecordActions key={a.id} table="incident_actions" id={a.id} items={a.actor_id?[{kind:'link',label:'Open actor',href:'/users/'+a.actor_id}]:[]}/>)}/>
 {permissions.has('manage_incidents')&&<form className="card card-pad form" action={add.bind(null,id)}><h2>Log follow-up</h2><label className="field">Emergency contact<select className="input" name="contact"><option value="">Internal note</option>{(contacts.data??[]).map((c:{id:string;name:string;phone:string;relationship:string})=><option key={c.id} value={c.id}>{c.name} · {c.phone} · {c.relationship}</option>)}</select></label><label className="field">Action taken<textarea className="input" name="note" minLength={3} required/></label><button className="btn">Record note or contact attempt</button></form>}</>;
}
