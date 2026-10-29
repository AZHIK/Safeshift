import type { SupabaseClient } from '@supabase/supabase-js';

export type ProfileSummary = {
  profile_id: string;
  full_name: string | null;
  display_name: string | null;
  phone: string | null;
  email: string | null;
  primary_role: string | null;
  is_active: boolean | null;
};

export async function loadProfileSummaries(
  supabase: SupabaseClient,
  ids: Array<string | null | undefined>,
): Promise<Map<string, ProfileSummary>> {
  const unique = [...new Set(ids.filter((id): id is string => Boolean(id)))];
  if (unique.length === 0) return new Map();
  const { data, error } = await supabase.rpc('admin_profile_summaries', { p_ids: unique });
  if (error) return new Map();
  const map = new Map<string, ProfileSummary>();
  for (const row of (data ?? []) as ProfileSummary[]) {
    map.set(row.profile_id, row);
  }
  return map;
}
