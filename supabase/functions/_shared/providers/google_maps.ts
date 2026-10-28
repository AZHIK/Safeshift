import { ProviderError } from '../errors.ts';
import type { AutocompletePrediction, DistanceResult, GeocodeResult } from '../types/index.ts';
import { type FetchLike, requestJson, type SleepLike } from './base.ts';

export interface GoogleMapsConfig {
  apiKey: string;
  baseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

interface LatLng {
  lat: number;
  lng: number;
}

export class GoogleMapsClient {
  private readonly baseUrl: string;
  private readonly config: GoogleMapsConfig;

  constructor(config: GoogleMapsConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? 'https://maps.googleapis.com').replace(/\/$/, '');
  }

  async calculateDistance(
    origins: LatLng[],
    destinations: LatLng[],
    mode = 'driving',
  ): Promise<DistanceResult> {
    const originParam = origins.map((point) => `${point.lat},${point.lng}`).join('|');
    const destinationParam = destinations.map((point) => `${point.lat},${point.lng}`).join('|');
    const url =
      `${this.baseUrl}/maps/api/distancematrix/json?origins=${encodeURIComponent(originParam)}` +
      `&destinations=${encodeURIComponent(destinationParam)}&mode=${encodeURIComponent(mode)}` +
      `&key=${encodeURIComponent(this.config.apiKey)}`;

    const { data } = await requestJson<Record<string, unknown>>('google_maps', url, {
      method: 'GET',
    }, {
      fetchImpl: this.config.fetchImpl,
      sleep: this.config.sleep,
      requestId: this.config.requestId,
    });

    if (String(data.status) !== 'OK') {
      throw new ProviderError('google_maps', `Distance Matrix returned ${data.status}`);
    }

    const rows = (data.rows ?? []) as Array<Record<string, unknown>>;
    const elements = (rows[0]?.elements ?? []) as Array<Record<string, unknown>>;
    const element = elements[0] ?? {};
    if (String(element.status) !== 'OK') {
      throw new ProviderError('google_maps', `Distance element returned ${element.status}`);
    }

    const distance = element.distance as { value?: number } | undefined;
    const duration = element.duration as { value?: number } | undefined;

    return {
      distance_km: Math.round(((distance?.value ?? 0) / 1_000) * 100) / 100,
      duration_min: Math.round(((duration?.value ?? 0) / 60) * 100) / 100,
    };
  }

  geocode(address: string): Promise<GeocodeResult> {
    const url = `${this.baseUrl}/maps/api/geocode/json?address=${encodeURIComponent(address)}` +
      `&key=${encodeURIComponent(this.config.apiKey)}`;
    return this.parseGeocode(url);
  }

  reverseGeocode(lat: number, lng: number): Promise<GeocodeResult> {
    const url = `${this.baseUrl}/maps/api/geocode/json?latlng=${lat},${lng}` +
      `&key=${encodeURIComponent(this.config.apiKey)}`;
    return this.parseGeocode(url);
  }

  private async parseGeocode(url: string): Promise<GeocodeResult> {
    const { data } = await requestJson<Record<string, unknown>>('google_maps', url, {
      method: 'GET',
    }, {
      fetchImpl: this.config.fetchImpl,
      sleep: this.config.sleep,
      requestId: this.config.requestId,
    });

    if (String(data.status) !== 'OK') {
      throw new ProviderError('google_maps', `Geocoding returned ${data.status}`);
    }

    const results = (data.results ?? []) as Array<Record<string, unknown>>;
    const first = results[0];
    if (!first) throw new ProviderError('google_maps', 'No geocoding result');

    const geometry = (first.geometry ?? {}) as { location?: LatLng };
    const location = geometry.location ?? { lat: 0, lng: 0 };

    return {
      lat: location.lat,
      lng: location.lng,
      formatted_address: String(first.formatted_address ?? ''),
      place_id: String(first.place_id ?? ''),
    };
  }

  async placesAutocomplete(
    input: string,
    sessionToken: string,
  ): Promise<AutocompletePrediction[]> {
    const url =
      `${this.baseUrl}/maps/api/place/autocomplete/json?input=${encodeURIComponent(input)}` +
      `&sessiontoken=${encodeURIComponent(sessionToken)}&key=${
        encodeURIComponent(this.config.apiKey)
      }`;

    const { data } = await requestJson<Record<string, unknown>>('google_maps', url, {
      method: 'GET',
    }, {
      fetchImpl: this.config.fetchImpl,
      sleep: this.config.sleep,
      requestId: this.config.requestId,
    });

    if (String(data.status) !== 'OK') {
      throw new ProviderError('google_maps', `Places Autocomplete returned ${data.status}`);
    }

    return ((data.predictions ?? []) as Array<Record<string, unknown>>).map((prediction) => ({
      description: String(prediction.description ?? ''),
      place_id: String(prediction.place_id ?? ''),
    }));
  }
}
