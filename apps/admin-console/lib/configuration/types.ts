/**
 * Shared types for the operator configuration console.
 *
 * Every configuration page is described by a `ConfigResource`: a plain-data
 * declaration of the table it manages, the columns it shows, the fields its
 * form renders and the permission that guards it. The declaration carries no
 * React and no database client, so the same object can be read by a server
 * component (to query and validate) and by a client component (to render the
 * table and the form).
 */

/** One choice in a select or multi-select control. */
export type ConfigOption = {
  value: string;
  label: string;
  secondary?: string;
  /**
   * Extra values the option carries.
   *
   * The country catalogue uses them: choosing a country fills the currency,
   * the language, the phone code and the time zone from the catalogue entry.
   */
  meta?: Record<string, unknown>;
};

/** The field controls the configuration form can render. */
export type ConfigFieldType =
  | 'text'
  | 'textarea'
  | 'number'
  | 'select'
  | 'multi-select'
  | 'checkbox'
  | 'json'
  | 'datetime'
  | 'date'
  | 'tags'
  | 'profile'
  | 'file'
  /** A PostGIS geography column edited as WKT text (e.g. a service boundary). */
  | 'geography';

/** A bag of form values, keyed by field name. */
export type ConfigFieldValues = Record<string, unknown>;

/** Field-level validation. Returns an error message, or null when valid. */
export type ConfigFieldValidator = (value: unknown, values: ConfigFieldValues) => string | null;

export type ConfigField = {
  /** Key in the form values. */
  name: string;
  label: string;
  type: ConfigFieldType;
  required?: boolean;
  help?: string;
  placeholder?: string;
  /** Key into the option map the page loads. */
  optionsKey?: string;
  /** Static options, for short closed sets. */
  options?: ConfigOption[];
  min?: number;
  max?: number;
  step?: number;
  defaultValue?: unknown;
  /**
   * The field is only shown when another field has a given value. Use
   * `notEquals` for the "only when the other field has been filled in" case:
   * `{ field: 'country_id', notEquals: '' }`.
   */
  dependsOn?: { field: string; equals?: unknown; notEquals?: unknown };
  validate?: ConfigFieldValidator;
  /**
   * The database column this field writes to. Defaults to `name`. Use it when
   * the form name and the column name differ.
   */
  column?: string;
  /** The column is never sent to the database (form-only field). */
  formOnly?: boolean;
  /** The column is written but never shown in the table. */
  hidden?: boolean;
  /**
   * The option key this field is filled in from.
   *
   * When the operator picks an option for another field, the value of this
   * key in that option's metadata is written here. The country form uses it
   * to fill the currency, the language, the phone code and the time zone
   * from the country catalogue.
   */
  autofillFrom?: string;
  /**
   * The storage bucket a file field uploads to.
   *
   * A file field holds the path of the uploaded object, so the row stores
   * "vehicle/pickup.svg" rather than the file itself.
   */
  upload?: {
    /** The bucket the file goes to. */
    bucket: string;
    /** The folder inside the bucket. */
    folder: string;
    /** The file types the operator may upload. */
    accept: string;
    /**
     * The field whose value names the uploaded file. The catalogue rows are
     * named after their code, so "code" gives "vehicle/pickup.svg".
     */
    nameFrom: string;
  };
};

export type ConfigColumnKind = 'text' | 'number' | 'boolean' | 'date' | 'json' | 'code';

export type ConfigColumn = {
  /** Key in the row object returned by the list query. */
  key: string;
  label: string;
  kind?: ConfigColumnKind;
  sortable?: boolean;
  /** How wide the cell is, as a CSS grid span. */
  width?: string;
};

/**
 * An extra action shown on every row of a configuration table.
 *
 * The Countries page uses it to send the operator to the settings of that
 * country. The href is a template rather than a function because the
 * resource is handed to the client as plain data.
 */
export type ConfigRowAction = {
  /** The text of the button. */
  label: string;
  /**
   * The page the button opens. '{id}' is replaced with the id of the row.
   */
  href: string;
};

/**
 * A table that points at the row being deactivated. While any of these rows
 * exist, deactivating the configuration row would break live data, so the
 * console refuses and tells the operator how many rows are in the way.
 *
 * The counts come from public.admin_config_reference_counts(), which counts
 * inside the database where the row-level security policies of the
 * operational tables cannot hide live references from the operator.
 */
export type ConfigReference = {
  /** The key the reference-count function returns this count under. */
  key: string;
  /** Human phrasing used in the warning, e.g. "active vehicles". */
  label: string;
  /**
   * Whether the reference stops the row from being deactivated. A
   * non-blocking reference is still counted and shown so the operator knows
   * what the row is attached to.
   */
  blocking?: boolean;
};

export type ConfigFilterType = 'select' | 'boolean';

