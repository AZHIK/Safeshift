'use client';

import { useMemo } from 'react';

import { SAMPLE_TEMPLATE_VARIABLES } from '@/lib/configuration/resources/communication';

/**
 * Renders a notification template with sample values.
 *
 * The panel is a preview of the copy, not a send: it shows the operator what
 * the customer will read, with the declared variables filled in.
 */
export function TemplatePreview({
  title,
  body,
  variables,
}: {
  title?: string | null;
  body?: string | null;
  variables?: string[] | null;
}) {
  const sample = useMemo(() => {
    const map: Record<string, string> = { ...SAMPLE_TEMPLATE_VARIABLES };
    for (const variable of variables ?? []) {
      const name = String(variable).trim();
      if (name && !(name in map)) {
        map[name] = `«${name}»`;
      }
    }
    return map;
  }, [variables]);

  const render = (template: string | null | undefined) => {
    if (!template) return '';
    return template.replace(/\{+\s*([a-zA-Z0-9_]+)\s*\}+/g, (match, name: string) => {
      const key = String(name);
      return key in sample ? sample[key] : match;
    });
  };

  const renderedTitle = render(title);
  const renderedBody = render(body);

  const used = Object.keys(sample).filter((key) =>
    `${title ?? ''} ${body ?? ''}`.includes(`{${key}}`),
  );

  return (
    <div className="config-preview">
      <div className="config-preview-head">
        <strong>Preview</strong>
        <span className="small muted">Sample values</span>
      </div>
      <div className="config-preview-body">
        {renderedTitle ? <div className="config-preview-title">{renderedTitle}</div> : null}
        <div className="config-preview-text">{renderedBody || 'The body is empty.'}</div>
      </div>
      {variables && variables.length > 0 ? (
        <div className="config-preview-vars">
          <div className="small muted">Declared variables</div>
          <div className="chip-list">
            {variables.map((variable) => (
              <span
                className={`chip${used.includes(String(variable)) ? '' : ' chip-warn'}`}
                key={variable}
              >
                {String(variable)}
              </span>
            ))}
          </div>
          {variables.some((variable) => !used.includes(String(variable))) ? (
            <p className="small muted" style={{ marginTop: 6 }}>
              Some declared variables do not appear in the template.
            </p>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
