import Link from 'next/link';
import { notFound } from 'next/navigation';
import { DataTable } from '@/components/data-table';
import { PageHeader } from '@/components/page-header';
import { titleize } from '@/lib/format';
import { requireArea } from '@/lib/guard';
import { records,recordFilters,readRecords,PAGE_SIZE } from '@/lib/records';
import { createClient } from '@/lib/supabase/server';

export default async function RecordsPage({params,searchParams}:{params:Promise<{resource:string}>;searchParams:Promise<Record<string,string|string[]|undefined>>}){
  const {resource}=await params;
  if(!Object.hasOwn(records,resource)) notFound();
  const list=records[resource],session=await requireArea(list.area);
  const q=new URLSearchParams();
  for(const [key,value] of Object.entries(await searchParams)) if(typeof value==='string') q.set(key,value);
  let result,filters;
  try {
    filters=recordFilters(list,q);
    result=await readRecords(await createClient(),list,filters,session,(filters.page-1)*PAGE_SIZE,PAGE_SIZE);
  } catch(error) {
    return <><PageHeader title={list.title}/><p role="alert">{(error as Error).message}</p><Link href={'/records/'+resource}>Clear filters</Link></>;
  }
  function href(page:number){const copy=new URLSearchParams(q);copy.set('page',String(page));return '?'+copy.toString();}
  const options=list.columns.map(c=><option key={c} value={c}>{titleize(c)}</option>);
  return <><PageHeader title={list.title} actions={<a className="btn" href={'/records/'+resource+'/export?'+q.toString()}>Export matching CSV</a>}/>
    <form className="card card-pad form-row">
      <label className="field">Search field<select className="input" name="field" defaultValue={filters.field}>{options}</select></label>
      <label className="field">Exact value<input className="input" name="q" defaultValue={filters.q}/></label>
      <label className="field">From (UTC)<input className="input" type="date" name="start" defaultValue={filters.start}/></label>
      <label className="field">Through (UTC)<input className="input" type="date" name="end" defaultValue={filters.end}/></label>
      <label className="field">Sort by<select className="input" name="sort" defaultValue={filters.sort}>{options}</select></label>
      <label className="field">Order<select className="input" name="dir" defaultValue={filters.ascending?'asc':'desc'}><option value="desc">Descending</option><option value="asc">Ascending</option></select></label><button className="btn">Apply</button>
    </form>
    <DataTable columns={list.columns.map(titleize)} rows={result.rows.map(r=>list.columns.map(c=>list.detail && c==='id'?<Link key={c} href={list.detail+r.id}>{String(r.id)}</Link>:String(r[c]??'—')))}/>
    <nav className="inline">{filters.page>1 && <Link href={href(filters.page-1)}>Previous</Link>}<span>Page {filters.page} · {result.count} matching records</span>{filters.page*PAGE_SIZE<result.count && <Link href={href(filters.page+1)}>Next</Link>}</nav></>;
}
