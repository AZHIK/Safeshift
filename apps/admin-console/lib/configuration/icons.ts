/**
 * The catalogue artwork.
 *
 * The vehicle and cargo catalogues point at an artwork file through their
 * `icon_url` column. The files live in the public `catalog-icons` bucket,
 * and the console uploads them when the operator picks one from their
 * computer.
 *
 * The rules here match the bucket's own limits, so the console refuses a
 * file the bucket would refuse anyway, with a message that says why.
 */

import type { SupabaseClient } from '@supabase/supabase-js';

import { supabaseUrl } from '@/lib/supabase/config';

/** The bucket that holds the catalogue artwork. */
export const CATALOG_ICON_BUCKET = 'catalog-icons';

/** The folders inside the bucket, one per catalogue. */
export const ICON_FOLDERS = {
  vehicle: 'vehicle',
  cargo: 'cargo',
} as const;

/** The file types the bucket accepts, and nothing else. */
export const ICON_MIME_TYPES = ['image/svg+xml', 'image/png', 'image/jpeg', 'image/webp'] as const;

/** The bucket refuses anything larger than this. */
export const MAX_ICON_BYTES = 524288;

/** The extension each accepted type is stored under. */
export const ICON_EXTENSION_BY_TYPE: Record<string, string> = {
  'image/svg+xml': 'svg',
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
};

/** The `accept` attribute of the file input. */
export const ICON_ACCEPT_ATTRIBUTE = ICON_MIME_TYPES.join(',');

/**
 * Turns a value into a file name the bucket will accept.
 *
 * The name of a catalogue row is its code, which the catalogue already
 * constrains to lower-case letters, digits and underscores. The sanitising
 * here is the second line of defence, for the values that come from a file
 * name instead.
 */
export function sanitizeIconName(value: string): string {
  const cleaned = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '_')
    .replace(/^_+|_+$/g, '');
  return cleaned || 'icon';
}

/** The extension a file is stored under, taken from its type. */
export function iconExtension(file: File): string | null {
  return ICON_EXTENSION_BY_TYPE[file.type] ?? null;
}

/** The reason a file cannot be uploaded, or null when it can. */
export function validateIconFile(file: File): string | null {
  if (!ICON_EXTENSION_BY_TYPE[file.type]) {
    return 'The icon must be an SVG, PNG, JPEG or WebP file.';
  }
  if (file.size === 0) {
    return 'The chosen file is empty.';
  }
  if (file.size > MAX_ICON_BYTES) {
    return 'The icon must be smaller than 512 KB.';
  }
  return null;
}

/** The path a file is stored at inside the bucket. */
export function iconPath(folder: string, name: string, extension: string): string {
  return `${folder}/${sanitizeIconName(name)}.${extension}`;
}

/** The outcome of an upload: the stored path, or the reason it failed. */
export type IconUploadResult = { path: string; publicUrl: string } | { error: string };

/**
 * Uploads an icon the operator picked from their computer.
 *
 * The file is stored under the catalogue folder, named after the row's code,
 * so the path stays the durable value the `icon_url` column holds. Replacing
 * an icon overwrites the previous one rather than leaving orphaned artwork
 * behind. The bucket's own policies still decide whether the caller may
 * write, so a caller without the catalogue permission is refused here as
 * well as in the console.
 */
export async function uploadIcon(
  client: SupabaseClient,
  upload: { bucket: string; folder: string; name: string },
  file: File,
): Promise<IconUploadResult> {
  const extension = iconExtension(file);
  if (!extension) {
    return { error: 'The icon must be an SVG, PNG, JPEG or WebP file.' };
  }
  const invalid = validateIconFile(file);
  if (invalid) return { error: invalid };

  const path = iconPath(upload.folder, upload.name, extension);
  const { error } = await client.storage.from(upload.bucket).upload(path, file, {
    cacheControl: '3600',
    contentType: file.type,
    upsert: true,
  });
  if (error) return { error: error.message };

  return { path, publicUrl: publicIconUrl(upload.bucket, path) ?? path };
}

/**
 * The URL an icon path resolves to.
 *
 * The mobile apps read the path out of the column and resolve it the same
 * way, so the console previews exactly what the customer will see. An
 * absolute URL stored in the column is returned unchanged.
 */
export function publicIconUrl(bucket: string, path: string): string | null {
  if (!path) return null;
  if (/^https?:\/\//i.test(path)) return path;
  return `${supabaseUrl}/storage/v1/object/public/${bucket}/${path.replace(/^\/+/, '')}`;
}
