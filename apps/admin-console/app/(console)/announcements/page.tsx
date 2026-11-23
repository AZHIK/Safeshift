import { randomUUID } from 'node:crypto';
import { redirect } from 'next/navigation';
import { ConfirmSubmit } from '@/components/confirm-submit';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { DataTable } from '@/components/data-table';
import { requireConfigurationPermission } from '@/lib/configuration/guard';
import { createClient } from '@/lib/supabase/server';
import { formatDate } from '@/lib/format';
import { RecordActions } from '@/components/record-actions';

async function publish(form:FormData) {
  'use server';
  await requireConfigurationPermission('send_notification');
  const client=await createClient();
  const {data,error}=await client.rpc('admin_announce',{p_id:form.get('id'),p_country:form.get('country'),p_city:form.get('city')||null,p_audience:form.get('audience'),p_title:form.get('title'),p_body:form.get('body')});
  redirect('/announcements?'+(error?'error=Could not publish. Check the country, city and your permissions.':'ok=Delivered to '+data+' inboxes.'));
}
export default async function Announcements({searchParams}:{searchParams:Promise<Record<string,string>>}) {
  await requireConfigurationPermission('send_notification');
  const client=await createClient();
  const [countries,cities,history]=await Promise.all([client.from('countries').select('id,name').order('name'),client.from('cities').select('id,name,countries(name)').order('name'),client.from('announcements').select('id,title,audience,recipient_count,created_at').order('created_at',{ascending:false}).limit(50)]);
  return <><PageHeader records={['announcements']} title="Announcements" description="Send a message to customer and driver inboxes in an operating country or city."/><Notice searchParams={await searchParams}/>
    <form action={publish} className="card card-pad form"><input type="hidden" name="id" value={randomUUID()}/>
      <label className="field">Country<select required className="input" name="country" defaultValue=""><option value="" disabled>Choose country</option>{countries.data?.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
      <label className="field">City<select className="input" name="city"><option value="">All cities in country</option>{cities.data?.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
      <label className="field">Audience<select className="input" name="audience"><option value="customer">Customers</option><option value="driver">Drivers</option><option value="all">Customers and drivers</option></select></label>
      <label className="field">Title<input className="input" name="title" required maxLength={140}/></label>
      <label className="field">Message<textarea className="input" name="body" required maxLength={4000}/></label>
      <ConfirmSubmit className="btn btn-primary" message="Send this announcement to every account in the selected audience?">Send announcement</ConfirmSubmit>
    </form><h2>Delivery history</h2>{history.error ? <p role="alert">Could not load delivery history.</p> :
      <DataTable columns={['Title','Audience','Recipients','Sent']} rows={(history.data??[]).map(r=>[r.title,r.audience,r.recipient_count,formatDate(r.created_at)])} actions={(history.data??[]).map(r=><RecordActions key={r.id} table="announcements" id={r.id}/>)} empty="No announcements sent."/>}</>;
}
