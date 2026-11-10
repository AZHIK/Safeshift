import { ProviderError } from '../errors.ts';
import type {
  AutocompletePrediction,
  DistanceResult,
  GeocodeResult,
  RouteResult,
} from '../types/index.ts';
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

interface ComputeRouteCandidate {
  distanceMeters?: number;
  duration?: string;
  polyline?: {
    encodedPolyline?: string;
  };
  routeLabels?: string[];
}

interface ComputeRoutesResponse {
  routes?: ComputeRouteCandidate[];
}

const ROUTE_TRAVEL_MODES: Record<string, string> = {
  driving: 'DRIVE',
  walking: 'WALK',
  bicycling: 'BICYCLE',
  transit: 'TRANSIT',
};

function roundTo(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

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
    // The Routes API lives on its own host. It must never fall back to
    // `baseUrl`, which is the Geocoding/Places host: posting a Compute Routes
    // request to it 404s with an empty body and is indistinguishable from a
    // missing API key.
    this.routesBaseUrl = (config.routesBaseUrl ?? 'https://routes.googleapis.com').replace(/\/$/, '');
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
      timeoutMs: 60_000,
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

  /**
   * Computes a single driving route between one origin and one destination using
   * Google Routes API `Compute Routes`.
   *
   * Returns road distance, duration, and the encoded polyline geometry. A
   * synthetic route label is derived from the provider's route label so the
   * client can surface it when supported.
   */
  async calculateRoute(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
    mode = 'driving',
  ): Promise<RouteResult> {
    const travelMode = ROUTE_TRAVEL_MODES[mode] ?? 'DRIVE';
    const routingPreference =
      travelMode === 'DRIVE' ? 'TRAFFIC_AWARE' : undefined;

    const body: Record<string, unknown> = {
      origin: {
        location: { latLng: { latitude: origin.lat, longitude: origin.lng } },
      },
      destination: {
        location: { latLng: { latitude: destination.lat, longitude: destination.lng } },
      },
      travelMode,
      computeAlternativeRoutes: false,
      // `PolylineQuality` is an enum: the accepted values are
      // POLYLINE_QUALITY_UNSPECIFIED, LOW, MEDIUM and HIGH_QUALITY. The bare
      // string "HIGH" is not a member and is rejected with INVALID_ARGUMENT.
      polylineQuality: 'HIGH_QUALITY',
      polylineEncoding: 'ENCODED_POLYLINE',
    };
    if (routingPreference) body.routingPreference = routingPreference;

    // Compute Routes is served from /directions/v2 on the Routes API host.
    // There is no /v1:computeRoutes path; requesting it 404s with an empty
    // body, which is impossible to tell apart from a disabled API.
    const url = `${this.routesBaseUrl}/directions/v2:computeRoutes`;
    const { data } = await requestJson<ComputeRoutesResponse>('google_maps', url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': this.config.apiKey,
        'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.routeLabels',
      },
      body: JSON.stringify(body),
    }, {
      fetchImpl: this.config.fetchImpl,
      sleep: this.config.sleep,
      requestId: this.config.requestId,
      timeoutMs: 60_000,
    });

    const routes = Array.isArray(data?.routes) ? data.routes : [];
    const route = routes[0];
    if (!route || typeof route.distanceMeters !== 'number') {
      throw new ProviderError('google_maps', 'Routes API returned no route');
    }
    const encodedPolyline =
      typeof route.polyline?.encodedPolyline === 'string' &&
      route.polyline.encodedPolyline.length > 0
        ? route.polyline.encodedPolyline
        : '';
    if (encodedPolyline.length === 0) {
      throw new ProviderError('google_maps', 'Routes API returned an empty polyline');
    }
    const durationSeconds = parseDurationSeconds(route.duration);
    if (durationSeconds === null) {
      throw new ProviderError('google_maps', 'Routes API is missing route duration');
    }
    const routeLabels = Array.isArray(route.routeLabels) ? route.routeLabels : [];
    return {
      distance_km: roundTo(route.distanceMeters / 1_000, 2),
      duration_min: roundTo(durationSeconds / 60, 2),
      encoded_polyline: encodedPolyline,
      route_label: routeLabels.includes('DEFAULT_ROUTE') ? 'DEFAULT_ROUTE' : undefined,
      traffic_aware: routingPreference !== undefined,
    };
  }
}
