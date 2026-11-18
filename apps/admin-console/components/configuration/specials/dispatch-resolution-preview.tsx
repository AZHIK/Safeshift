'use client';

import { useMemo, useState } from 'react';

export type DispatchRuleRow = {
  id: string;
  country_id: string | null;
  city_id: string | null;
  vehicle_type_id: string | null;
  country_name: string | null;
  city_name: string | null;
  vehicle_type_name: string | null;
  max_search_radius_km: number;
  offer_timeout_seconds: number;
  max_concurrent_offers: number;
  reassign_after_seconds: number;
  minimum_acceptance_rate: number | null;
  min_driver_rating: number | null;
  is_active: boolean;
};

export type DispatchScopeOption = { value: string; label: string };

/**
 * How specific a rule is. A rule that names a vehicle type is more specific
 * than one that names a city, and a city rule is more specific than a
 * country rule.
 */
export function specificity(rule: DispatchRuleRow): number {
  let score = 0;
  if (rule.country_id) score += 1;
  if (rule.city_id) score += 2;
  if (rule.vehicle_type_id) score += 4;
  return score;
}

/**
 * Picks the rule that would apply to a hypothetical job.
 *
 * The matcher reads the most specific active rule that matches every scope
 * value of the job: the vehicle type rule first, then the city, then the
 * country, then the global rule.
 */
export function resolveRule(
  rules: DispatchRuleRow[],
  job: { countryId: string; cityId: string; vehicleTypeId: string },
): DispatchRuleRow | null {
  const candidates = rules.filter((rule) => {
    if (!rule.is_active) return false;
    if (rule.country_id && rule.country_id !== job.countryId) return false;
    if (rule.city_id && rule.city_id !== job.cityId) return false;
    if (rule.vehicle_type_id && rule.vehicle_type_id !== job.vehicleTypeId) return false;
    return true;
  });

  if (candidates.length === 0) return null;

  return candidates.sort((a, b) => {
    const bySpecificity = specificity(b) - specificity(a);
    if (bySpecificity !== 0) return bySpecificity;
    return String(b.id).localeCompare(String(a.id));
  })[0];
}

/**
 * The dispatch rule resolution preview.
 *
 * It shows the cascade the matcher follows and which rule a hypothetical
 * job would land on.
 */
export function DispatchResolutionPreview({
  rules,
  countries,
  cities,
  vehicleTypes,
}: {
  rules: DispatchRuleRow[];
  countries: DispatchScopeOption[];
  cities: DispatchScopeOption[];
  vehicleTypes: DispatchScopeOption[];
}) {
  const [countryId, setCountryId] = useState(countries[0]?.value ?? '');
  const [cityId, setCityId] = useState('');
  const [vehicleTypeId, setVehicleTypeId] = useState('');

  const resolved = useMemo(
    () => resolveRule(rules, { countryId, cityId, vehicleTypeId }),
    [cityId, countryId, rules, vehicleTypeId],
  );

  const matching = rules.filter(
    (rule) =>
      rule.is_active &&
      (!rule.country_id || rule.country_id === countryId) &&
      (!rule.city_id || rule.city_id === cityId) &&
      (!rule.vehicle_type_id || rule.vehicle_type_id === vehicleTypeId),
  );

  return (
    <div className="card card-pad">
      <h3 className="card-title">Resolution preview</h3>
      <p className="card-sub">
        The matcher takes the most specific active rule: vehicle type, then city, then country, then
        the global rule.
      </p>

      <div className="form" style={{ marginTop: 12 }}>
        <div className="field">
          <label htmlFor="dispatch-country">Country</label>
          <select
            className="input"
            id="dispatch-country"
            onChange={(event) => {
              setCountryId(event.target.value);
              setCityId('');
            }}
            value={countryId}
          >
            <option value="">Any country</option>
            {countries.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <label htmlFor="dispatch-city">City</label>
          <select
            className="input"
            id="dispatch-city"
            onChange={(event) => setCityId(event.target.value)}
            value={cityId}
          >
            <option value="">Any city</option>
            {cities.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <label htmlFor="dispatch-vehicle">Vehicle type</label>
          <select
            className="input"
            id="dispatch-vehicle"
            onChange={(event) => setVehicleTypeId(event.target.value)}
            value={vehicleTypeId}
          >
            <option value="">Any vehicle type</option>
            {vehicleTypes.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {resolved ? (
        <div className="calculator-result">
          <div className="small muted">Rule that would apply</div>
          <div className="small" style={{ fontWeight: 650 }}>
            {resolved.country_name ?? 'All countries'}
            {resolved.city_name ? ` · ${resolved.city_name}` : ''}
            {resolved.vehicle_type_name ? ` · ${resolved.vehicle_type_name}` : ''}
          </div>
          <div className="small muted">
            Radius {resolved.max_search_radius_km} km · offer timeout{' '}
            {resolved.offer_timeout_seconds}s · {resolved.max_concurrent_offers} concurrent offers
          </div>
        </div>
      ) : (
        <div className="calculator-result">
          <div className="small muted">No active rule matches this combination.</div>
          <div className="small muted">The matcher falls back to its built-in defaults.</div>
        </div>
      )}

      {matching.length > 1 ? (
        <p className="small muted" style={{ marginTop: 10 }}>
          {matching.length} rules match this scope. The most specific one wins.
        </p>
      ) : null}
    </div>
  );
}
