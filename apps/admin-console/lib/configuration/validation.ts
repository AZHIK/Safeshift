/**
 * Value coercion and validation for the configuration console.
 *
 * The console deliberately avoids a schema library: the field definitions in
 * `resources/` already describe what each column accepts, so the rules live
 * next to the fields rather than in a second, parallel description.
 */

import type { ConfigCrossRule, ConfigField, ConfigFieldValues } from './types';

/** The part of a resource the form helpers need. */
type FieldSet = { fields: ConfigField[] };

/** Coerces a raw form value into the type the column expects. */
export function coerceValue(field: ConfigField, value: unknown): unknown {
  if (value === undefined) return null;
  if (value === null || value === '') {
    return field.type === 'checkbox' ? false : null;
  }

  switch (field.type) {
    case 'number': {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : null;
    }
    case 'checkbox':
      return value === true || value === 'true' || value === 'on';
    case 'multi-select':
    case 'tags':
      return Array.isArray(value)
        ? value.map((item) => String(item)).filter((item) => item.length > 0)
        : String(value)
            .split(',')
            .map((item) => item.trim())
            .filter((item) => item.length > 0);
    case 'json': {
      if (typeof value !== 'string') return value;
      const text = value.trim();
      if (!text) return null;
      try {
        return JSON.parse(text);
      } catch {
        return value;
      }
    }
    case 'text':
    case 'textarea':
    case 'select':
    case 'date':
    default:
      return typeof value === 'string' ? value.trim() : value;
  }
}

/** Turns a database row into the form values the dialog starts from. */
export function rowToValues(resource: FieldSet, row: Record<string, unknown>): ConfigFieldValues {
  const values: ConfigFieldValues = {};
  for (const field of resource.fields) {
    const column = field.column ?? field.name;
    const raw = row[column];
    if (field.type === 'json' && raw !== null && raw !== undefined) {
      values[field.name] = JSON.stringify(raw, null, 2);
    } else if (field.type === 'multi-select' || field.type === 'tags') {
      values[field.name] = Array.isArray(raw) ? raw.map((item) => String(item)) : [];
    } else if (field.type === 'checkbox') {
      values[field.name] = raw === true;
    } else if (field.type === 'date' && typeof raw === 'string') {
      values[field.name] = raw.slice(0, 10);
    } else {
      values[field.name] = raw ?? null;
    }
  }
  return values;
}

/** Produces the default values for a brand new record. */
export function defaultValues(resource: FieldSet): ConfigFieldValues {
  const values: ConfigFieldValues = {};
  for (const field of resource.fields) {
    if (field.defaultValue !== undefined) {
      values[field.name] = field.defaultValue;
    } else if (field.type === 'checkbox') {
      values[field.name] = field.name === 'is_active';
    } else if (field.type === 'multi-select' || field.type === 'tags') {
      values[field.name] = [];
    } else {
      values[field.name] = null;
    }
  }
  return values;
}

/** Validates one field. Returns an error message, or null when valid. */
export function validateField(
  field: ConfigField,
  value: unknown,
  values: ConfigFieldValues,
): string | null {
  const empty =
    value === null ||
    value === undefined ||
    value === '' ||
    (Array.isArray(value) && value.length === 0);

  if (field.required && empty) {
    return `${field.label} is required.`;
  }

  if (empty) return null;

  if (field.type === 'number') {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return `${field.label} must be a number.`;
    if (field.min !== undefined && parsed < field.min) {
      return `${field.label} must be at least ${field.min}.`;
    }
    if (field.max !== undefined && parsed > field.max) {
      return `${field.label} must be at most ${field.max}.`;
    }
  }

  if (field.type === 'json') {
    if (typeof value === 'string') {
      try {
        JSON.parse(value);
      } catch {
        return `${field.label} must be valid JSON.`;
      }
    }
  }

  if (
    field.type === 'text' ||
    field.type === 'textarea' ||
    field.type === 'select'
  ) {
    if (typeof value === 'string' && value.length > 4000) {
      return `${field.label} is too long.`;
    }
  }

  if (field.type === 'geography' && typeof value === 'string' && value.length > 20000) {
    return `${field.label} is too long.`;
  }

  return field.validate ? field.validate(value, values) : null;
}

