import {PageHeader} from '@/components/page-header';
import {DataTable} from '@/components/data-table';
import {Notice} from '@/components/notice';
import {requireConfigurationPermission} from '@/lib/configuration/guard';
import {createClient} from '@/lib/supabase/server';
import {formatDate,titleize} from '@/lib/format';
import {changeProviderRequest} from './actions';
async function request(form:FormData){'use server';await changeProviderRequest(String(form.get('document')),String(form.get('kind')),null);}
export default async function Registry({searchParams}:{searchParams:Promise<Record<string,string>>}){
 await requireConfigurationPermission('verify_driver');const params=await searchParams;const db=await createClient();
 const {data,error}=await db.from('provider_requests').select('id,document_id,kind,status,provider_reference,created_at').not('document_id','is',null).order('created_at',{ascending:false}).limit(50);
 return <><PageHeader records={['registry']} title="Identity registry checks" description="Queue checks for current driver documents. Results require a connected registry provider."/><Notice searchParams={params}/><form action={request} className="card card-pad form">
 <label className="field">Driver document ID<input className="input" name="document" defaultValue={params.document??''} required/></label><label className="field">Registry<select className="input" name="kind"><option value="national_id">National identity (NIDA in Tanzania)</option><option value="driving_licence">Driving licence</option><option value="tax_id">Tax identification (TIN)</option></select></label><button className="btn btn-primary">Request check</button></form>
 <h2>Recent checks</h2>{error?<p role="alert">Could not load checks.</p>:<DataTable columns={['Document','Check','Status','Provider reference','Requested','Action']} rows={(data??[]).map(r=>[r.document_id,titleize(r.kind),titleize(r.status),r.provider_reference??'—',formatDate(r.created_at),r.status==='awaiting_integration'?<form key={r.id} action={changeProviderRequest.bind(null,r.document_id,r.kind,r.id)}><button className="btn btn-sm">Cancel</button></form>:null])}/>}</>;
}
