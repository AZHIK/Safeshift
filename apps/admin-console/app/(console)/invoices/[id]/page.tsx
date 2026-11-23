import {notFound} from 'next/navigation';
import {PageHeader} from '@/components/page-header';
import {DataTable} from '@/components/data-table';
import {Notice} from '@/components/notice';
import {ConfirmSubmit} from '@/components/confirm-submit';
import {getCallerPermissions} from '@/lib/configuration/guard';
import {requireArea} from '@/lib/guard';
import {createClient} from '@/lib/supabase/server';
import {formatMoney,formatDate,titleize} from '@/lib/format';
import {issueInvoice} from '../actions';
import {changeProviderRequest} from '../../registry/actions';
import { RecordActions } from '@/components/record-actions';
export default async function Invoice({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<Record<string,string>>}){
 await requireArea('invoices'); const {id}=await params;const db=await createClient(),{permissions}=await getCallerPermissions();
 const [header,lines,receipts]=await Promise.all([db.from('invoices').select('*,business_accounts(legal_name)').eq('id',id).maybeSingle(),db.from('invoice_line_items').select('id,description,quantity,unit_price,amount').eq('invoice_id',id).order('created_at'),db.from('provider_requests').select('id,status,provider_reference,created_at').eq('invoice_id',id).order('created_at',{ascending:false})]);
 if(header.error||lines.error)throw Error('Could not load invoice');const i=header.data;if(!i)notFound();
 const manage=permissions.has('manage_invoices');const money=(n:number)=>formatMoney(n,i.currency_code);
 return <><PageHeader title={i.invoice_number} description={i.business_accounts?.legal_name??'Business invoice'}/><Notice searchParams={await searchParams}/>
 <article className="section-stack"><p>{titleize(i.status)} · {formatDate(i.period_start)} until {formatDate(i.period_end)} (exclusive)</p><DataTable columns={['Item','Quantity','Unit price','Amount']} rows={(lines.data??[]).map(l=>[l.description,l.quantity,money(l.unit_price),money(l.amount)])} actions={(lines.data??[]).map(l=><RecordActions key={l.id} table="invoice_line_items" id={l.id}/>)}/>
 <section className="card card-pad"><p>Subtotal · {money(i.subtotal)}</p><p>Tax · {money(i.tax_amount)}</p><strong>Total · {money(i.total)}</strong>{i.due_at&&<p>Due · {formatDate(i.due_at)}</p>}</section>
 {manage&&i.status==='draft'&&<form action={issueInvoice.bind(null,id)}><ConfirmSubmit className="btn btn-primary" message="Issue this invoice and notify business members?">Issue invoice</ConfirmSubmit></form>}
 {manage&&i.issued_at&&<section><h2>Fiscal receipt</h2><p>A receipt reference appears after the fiscal provider confirms issuance.</p>{receipts.error?<p role="alert">Could not load receipt requests.</p>:<><DataTable columns={['Requested','Status','Receipt reference']} empty="No receipt requested yet." rows={(receipts.data??[]).map(r=>[formatDate(r.created_at),titleize(r.status),r.provider_reference??'Awaiting reference'])} actions={(receipts.data??[]).map(r=><RecordActions key={r.id} table="provider_requests" id={r.id} items={r.status==='awaiting_integration'?[{kind:'form',label:'Cancel request',action:changeProviderRequest.bind(null,id,'fiscal_receipt',r.id),confirm:'Cancel this fiscal receipt request?',danger:true}]:[]}/>)}/>{!(receipts.data??[]).some(r=>r.status!=='cancelled')&&<form action={changeProviderRequest.bind(null,id,'fiscal_receipt',null)}><button className="btn">Request fiscal receipt</button></form>}</>}</section>}</article></>;
}
