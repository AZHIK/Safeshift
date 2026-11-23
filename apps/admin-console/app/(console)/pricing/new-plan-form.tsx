'use client';

import { useState } from 'react';

import { createPricingPlanAction } from './actions';

type Option = { id: string; name: string };
type CityOption = Option & { country_id: string };

/** Creates a plan; its first version is published with these base rates. */
export function NewPlanForm({
  countries,
  cities,
  vehicleTypes,
}: {
  countries: Option[];
  cities: CityOption[];
  vehicleTypes: Option[];
}) {
  const [open, setOpen] = useState(false);
  const [countryId, setCountryId] = useState(countries[0]?.id ?? '');
  const cityOptions = cities.filter((c) => c.country_id === countryId);

  if (!open) {
    return (
      <button type="button" className="btn btn-primary" onClick={() => setOpen(true)}>
        New plan
      </button>
    );
  }

  return (
    <div className="dialog-backdrop" role="presentation" onClick={() => setOpen(false)}>
      <div
        className="dialog dialog-wide"
        role="dialog"
        aria-modal="true"
        aria-labelledby="new-plan-title"
        onClick={(e) => e.stopPropagation()}
      >
        <form action={createPricingPlanAction}>
          <div className="dialog-head">
            <h2 className="dialog-title" id="new-plan-title">
              New pricing plan
            </h2>
          </div>
          <div className="dialog-body form">
            <p className="small muted">
              Version 1 is published straight away with these rates. Add tiers, surcharges and
              multipliers afterwards through a draft.
            </p>
            <div className="form-grid">
              <label className="field">
                Country
                <select
                  className="input"
                  name="country_id"
                  required
                  value={countryId}
                  onChange={(e) => setCountryId(e.target.value)}
                >
                  {countries.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="field">
                City
                <select className="input" name="city_id" required key={countryId}>
                  {cityOptions.length === 0 ? <option value="">No active cities</option> : null}
                  {cityOptions.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="field">
                Vehicle type
                <select className="input" name="vehicle_type_id" required>
                  {vehicleTypes.map((v) => (
                    <option key={v.id} value={v.id}>
                      {v.name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="field">
                Currency
                <input className="input" name="currency_code" defaultValue="TZS" maxLength={3} required />
              </label>
              <label className="field">
                Name
                <input className="input" name="name" required placeholder="Dar es Salaam · Pickup" />
              </label>
              <label className="field">
                Code
                <input
                  className="input"
                  name="code"
                  required
                  pattern="[a-z0-9]+(-[a-z0-9]+)*"
                  title="Lowercase letters and digits separated by hyphens"
                  placeholder="dar-pickup"
                />
              </label>
            </div>
            <label className="field">
              Description
              <input className="input" name="description" />
            </label>
            <div className="form-grid">
              <label className="field">
                Base fare
                <input className="input" name="base_fare" type="number" min="0" step="0.01" required />
              </label>
              <label className="field">
                Per km
                <input className="input" name="per_km_rate" type="number" min="0" step="0.01" required />
              </label>
              <label className="field">
                Per minute
                <input className="input" name="per_min_rate" type="number" min="0" step="0.01" required />
              </label>
              <label className="field">
                Minimum charge
                <input className="input" name="minimum_charge" type="number" min="0" step="0.01" defaultValue="0" />
              </label>
              <label className="field">
                VAT %
                <input
                  className="input"
                  name="vat_percent"
                  type="number"
                  min="0"
                  max="100"
                  step="0.01"
                  defaultValue="18"
                />
              </label>
            </div>
          </div>
          <div className="dialog-foot">
            <button type="button" className="btn" onClick={() => setOpen(false)}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              Create plan
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
