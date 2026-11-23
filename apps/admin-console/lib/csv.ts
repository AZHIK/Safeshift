export function csvRow(values: unknown[]): string {
  return values.map(value => {
    const raw = typeof value === 'object' && value !== null ? JSON.stringify(value) : String(value ?? '');
    const safe = typeof value === 'string' && /^(?:\s*[=+@-]|[\t\r\n])/.test(raw) ? "'" + raw : raw;
    return '"' + safe.replaceAll('"','""') + '"';
  }).join(',') + '\r\n';
}
