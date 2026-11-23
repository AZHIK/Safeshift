/**
 * The option lists the configuration forms offer.
 *
 * A page loads only the option sets its own form needs. The loader keys
 * match the `optionsKey` declared on the fields in `resources/`.
 */

import type { SupabaseClient } from '@supabase/supabase-js';

import type { ConfigOption, ConfigResource } from './types';

type OptionLoader = (client: SupabaseClient) => Promise<ConfigOption[]>;

async function rows(
  client: SupabaseClient,
  table: string,
  select: string,
  order?: string,
): Promise<Record<string, unknown>[]> {
  const query = client.from(table).select(select);
  const { data, error } = order ? await query.order(order) : await query;
  if (error) return [];
  return (data ?? []) as unknown as unknown as Record<string, unknown>[];
}

const loaders: Record<string, OptionLoader> = {
  role_definitions: async (client) =>
    (await rows(client, 'admin_role_definitions', 'role_name,label', 'label')).map(row => ({
      value: String(row.role_name), label: String(row.label),
    })),
  countries: async (client) =>
    (await rows(client, 'countries', 'id, name, iso_code', 'name')).map((row) => ({
      value: String(row.id),
      label: String(row.name),
      secondary: String(row.iso_code ?? ''),
    })),

  languages: async (client) =>
    (await rows(client, 'languages', 'id, code, name, native_name', 'name')).map((row) => ({
      value: String(row.id),
      label: String(row.native_name ? `${row.name} (${row.native_name})` : row.name),
      secondary: String(row.code ?? ''),
    })),

  cities: async (client) =>
    (await rows(client, 'cities', 'id, name, country_id, countries(name, iso_code)', 'name')).map(
      (row) => {
        const country = row.countries as { name?: string; iso_code?: string } | null;
        return {
          value: String(row.id),
          label: String(row.name),
          secondary: country ? `${country.name} (${country.iso_code})` : '',
        };
      },
    ),

  regions: async (client) =>
    (await rows(client, 'regions', 'id, name, code, country_id, countries(name, iso_code)', 'name')).map(
      (row) => {
        const country = row.countries as { name?: string; iso_code?: string } | null;
        return {
          value: String(row.id),
          label: String(row.name),
          secondary: country ? `${country.name} (${country.iso_code})` : String(row.code ?? ''),
        };
      },
    ),

  service_zones: async (client) =>
    (await rows(client, 'service_zones', 'id, name, city_id, cities(name)', 'name')).map((row) => {
      const city = row.cities as { name?: string } | null;
      return {
        value: String(row.id),
        label: String(row.name),
        secondary: city ? String(city.name) : '',
      };
    }),

  neighborhoods: async (client) =>
    (await rows(client, 'neighborhoods', 'id, name, city_id', 'name')).map((row) => ({
      value: String(row.id),
      label: String(row.name),
    })),

  currencies: async (client) =>
    (await rows(client, 'currencies', 'id, code, name, symbol', 'code')).map((row) => ({
      value: String(row.code),
      label: `${row.code} — ${row.name}`,
      secondary: String(row.symbol ?? ''),
    })),

  // The currency id, for the columns that reference currencies(id) rather
  // than the three-letter code.
  currency_ids: async (client) =>
    (await rows(client, 'currencies', 'id, code, name, symbol', 'code')).map((row) => ({
      value: String(row.id),
      label: `${row.code} — ${row.name}`,
      secondary: String(row.symbol ?? ''),
    })),

  vehicle_types: async (client) =>
    (await rows(client, 'vehicle_types', 'id, code, name, is_active', 'display_order')).map(
      (row) => ({
        value: String(row.id),
        label: String(row.name),
        secondary: String(row.code ?? ''),
      }),
    ),

  vehicle_makes: async (client) =>
    (await rows(client, 'vehicle_makes', 'id, name', 'name')).map((row) => ({
      value: String(row.id),
      label: String(row.name),
    })),

  vehicle_equipment: async (client) =>
    (await rows(client, 'vehicle_equipment_catalog', 'id, code, name', 'code')).map((row) => ({
      value: String(row.code),
      label: String(row.name),
      secondary: String(row.code ?? ''),
    })),

  cargo_categories: async (client) =>
    (await rows(client, 'cargo_categories', 'id, name, parent_category_id', 'display_order')).map(
      (row) => ({
        value: String(row.id),
        label: String(row.name),
      }),
    ),

  cargo_root_categories: async (client) =>
    (await rows(client, 'cargo_categories', 'id, name', 'display_order'))
      .filter((row) => row.parent_category_id === null || row.parent_category_id === undefined)
      .map((row) => ({
        value: String(row.id),
        label: String(row.name),
      })),

  cargo_types: async (client) =>
    (await rows(client, 'cargo_types', 'id, code, name', 'display_order')).map((row) => ({
      value: String(row.id),
      label: String(row.name),
      secondary: String(row.code ?? ''),
    })),

  vehicle_type_codes: async (client) =>
    (await rows(client, 'vehicle_types', 'code', 'code')).map((row) => ({
      value: String(row.code),
      label: String(row.code),
    })),

  document_codes: async (client) =>
    (await rows(client, 'document_types', 'code, name', 'code')).map((row) => ({
      value: String(row.code),
      label: String(row.name),
      secondary: String(row.code ?? ''),
    })),

  permissions: async (client) =>
    (
      await rows(
        client,
        'admin_permissions_catalog',
        'permission_key, description, category',
        'permission_key',
      )
    ).map((row) => ({
      value: String(row.permission_key),
      label: String(row.permission_key),
      secondary: String(row.description ?? ''),
    })),

  profiles: async (client) =>
    (
      await rows(
        client,
        'profiles',
        'id, full_name, display_name, email, primary_role',
        'full_name',
      )
    )
      .filter((row) => row.primary_role === 'admin')
      .map((row) => ({
        value: String(row.id),
        label: String(row.full_name ?? row.display_name ?? row.email ?? row.id),
        secondary: String(row.email ?? ''),
      })),
};

/** The option keys a resource's form needs. */
export function requiredOptionKeys(resource: ConfigResource): string[] {
  const keys = new Set<string>();
  for (const field of resource.fields) {
    if (field.optionsKey) keys.add(field.optionsKey);
  }
  for (const filter of resource.filters ?? []) {
    if (filter.optionsKey) keys.add(filter.optionsKey);
  }
  return [...keys];
}

/** Loads the option lists a resource's form needs. */
export async function loadOptionsFor(
  client: SupabaseClient,
  resource: ConfigResource,
): Promise<Record<string, ConfigOption[]>> {
  const keys = requiredOptionKeys(resource);
  const entries = await Promise.all(
    keys.map(async (key) => {
      const loader = loaders[key];
      if (!loader) return [key, [] as ConfigOption[]] as const;
      return [key, await loader(client)] as const;
    }),
  );
  return Object.fromEntries(entries);
}
