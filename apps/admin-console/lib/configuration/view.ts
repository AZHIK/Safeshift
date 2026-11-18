/**
 * The serialisable half of a configuration resource.
 *
 * The page hands this to the client components. Validation callbacks and
 * database hooks stay on the server: they are functions, and the server is
 * the only place that may run them.
 */

import type {
  ConfigColumn,
  ConfigCrossRule,
  ConfigField,
  ConfigFilter,
  ConfigResource,
  ConfigRowAction,
  ConfigSpecial,
} from './types';

export type ConfigView = {
  table: string;
  singular: string;
  singularTitle: string;
  pluralTitle: string;
  description: string;
  permission: string;
  group: string;
  countryScoped?: boolean;
  softDelete?: boolean;
  hardDelete?: boolean;
  columns: ConfigColumn[];
  fields: ConfigField[];
  crossRules?: ConfigCrossRule[];
  searchColumns?: string[];
  groupBy?: string;
  filters?: ConfigFilter[];
  special?: ConfigSpecial;
  rowAction?: ConfigRowAction;
};

/** Strips the server-only members of a resource. */
export function toView(resource: ConfigResource): ConfigView {
  return {
    table: resource.table,
    singular: resource.singular,
    singularTitle: resource.singularTitle,
    pluralTitle: resource.pluralTitle,
    description: resource.description,
    permission: resource.permission,
    group: resource.group,
    countryScoped: resource.countryScoped,
    softDelete: resource.softDelete,
    hardDelete: resource.hardDelete,
    columns: resource.columns,
    fields: resource.fields.map((field) => ({
      name: field.name,
      label: field.label,
      type: field.type,
      required: field.required,
      help: field.help,
      placeholder: field.placeholder,
      optionsKey: field.optionsKey,
      options: field.options,
      min: field.min,
      max: field.max,
      step: field.step,
      defaultValue: field.defaultValue,
      dependsOn: field.dependsOn,
      column: field.column,
      formOnly: field.formOnly,
      autofillFrom: field.autofillFrom,
      upload: field.upload,
    })),
    searchColumns: resource.searchColumns,
    groupBy: resource.groupBy,
    filters: resource.filters,
    special: resource.special,
    rowAction: resource.rowAction,
    crossRules: resource.crossRules,
  };
}