/**
 * Runs the declarative cross-field rules.
 *
 * A rule is skipped when the values it compares are not both present: an
 * empty field is the field's own error to report.
 */
export function applyCrossRules(
  rules: ConfigCrossRule[] | undefined,
  values: ConfigFieldValues,
): Record<string, string> {
  const errors: Record<string, string> = {};
  if (!rules) return errors;

  for (const rule of rules) {
    const value = values[rule.field];
    const isEmpty =
      value === null ||
      value === undefined ||
      value === '' ||
      (Array.isArray(value) && value.length === 0);

    if (rule.type === 'required_when') {
      const condition = values[rule.against ?? ''];
      const applies = String(condition ?? '') === String(rule.equals ?? '');
      if (applies && isEmpty) errors[rule.field] = rule.message;
      continue;
    }

    if (isEmpty) continue;

    const other = rule.against ? values[rule.against] : rule.value;
    const otherEmpty =
      other === null ||
      other === undefined ||
      other === '' ||
      (Array.isArray(other) && other.length === 0);
    if (otherEmpty) continue;

    const left = Number(value);
    const right = Number(other);
    if (!Number.isFinite(left) || !Number.isFinite(right)) continue;

    let holds = true;
    switch (rule.type) {
      case 'gte':
        holds = left >= right;
        break;
      case 'lte':
        holds = left <= right;
        break;
      case 'gt':
        holds = left > right;
        break;
      case 'lt':
        holds = left < right;
        break;
      case 'eq':
        holds = left === right;
        break;
      case 'neq':
        holds = left !== right;
        break;
      default:
        holds = true;
    }

    if (!holds) errors[rule.field] = rule.message;
  }

  return errors;
}

/**
 * Validates a whole form.
 *
 * Returns a map of field name to error message. An empty map means the form
 * is valid. Cross-field rules declared on the resource are applied last and
 * may add errors to fields that pass their own checks.
 */
export function validateValues(
  resource: FieldSet & {
    validate?: (values: ConfigFieldValues) => Record<string, string>;
    crossRules?: ConfigCrossRule[];
  },
  values: ConfigFieldValues,
): Record<string, string> {
  const errors: Record<string, string> = {};

  for (const field of resource.fields) {
    if (field.dependsOn && !isFieldVisible(field, values)) continue;
    const error = validateField(field, values[field.name], values);
    if (error) errors[field.name] = error;
  }

  const crossField = applyCrossRules(resource.crossRules, values);
  for (const [name, message] of Object.entries(crossField)) {
    if (!errors[name]) errors[name] = message;
  }

  if (resource.validate) {
    const extra = resource.validate(values);
    for (const [name, message] of Object.entries(extra)) {
      if (!errors[name]) errors[name] = message;
    }
  }

  return errors;
}

/** True when a conditional field should be shown for the current values. */
export function isFieldVisible(field: ConfigField, values: ConfigFieldValues): boolean {
  if (!field.dependsOn) return true;
  const current = values[field.dependsOn.field];
  const { equals, notEquals } = field.dependsOn;

  if (equals !== undefined) {
    const expected = equals;
    if (Array.isArray(expected)) {
      return expected.map((item) => String(item)).includes(String(current ?? ''));
    }
    return String(current ?? '') === String(expected ?? '');
  }

  if (notEquals !== undefined) {
    return String(current ?? '') !== String(notEquals ?? '');
  }

  return true;
}

/** Builds the payload the database receives from the form values. */
export function buildPayload(
  resource: FieldSet,
  values: ConfigFieldValues,
): Record<string, unknown> {
  const payload: Record<string, unknown> = {};
  for (const field of resource.fields) {
    if (field.formOnly) continue;
    const column = field.column ?? field.name;
    if (field.dependsOn && !isFieldVisible(field, values)) {
      // A hidden field is cleared rather than left holding a stale value.
      payload[column] = field.type === 'multi-select' || field.type === 'tags' ? [] : null;
      continue;
    }
    payload[column] = coerceValue(field, values[field.name]);
  }
  return payload;
}
