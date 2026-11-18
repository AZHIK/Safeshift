'use client';

import type { ConfigFilter, ConfigOption } from '@/lib/configuration/types';

export type ConfigurationFilterState = {
  search: string;
  status: 'all' | 'active' | 'inactive';
  country: string;
  extra: Record<string, string>;
};

/**
 * The filter bar every configuration page shows above its table.
 *
 * The status toggle only appears for the tables that have an is_active
 * column; a feature flag is enabled or it is not, so there is nothing to
 * filter.
 */
export function ConfigurationSearchFilters({
  state,
  countries,
  filters,
  hasStatus,
  onChange,
}: {
  state: ConfigurationFilterState;
  countries?: ConfigOption[];
  filters?: ConfigFilter[];
  hasStatus: boolean;
  onChange: (next: ConfigurationFilterState) => void;
}) {
  return (
    <div className="config-toolbar">
      <div className="field config-toolbar-search">
        <label htmlFor="config-search">Search</label>
        <input
          className="input"
          id="config-search"
          onChange={(event) => onChange({ ...state, search: event.target.value })}
          placeholder="Search by name, code or description"
          type="search"
          value={state.search}
        />
      </div>

      {hasStatus ? (
        <div className="field">
          <label htmlFor="config-status">Status</label>
          <select
            className="input"
            id="config-status"
            onChange={(event) =>
              onChange({
                ...state,
                status: event.target.value as ConfigurationFilterState['status'],
              })
            }
            value={state.status}
          >
            <option value="all">All</option>
            <option value="active">Active only</option>
            <option value="inactive">Inactive only</option>
          </select>
        </div>
      ) : null}

      {countries && countries.length > 0 ? (
        <div className="field">
          <label htmlFor="config-country">Country</label>
          <select
            className="input"
            id="config-country"
            onChange={(event) => onChange({ ...state, country: event.target.value })}
            value={state.country}
          >
            <option value="all">All countries</option>
            {countries.map((country) => (
              <option key={country.value} value={country.value}>
                {country.secondary ? `${country.label} (${country.secondary})` : country.label}
              </option>
            ))}
          </select>
        </div>
      ) : null}

      {(filters ?? []).map((filter) => (
        <div className="field" key={filter.name}>
          <label htmlFor={`config-filter-${filter.name}`}>{filter.label}</label>
          <select
            className="input"
            id={`config-filter-${filter.name}`}
            onChange={(event) =>
              onChange({
                ...state,
                extra: { ...state.extra, [filter.name]: event.target.value },
              })
            }
            value={state.extra[filter.name] ?? 'all'}
          >
            <option value="all">All</option>
            {(filter.options ?? []).map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
      ))}
    </div>
  );
}
