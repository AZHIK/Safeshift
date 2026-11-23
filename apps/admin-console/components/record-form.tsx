import { searchReferenceAction } from '@/app/(console)/data/actions';
import { ReferenceSelect } from '@/components/reference-select';
import { fieldLabel, formValue, inputKind, type RecordColumn } from '@/lib/data-records';
import { titleize } from '@/lib/format';
import type { ReferenceChoices } from '@/lib/record-labels';


/** One field per column, typed from the database. */
export function RecordFields({
  columns,
  values = {},
  mode,
  table,
  references = {},
}: {
  columns: RecordColumn[];
  values?: Record<string, unknown>;
  mode: 'create' | 'edit';
  table: string;
  /** Dropdown choices for reference columns (loadReferenceChoices). */
  references?: Record<string, ReferenceChoices>;
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
        const choices = column.references_table ? references[column.column_name] : undefined;
        const hint = [
          choices ? `choose from ${titleize(column.references_table!.replace(/^(public|auth)\./, ''))}` : column.data_type,
          mode === 'create' && column.has_default ? 'leave blank for the default' : null,
          !column.is_nullable ? 'required' : null,
        ]
          .filter(Boolean)
          .join(' · ');
        let input;
        if (locked) {
          input = <input className="input mono" id={id} value={value} readOnly disabled />;
        } else if (choices) {
          input = (
            <ReferenceSelect id={id} name={name} table={table} column={column.column_name} choices={choices}
              defaultValue={value} required={required}
              blankLabel={mode === 'edit' && !column.is_nullable ? 'Unchanged' : column.is_nullable ? 'None' : 'Choose…'}
              search={searchReferenceAction} />
          );
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
              {choices ? fieldLabel(column.column_name) : titleize(column.column_name)}
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
