'use client';

import { useEffect, useMemo, useState } from 'react';

import { applyCrossRules, isFieldVisible, validateField } from '@/lib/configuration/validation';
import { publicIconUrl, uploadIcon, validateIconFile } from '@/lib/configuration/icons';
import type {
  ConfigCrossRule,
  ConfigField,
  ConfigFieldValues,
  ConfigOption,
} from '@/lib/configuration/types';
import { getBrowserClient } from '@/lib/supabase/client';

import { TemplatePreview } from './template-preview';

export type FormSubmitResult = {
  success: boolean;
  error?: string;
  fieldErrors?: Record<string, string>;
};

export type ProfileHit = {
  id: string;
  name: string;
  email: string;
};

/** The empty option of a select that may hold no value. */
function emptyLabel(field: ConfigField): string {
  if (field.optionsKey === 'countries') return 'All countries';
  if (field.optionsKey === 'cities') return 'All cities';
  if (field.optionsKey === 'vehicle_types') return 'All vehicle types';
  return '—';
}

/**
 * The create and edit form.
 *
 * One dialog serves both jobs: the edit dialog opens with the row's values
 * already filled in. Field-level errors come from the shared validator, and
 * the server's own validation is merged in when it returns field errors.
 */
export function ConfigurationFormDialog({
  open,
  title,
  description,
  fields,
  options,
  initialValues,
  onSubmit,
  onClose,
  searchProfiles,
  preview,
  crossRules,
}: {
  open: boolean;
  title: string;
  description?: string;
  fields: ConfigField[];
  options: Record<string, ConfigOption[]>;
  initialValues: ConfigFieldValues;
  onSubmit: (values: ConfigFieldValues) => Promise<FormSubmitResult>;
  onClose: () => void;
  searchProfiles?: (query: string) => Promise<ProfileHit[]>;
  preview?: { titleField: string; bodyField: string; variablesField?: string };
  crossRules?: ConfigCrossRule[];
}) {
  const [values, setValues] = useState<ConfigFieldValues>(initialValues);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [serverError, setServerError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [profileQuery, setProfileQuery] = useState(() => {
    const profileField = fields.find((field) => field.type === 'profile');
    if (!profileField) return '';
    const chosen = initialValues[profileField.name] as string | null;
    if (!chosen) return '';
    return String(initialValues.profile_label ?? chosen);
  });
  const [profileHits, setProfileHits] = useState<ProfileHit[]>([]);
  const [uploadingField, setUploadingField] = useState<string | null>(null);

  useEffect(() => {
    if (!open || !searchProfiles || profileQuery.trim().length < 2) return;
    let cancelled = false;
    const timer = setTimeout(async () => {
      const hits = await searchProfiles(profileQuery.trim());
      if (!cancelled) setProfileHits(hits);
    }, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [open, profileQuery, searchProfiles]);

  const visibleFields = useMemo(
    () => fields.filter((field) => isFieldVisible(field, values)),
    [fields, values],
  );

  if (!open) return null;

  /**
   * Fills the fields that depend on the one the operator just chose.
   *
   * The country form works this way: choosing a country from the catalogue
   * fills the name, the currency, the language, the phone code and the time
   * zone from the catalogue entry. The operator can still change any of them
   * afterwards.
   */
  const applyAutofill = (
    current: ConfigFieldValues,
    changedField: ConfigField,
    value: unknown,
  ): ConfigFieldValues => {
    const option = (options[changedField.optionsKey ?? ''] ?? []).find(
      (entry) => entry.value === String(value ?? ''),
    );
    const meta = option?.meta;
    if (!meta) return current;

    const next = { ...current };
    for (const field of fields) {
      const source = field.autofillFrom;
      if (!source) continue;
      const value = meta[source];
      if (value === undefined || value === null) continue;
      next[field.name] = value;
    }
    return next;
  };

  const setValue = (name: string, value: unknown) => {
    const changedField = fields.find((field) => field.name === name);
    setValues((current) => {
      const next = { ...current, [name]: value };
      if (!changedField) return next;
      return applyAutofill(next, changedField, value);
    });
    setErrors((current) => {
      if (!current[name]) return current;
      const next = { ...current };
      delete next[name];
      return next;
    });
  };

  /**
   * Uploads an icon the operator picked from their computer.
   *
   * The file is stored in the public catalogue bucket, named after the row's
   * code, and the form field holds the stored path. Uploading replaces the
   * previous artwork under the same name, so an edit never leaves the old
   * file behind.
   */
  const handleFile = async (field: ConfigField, file: File | null) => {
    const upload = field.upload;
    if (!file || !upload) return;

    const invalid = validateIconFile(file);
    if (invalid) {
      setErrors((current) => ({ ...current, [field.name]: invalid }));
      return;
    }

    const fallbackName = file.name.replace(/\.[^.]+$/, '');
    const name = String(values[upload.nameFrom] ?? '').trim() || fallbackName;

    setUploadingField(field.name);
    setErrors((current) => {
      const next = { ...current };
      delete next[field.name];
      return next;
    });

    try {
      const result = await uploadIcon(
        getBrowserClient(),
        { bucket: upload.bucket, folder: upload.folder, name },
        file,
      );
      if ('error' in result) {
        setErrors((current) => ({ ...current, [field.name]: result.error }));
        return;
      }
      setValues((current) => ({
        ...current,
        [field.name]: result.path,
        [`${field.name}__url`]: result.publicUrl,
      }));
    } catch (caught) {
      setErrors((current) => ({
        ...current,
        [field.name]: caught instanceof Error ? caught.message : 'The icon could not be uploaded.',
      }));
    } finally {
      setUploadingField(null);
    }
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setServerError(null);

    const nextErrors: Record<string, string> = {};
    for (const field of fields) {
      if (!isFieldVisible(field, values)) continue;
      const error = validateField(field, values[field.name], values);
      if (error) nextErrors[field.name] = error;
    }
    for (const [name, message] of Object.entries(applyCrossRules(crossRules, values))) {
      if (!nextErrors[name]) nextErrors[name] = message;
    }

    if (Object.keys(nextErrors).length > 0) {
      setErrors(nextErrors);
      return;
    }

    setSubmitting(true);
    try {
      const result = await onSubmit(values);
      if (result.success) {
        onClose();
        return;
      }
      setServerError(result.error ?? 'The record could not be saved.');
      if (result.fieldErrors) setErrors(result.fieldErrors);
    } finally {
      setSubmitting(false);
    }
  };

  const renderField = (field: ConfigField) => {
    const value = values[field.name];
    const error = errors[field.name];
    const fieldOptions = field.options ?? options[field.optionsKey ?? ''] ?? [];

    const control = (() => {
      switch (field.type) {
        case 'textarea':
        case 'geography':
          return (
            <textarea
              className="input"
              id={field.name}
              onChange={(event) => setValue(field.name, event.target.value)}
              placeholder={field.placeholder}
              rows={field.type === 'geography' ? 5 : 3}
              value={(value as string) ?? ''}
            />
          );
        case 'number':
          return (
            <input
              className="input"
              id={field.name}
              max={field.max}
              min={field.min}
              onChange={(event) => setValue(field.name, event.target.value)}
              placeholder={field.placeholder}
              required={field.required}
              step={field.step ?? 1}
              type="number"
              value={value === null || value === undefined ? '' : String(value)}
            />
          );
        case 'datetime':
        case 'date':
          return (
            <input
              className="input"
              id={field.name}
              onChange={(event) => setValue(field.name, event.target.value)}
              required={field.required}
              type={field.type === 'datetime' ? 'datetime-local' : 'date'}
              step={field.type === 'datetime' ? 'any' : undefined}
              value={(value as string) ?? ''}
            />
          );
        case 'checkbox':
          return (
            <label className="inline" htmlFor={field.name}>
              <input
                checked={value === true}
                id={field.name}
                onChange={(event) => setValue(field.name, event.target.checked)}
                type="checkbox"
              />
              <span className="small">{field.label}</span>
            </label>
          );
        case 'select':
          return (
            <select
              className="input"
              id={field.name}
              onChange={(event) => setValue(field.name, event.target.value || null)}
              required={field.required}
              value={(value as string) ?? ''}
            >
              {!field.required ? <option value="">{emptyLabel(field)}</option> : null}
              {fieldOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.secondary ? `${option.label} — ${option.secondary}` : option.label}
                </option>
              ))}
            </select>
          );
        case 'multi-select':
          return (
            <div className="multi-select" id={field.name}>
              {fieldOptions.length === 0 ? (
                <span className="small muted">No options available.</span>
              ) : (
                fieldOptions.map((option) => {
                  const selected = Array.isArray(value)
                    ? (value as string[]).includes(option.value)
                    : false;
                  return (
                    <label className="inline" key={option.value}>
                      <input
                        checked={selected}
                        onChange={(event) => {
                          const current = Array.isArray(value) ? [...(value as string[])] : [];
                          const next = event.target.checked
                            ? [...current, option.value]
                            : current.filter((item) => item !== option.value);
                          setValue(field.name, next);
                        }}
                        type="checkbox"
                      />
                      <span className="small">
                        {option.secondary ? `${option.label} (${option.secondary})` : option.label}
                      </span>
                    </label>
                  );
                })
              )}
            </div>
          );
        case 'tags':
          return (
            <input
              className="input"
              id={field.name}
              onChange={(event) => setValue(field.name, event.target.value)}
              placeholder="comma, separated, names"
              value={
                Array.isArray(value) ? (value as string[]).join(', ') : ((value as string) ?? '')
              }
            />
          );
        case 'json':
          return (
            <textarea
              className="input mono"
              id={field.name}
              onChange={(event) => setValue(field.name, event.target.value)}
              placeholder={field.placeholder}
              rows={4}
              value={(value as string) ?? ''}
            />
          );
        case 'profile': {
          const chosen =
            (values.profile_label as string | undefined) ?? (value ? String(value) : undefined);
          return (
            <div className="profile-search">
              <input
                className="input"
                id={field.name}
                onChange={(event) => {
                  setProfileQuery(event.target.value);
                  setProfileHits([]);
                  setValue(field.name, null);
                  setValue('profile_label', null);
                }}
                placeholder="Search by name, phone or email"
                value={profileQuery}
              />
              {chosen && chosen !== profileQuery ? (
                <div className="small muted">Selected: {chosen}</div>
              ) : null}
              {profileHits.length > 0 ? (
                <div className="profile-hits">
                  {profileHits.map((hit) => (
                    <button
                      className="profile-hit"
                      key={hit.id}
                      onClick={() => {
                        setValue(field.name, hit.id);
                        setValue(
                          'profile_label',
                          `${hit.name}${hit.email ? ` (${hit.email})` : ''}`,
                        );
                        setProfileQuery(hit.name);
                        setProfileHits([]);
                      }}
                      type="button"
                    >
                      <span>{hit.name}</span>
                      <span className="small muted">{hit.email}</span>
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
          );
        }
        case 'file': {
          const upload = field.upload;
          const path = String(value ?? '');
          const previewUrl = upload
            ? ((values[`${field.name}__url`] as string | undefined) ??
              publicIconUrl(upload.bucket, path))
            : null;
          return (
            <div className="file-upload">
              {previewUrl ? (
                <div className="file-preview">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img alt="" src={previewUrl} />
                </div>
              ) : null}
              <input
                accept={upload?.accept}
                className="input"
                disabled={uploadingField === field.name}
                id={field.name}
                onChange={(event) => void handleFile(field, event.target.files?.[0] ?? null)}
                type="file"
              />
              <div className="small muted">
                {uploadingField === field.name ? (
                  'Uploading…'
                ) : path ? (
                  <>
                    Current file: <span className="mono">{path}</span>
                  </>
                ) : (
                  'No file chosen.'
                )}
              </div>
            </div>
          );
        }
        case 'text':
        default:
          return (
            <input
              className="input"
              id={field.name}
              onChange={(event) => setValue(field.name, event.target.value)}
              placeholder={field.placeholder}
              required={field.required}
              value={(value as string) ?? ''}
            />
          );
      }
    })();

    const isCheckbox = field.type === 'checkbox';

    return (
      <div className={`field${isCheckbox ? ' field-check' : ''}`} key={field.name}>
        {!isCheckbox ? <label htmlFor={field.name}>{field.label}</label> : null}
        {control}
        {field.help ? <div className="small muted">{field.help}</div> : null}
        {error ? <div className="field-error">{error}</div> : null}
      </div>
    );
  };

  return (
    <div
      aria-modal="true"
      className="dialog-backdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && !submitting) onClose();
      }}
      role="dialog"
    >
      <div className={`dialog${preview ? ' dialog-wide' : ''}`}>
        <div className="dialog-head">
          <div>
            <h2 className="dialog-title">{title}</h2>
            {description ? <p className="small muted">{description}</p> : null}
          </div>
          <button
            aria-label="Close"
            className="btn btn-sm"
            disabled={submitting}
            onClick={onClose}
            type="button"
          >
            ✕
          </button>
        </div>

        <form noValidate onSubmit={handleSubmit}>
          <div className="dialog-body">
            {serverError ? <div className="notice notice-error">{serverError}</div> : null}
            <div className="form-grid">{visibleFields.map(renderField)}</div>
            {preview ? (
              <TemplatePreview
                body={(values[preview.bodyField] as string) ?? ''}
                title={(values[preview.titleField] as string) ?? ''}
                variables={
                  preview.variablesField
                    ? ((values[preview.variablesField] as string[]) ?? [])
                    : undefined
                }
              />
            ) : null}
          </div>
          <div className="dialog-foot">
            <button className="btn" disabled={submitting} onClick={onClose} type="button">
              Cancel
            </button>
            <button className="btn btn-primary" disabled={submitting} type="submit">
              {submitting ? 'Saving…' : 'Save'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
