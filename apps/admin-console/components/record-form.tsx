import { formValue, inputKind, type RecordColumn } from '@/lib/data-records';
import { titleize } from '@/lib/format';

/** One field per column, typed from the database. */
export function RecordFields({
  columns,
  values = {},
  mode,
}: {
  columns: RecordColumn[];
  values?: Record<string, unknown>;
  mode: 'create' | 'edit';
}) {
  return (
    <>
      {columns.map((column) => {
        if (column.is_generated) return null;
        const name = `f:${column.column_name}`;
        const id = `field-${column.column_name}`;
        const value = formValue(values[column.column_name]);
        const locked = mode === 'edit' && column.is_primary_key;
        const kind = inputKind(column);
        const required = !column.is_nullable && !column.has_default && mode === 'create';
        const hint = [
          column.data_type,
          column.references_table ? `refers to ${column.references_table.replace('public.', '')}` : null,
          mode === 'create' && column.has_default ? 'leave blank for the default' : null,
          !column.is_nullable ? 'required' : null,
        ]
          .filter(Boolean)
          .join(' · ');
        let input;
        if (locked) {
          input = <input className="input mono" id={id} value={value} readOnly disabled />;
        } else if (kind === 'boolean') {
          input = (
            <select className="input" id={id} name={name} defaultValue={value} required={required}>
              <option value="">{column.is_nullable || mode === 'create' ? '—' : 'Unchanged'}</option>
              <option value="true">Yes</option>
              <option value="false">No</option>
            </select>
          );
        } else if (kind === 'enum') {
          input = (
            <select className="input" id={id} name={name} defaultValue={value} required={required}>
              <option value="">—</option>
              {(column.enum_values ?? []).map((v) => (
                <option key={v} value={v}>{titleize(v)}</option>
              ))}
            </select>
          );
        } else if (kind === 'json' || (kind === 'longtext' && value.length > 60)) {
          input = (
            <textarea className={`input${kind === 'json' ? ' mono' : ''}`} id={id} name={name} defaultValue={value}
              rows={kind === 'json' ? 5 : 3} required={required} />
          );
        } else {
          input = (
            <input className={`input${column.data_type === 'uuid' ? ' mono' : ''}`} id={id} name={name} defaultValue={value}
              type={kind === 'number' ? 'number' : kind === 'date' ? 'date' : 'text'}
              step={kind === 'number' ? 'any' : undefined}
              placeholder={kind === 'timestamp' ? 'YYYY-MM-DD HH:MM:SS+03' : undefined}
              required={required} />
          );
        }
        return (
          <div className="field" key={column.column_name}>
            <label htmlFor={id}>
              {titleize(column.column_name)}
              {column.is_primary_key ? ' (key)' : ''}
            </label>
            {input}
            <span className="small muted">{hint}</span>
          </div>
        );
      })}
    </>
  );
}
