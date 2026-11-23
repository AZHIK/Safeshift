import { createClient } from '@/lib/supabase/server';
import { csvRow } from '@/lib/csv';
export async function POST(request: Request) {
  if (request.headers.get('origin') !== new URL(request.url).origin) return new Response('Invalid origin',{status:403});
  const f=await request.formData();
  const client=await createClient();
  const result=f.get('request') ? await client.rpc('admin_export_government_request',{p_id:f.get('request')}) :
    await client.rpc('admin_regulator_report',{p_country:f.get('country'),p_start:f.get('start'),p_end:f.get('end')});
  if(result.error || !result.data) return new Response('Report unavailable. Check scope, dates and approval.',{status:result.error?.code==='42501'?403:400});
  const {recorded_commission,...counts}=result.data;
  const data=csvRow(['Measure','Value','Currency'])+
    Object.entries(counts).map(([k,v])=>csvRow([k,v,''])).join('')+
    Object.entries(recorded_commission ?? {}).map(([c,v])=>csvRow(['recorded_commission',v,c])).join('');
  return new Response(data,{headers:{'Content-Type':'text/csv; charset=utf-8','Content-Disposition':'attachment; filename="operating-report.csv"','Cache-Control':'private, no-store'}});
}
