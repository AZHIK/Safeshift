import { csvRow } from '@/lib/csv';
import { requireArea } from '@/lib/guard';
import { records,recordFilters,readRecords } from '@/lib/records';
import { createClient } from '@/lib/supabase/server';

export async function GET(req:Request,{params}:{params:Promise<{resource:string}>}){
  const {resource}=await params;
  if(!Object.hasOwn(records,resource)) return new Response('Unknown list',{status:404});
  const list=records[resource],session=await requireArea(list.area),db=await createClient();
  try {
    const filters=recordFilters(list,new URL(req.url).searchParams);
    let offset=0;
    const chunk=500,parts=[csvRow(list.columns)];
    while(true){
      const {rows,count}=await readRecords(db,list,filters,session,offset,chunk);
      for(const row of rows) parts.push(csvRow(list.columns.map(c=>row[c])));
      offset+=rows.length;
      if(!rows.length || offset>=count) break;
    }
    return new Response(parts.join(''),{headers:{'Content-Type':'text/csv; charset=utf-8','Content-Disposition':'attachment; filename="'+resource+'.csv"','Cache-Control':'private, no-store'}});
  }catch{ return new Response('Export failed. Check your filters and access.',{status:400}); }
}
