import type { SupabaseClient } from './db.ts';
import type { DistanceResult, GeocodeResult } from './types/index.ts';

export interface Point {
  lat: number;
  lng: number;
}

export async function getCachedDistance(
  service: SupabaseClient,
  origin: Point,
  destination: Point,
  mode: string,
): Promise<DistanceResult | null> {
  const { data, error } = await service
    .from('distance_cache')
    .select('distance_km, duration_min')
    .eq('origin_lat', origin.lat)
    .eq('origin_lng', origin.lng)
    .eq('dest_lat', destination.lat)
    .eq('dest_lng', destination.lng)
    .eq('mode', mode)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();

  if (error || !data) return null;
  return {
    distance_km: Number(data.distance_km),
    duration_min: Number(data.duration_min),
  };
}

export async function storeDistance(
  service: SupabaseClient,
  origin: Point,
  destination: Point,
  mode: string,
  result: DistanceResult,
): Promise<void> {
  await service.from('distance_cache').upsert(
    {
      origin_lat: origin.lat,
      origin_lng: origin.lng,
      dest_lat: destination.lat,
      dest_lng: destination.lng,
      mode,
      distance_km: result.distance_km,
      duration_min: result.duration_min,
      cached_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1_000).toISOString(),
    },
    { onConflict: 'origin_lat,origin_lng,dest_lat,dest_lng,mode' },
  );
}

export async function getCachedForwardGeocode(
  service: SupabaseClient,
  address: string,
): Promise<GeocodeResult | null> {
  const { data, error } = await service
    .from('geocoding_cache')
    .select('result')
    .eq('query_type', 'forward')
    .eq('query_text', address.trim().toLowerCase())
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();

  if (error || !data) return null;
  return data.result as GeocodeResult;
}

export async function getCachedReverseGeocode(
  service: SupabaseClient,
  lat: number,
  lng: number,
): Promise<GeocodeResult | null> {
  const { data, error } = await service
    .from('geocoding_cache')
    .select('result')
    .eq('query_type', 'reverse')
    .eq('query_lat', lat)
    .eq('query_lng', lng)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();

  if (error || !data) return null;
  return data.result as GeocodeResult;
}

export async function storeForwardGeocode(
  service: SupabaseClient,
  address: string,
  result: GeocodeResult,
): Promise<void> {
  await service.from('geocoding_cache').upsert(
    {
      query_type: 'forward',
      query_text: address.trim().toLowerCase(),
      result,
      cached_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1_000).toISOString(),
    },
    { onConflict: 'query_text' },
  );
}

export async function storeReverseGeocode(
  service: SupabaseClient,
  lat: number,
  lng: number,
  result: GeocodeResult,
): Promise<void> {
  await service.from('geocoding_cache').upsert(
    {
      query_type: 'reverse',
      query_lat: lat,
      query_lng: lng,
      result,
      cached_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1_000).toISOString(),
    },
    { onConflict: 'query_lat,query_lng' },
  );
}
