import { ProviderError } from '../errors.ts';
import type { AutocompletePrediction, DistanceResult, GeocodeResult } from '../types/index.ts';
import { type FetchLike, requestJson, type SleepLike } from './base.ts';

export interface GoogleMapsConfig {
  apiKey: string;
  baseUrl?: string;
  routesBaseUrl?: string;
  fetchImpl?: FetchLike;
  sleep?: SleepLike;
  requestId?: string;
}

interface LatLng {
  lat: number;
  lng: number;
}

interface RouteMatrixElement {
  originIndex?: number;
  destinationIndex?: number;
  status?: {
    code?: number;
    message?: string;
  };
  condition?: string;
  distanceMeters?: number;
  duration?: string;
}

const ROUTE_TRAVEL_MODES: Record<string, string> = {
  driving: 'DRIVE',
  walking: 'WALK',
  bicycling: 'BICYCLE',
  transit: 'TRANSIT',
};

function parseDurationSeconds(value: string | undefined): number | null {
  if (!value) return null;
  const match = value.match(/^(\d+(?:\.\d+)?)s$/);
  return match ? Number(match[1]) : null;
}

export class GoogleMapsClient {
  private readonly baseUrl: string;
  private readonly routesBaseUrl: string;
  private readonly config: GoogleMapsConfig;

  constructor(config: GoogleMapsConfig) {
    this.config = config;
    this.baseUrl = (config.baseUrl ?? 'https://maps.googleapis.com').replace(/\/$/, '');
    this.routesBaseUrl = (config.routesBaseUrl ?? config.baseUrl ?? 'https://routes.googleapis.com')
      .replace(/\/$/, '');
  }

  async calculateDistance(
    origins: LatLng[],
    destinations: LatLng[],
    mode = 'driving',
  ): Promise<DistanceResult> {
    const travelMode = ROUTE_TRAVEL_MODES[mode] ?? 'DRIVE';
    const body: Record<string, unknown> = {
      origins: origins.map((point) => ({
        waypoint: {
          location: { latLng: { latitude: point.lat, longitude: point.lng } },
        },
      })),
      destinations: destinations.map((point) => ({
        waypoint: {
          location: { latLng: { latitude: point.lat, longitude: point.lng } },
        },
      })),
      travelMode,
    };
    if (travelMode === 'DRIVE') body.routingPreference = 'TRAFFIC_AWARE';

    const url = `${this.routesBaseUrl}/distanceMatrix/v2:computeRouteMatrix`;
    const { data } = await requestJson<RouteMatrixElement[]>('google_maps', url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.config.apiKey,
        'X-Goog-FieldMask':
          'originIndex,destinationIndex,duration,distanceMeters,status,condition',
      },
      body: JSON.stringify(body),
    }, {
      fetchImpl: this.config.fetchImpl,
      sleep: this.config.sleep,
      requestId: this.config.requestId,
    });

    const elements = Array.isArray(data) ? data : [];
    const element = elements.find((item) =>
      (item.originIndex ?? 0) === 0 && (item.destinationIndex ?? 0) === 0
    ) ?? elements[0];
    if (!element) {
      throw new ProviderError('google_maps', 'Routes API returned no route matrix elements');
    }
    if (element.status?.code) {
      throw new ProviderError(
        'google_maps',
        `Routes API element returned ${element.status.code}: ${
          element.status.message ?? 'unknown error'
        }`,
      );
    }
    if (element.condition && element.condition !== 'ROUTE_EXISTS') {
      throw new ProviderError('google_maps', `Routes API element returned ${element.condition}`);
    }
    if (typeof element.distanceMeters !== 'number') {
      throw new ProviderError('google_maps', 'Routes API element is missing distanceMeters');
    }
    const durationSeconds = parseDurationSeconds(element.duration);
    if (durationSeconds === null) {
      throw new ProviderError('google_maps', 'Routes API element is missing duration');
    }

    return {
      distance_km: Math.round((element.distanceMeters / 1_000) * 100) / 100,
      duration_min: Math.round((durationSeconds / 60) * 100) / 100,
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
