import type { SupabaseClient } from '@supabase/supabase-js';

/** The public bucket that holds the catalogue artwork. */
export const CATALOG_ICON_BUCKET = 'catalog-icons';

/** Folders inside the bucket, one per catalogue. */
export const CATALOG_ICON_FOLDERS = {
  vehicle_types: 'vehicle',
  cargo_types: 'cargo',
} as const;

export type CountryOption = { id: string; name: string; isoCode: string };

export type IconOption = { path: string; label: string };

/**
 * Reads the countries a catalogue row can be scoped to.
 *
 * A catalogue row with no country applies to every market, so the console
 * offers "Global" alongside the real countries.
 */
export async function loadCountries(supabase: SupabaseClient): Promise<CountryOption[]> {
  const { data } = await supabase
    .from('countries')
    .select('id, name, iso_code')
    .eq('is_active', true)
    .order('name');
  return (data ?? []).map((row) => ({
    id: row.id as string,
    name: row.name as string,
    isoCode: row.iso_code as string,
  }));
}

/**
 * Lists the artwork already uploaded to the catalogue bucket.
 *
 * The list is empty when the bucket has not been populated yet; the console
 * still accepts a typed path in that case, so nothing here is a hard-coded
 * catalogue.
 */
export async function loadIconOptions(
  supabase: SupabaseClient,
  folder: string,
): Promise<IconOption[]> {
  const { data } = await supabase.storage.from(CATALOG_ICON_BUCKET).list(folder, { limit: 200 });
  return (data ?? [])
    .filter((entry) => entry.name?.toLowerCase().endsWith('.svg'))
    .map((entry) => ({
      path: `${folder}/${entry.name}`,
      label: entry.name as string,
    }))
    .sort((a, b) => a.path.localeCompare(b.path));
}

/** The durable codes of the vehicle types, used by the cargo allow lists. */
export async function loadVehicleTypeCodes(supabase: SupabaseClient): Promise<string[]> {
  const { data } = await supabase
    .from('vehicle_types')
    .select('code')
    .eq('is_active', true)
    .order('code');
  return (data ?? []).map((row) => row.code as string);
}

/** The cargo categories a cargo type can be filed under. */
export async function loadCargoCategories(
  supabase: SupabaseClient,
): Promise<{ id: string; name: string }[]> {
  const { data } = await supabase
    .from('cargo_categories')
    .select('id, name')
    .order('display_order');
  return (data ?? []).map((row) => ({
    id: row.id as string,
    name: row.name as string,
  }));
}

/** Normalises a code: lower case, underscores, no spaces. */
export function normalizeCode(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
}

export function parseNumber(value: FormDataEntryValue | null): number | null {
  const text = String(value ?? '').trim();
  if (!text) return null;
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : null;
}

export function parseBoolean(value: FormDataEntryValue | null): boolean {
  return value === 'on' || value === 'true';
}
