import {expect,it} from 'vitest';
import {records,recordFilters} from '@/lib/records';
import {csvRow} from '@/lib/csv';
it('checks date windows, page numbers and sort names',()=>{
 expect(recordFilters(records.jobs,new URLSearchParams('page=-1&sort=password')).sort).toBe('created_at');
 expect(recordFilters(records.jobs,new URLSearchParams('page=4&field=status&q=completed'))).toMatchObject({page:4,field:'status',q:'completed'});
 expect(()=>recordFilters(records.jobs,new URLSearchParams('start=2026-02-30'))).toThrow();
 expect(()=>recordFilters(records.jobs,new URLSearchParams('start=2026-03-01&end=2026-02-28'))).toThrow();
});
it('writes quoted CSV and neutralizes spreadsheet formulas',()=>{
 expect(csvRow(['a,"b"',null,' =1+2',-50])).toBe('"a,""b""","","\' =1+2","-50"\r\n');
});