export type ConfigFilter = {
  name: string;
  label: string;
  type: ConfigFilterType;
  optionsKey?: string;
  options?: ConfigOption[];
  /**
   * The filter is handled by the resource rather than by a plain column
   * comparison, so the engine must not turn it into an equality filter.
   */
  special?: boolean;
};

/** Optional side panel rendered next to a configuration table. */
export type ConfigSpecial =
  'notification-preview' | 'cancellation-calculator' | 'dispatch-resolution' | 'pricing-warning';

/**
 * A rule that spans two fields.
 *
 * The rules are declarative on purpose: the form runs them as the operator
 * types, and the server runs them again before it writes, so the operator
 * sees the problem before the round trip.
 */
export type ConfigCrossRule = {
  /** The field the error is attached to. */
  field: string;
  type: 'gte' | 'lte' | 'gt' | 'lt' | 'eq' | 'neq' | 'required_when';
  /** The other field the rule compares against. */
  against?: string;
  /** A constant the rule compares against. */
  value?: unknown;
  /** The value `against` must have for a 'required_when' rule to apply. */
  equals?: unknown;
  message: string;
};

export type ConfigResource = {
  /** The database table this resource manages. */
  table: string;
  /** Lower-case singular, e.g. "vehicle type". */
  singular: string;
  /** Title-case singular, e.g. "Vehicle Type". */
  singularTitle: string;
  /** Title-case plural, e.g. "Vehicle Types". */
  pluralTitle: string;
  /** One-line explanation shown under the page title. */
  description: string;
  /** The permission that grants access to this page. */
  permission: string;
  /** Sub-navigation group. */
  group: string;
  /** The table has a country column, so the page shows a scope badge. */
  countryScoped?: boolean;
  /** The table has an is_active column: deleting means deactivating. */
  softDelete?: boolean;
  /** The table has no is_active column and nothing references it. */
  hardDelete?: boolean;
  /** The PostgREST select expression, including any joins. */
  selectSpec: string;
  columns: ConfigColumn[];
  fields: ConfigField[];
  /** Rows that keep this configuration row alive. */
  references?: ConfigReference[];
  /**
   * The name the reference-count function knows this table by. Defaults to
   * the table name.
   */
  referenceResource?: string;
  /**
   * Uniqueness rules enforced by the console before it writes, so the
   * operator gets a readable message instead of a database constraint error.
   */
  uniqueColumns?: { columns: string[]; label: string }[];
  /** Cross-field validation a single field cannot express. */
  validate?: (values: ConfigFieldValues) => Record<string, string>;
  /** Declarative cross-field rules, run by the form and by the server. */
  crossRules?: ConfigCrossRule[];
  /** Columns the free-text search covers. */
  searchColumns?: string[];
  /** Group the list rows by this column. */
  groupBy?: string;
  /** Extra list filters beyond the standard active toggle. */
  filters?: ConfigFilter[];
  /** Optional side panel. */
  special?: ConfigSpecial;
  /** An extra action shown on every row of the table. */
  rowAction?: ConfigRowAction;
  /** Default ordering. */
  defaultSort?: { column: string; ascending: boolean };
  /** The list is not paginated because it is always short. */
  noPagination?: boolean;
  /**
   * Server-side hook that fills in computed columns after the rows are
   * fetched. It may run extra queries.
   */
  augment?: (rows: Record<string, unknown>[], ctx: AugmentContext) => Promise<void>;
  /**
   * Builds the PostgREST filter clause for one of the resource's special
   * filters. The engine applies the clause to the list query, so the result
   * is still filtered, sorted and paginated by the database.
   */
  specialListFilter?: (args: {
    client: import('@supabase/supabase-js').SupabaseClient;
    filters: ListFilters;
  }) => Promise<{ orFilter: string } | null>;
  /** The table is a join of two tables rather than one. */
  composite?: boolean;
  /**
   * Writes go through this SECURITY DEFINER RPC instead of a direct
   * insert/update/delete. Geography tables use it to convert WKT text into
   * PostGIS geography values.
   */
  writeRpc?: string;
  /** The RPC that counts live references for the deactivation guard. */
  referenceCountsRpc?: string;
  /** Fills computed fields on a single row before the edit form opens. */
  augmentRecord?: (row: Record<string, unknown>, ctx: AugmentContext) => Promise<void>;
};

/** What an augment hook may use to run its own queries. */
export type AugmentContext = {
  /** The Supabase client bound to the signed-in admin. */
  client: import('@supabase/supabase-js').SupabaseClient;
  /** The list filters that produced these rows. */
  filters: ListFilters;
};

/** The filters a configuration list understands. */
export type ListFilters = {
  search?: string;
  /** 'all' shows every row, the others narrow to is_active. */
  status?: 'all' | 'active' | 'inactive';
  /** A country id, or 'all'. */
  country?: string;
  page?: number;
  pageSize?: number;
  sort?: string;
  direction?: 'asc' | 'desc';
  /** Values for the resource's own extra filters. */
  extra?: Record<string, string>;
};
