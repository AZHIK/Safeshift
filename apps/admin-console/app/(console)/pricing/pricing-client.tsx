'use client'

import { useState, useTransition } from 'react'
import { createPricingPlan, updatePricingPlan, deactivatePricingPlan, deletePricingPlan } from './actions'

type Plan = {
  id: string
  name: string
  code: string
  isActive: boolean
  country: string
  city: string
  vehicle: string
  currency: string
  baseFare: number
  perKm: number
  perMin: number
  minimum: number
  vat: number
}

type Option = { id: string; name: string }

export function PricingClient({
  plans,
  countries,
  cities,
  vehicleTypes,
}: {
  plans: Plan[]
  countries: Option[]
  cities: { id: string; name: string; country_id: string }[]
  vehicleTypes: Option[]
}) {
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Plan | null>(null)
  const [pending, startTransition] = useTransition()
  const [error, setError] = useState<string | null>(null)

  const [countryId, setCountryId] = useState(countries[0]?.id ?? '')
  const cityOptions = cities.filter((c) => c.country_id === countryId)

  function openCreate() {
    setEditing(null)
    setOpen(true)
    setError(null)
  }
  function openEdit(plan: Plan) {
    setEditing(plan)
    setOpen(true)
    setError(null)
  }

  function submit(formData: FormData) {
    startTransition(async () => {
      try {
        if (editing) await updatePricingPlan(editing.id, formData)
        else await createPricingPlan(formData)
        setOpen(false)
        window.location.reload()
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed')
      }
    })
  }

  function run(action: () => Promise<void>) {
    startTransition(async () => {
      try {
        await action()
        window.location.reload()
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed')
      }
    })
  }

  return (
    <>
      <div style={{ marginBottom: 12 }}>
        <button className="btn btn-primary" onClick={openCreate}>
          New pricing plan
        </button>
        {error ? (
          <div className="notice notice-error" style={{ marginTop: 8 }}>
            {error}
          </div>
        ) : null}
      </div>

      <table className="data-table">
        <thead>
          <tr>
            <th>Plan</th>
            <th>Scope</th>
            <th>Base fare</th>
            <th>Per km</th>
            <th>Per min</th>
            <th>Minimum</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {plans.map((p) => (
            <tr key={p.id}>
              <td>
                <strong>{p.name}</strong>
                <div className="small muted">{p.code}</div>
              </td>
              <td className="small">
                {p.country} · {p.city} · {p.vehicle}
              </td>
              <td>{p.currency} {p.baseFare.toFixed(2)}</td>
              <td>{p.currency} {p.perKm.toFixed(2)}</td>
              <td>{p.currency} {p.perMin.toFixed(2)}</td>
              <td>{p.currency} {p.minimum.toFixed(2)}</td>
              <td>{p.isActive ? 'Active' : 'Disabled'}</td>
              <td style={{ display: 'flex', gap: 6 }}>
                <button className="btn btn-sm" onClick={() => openEdit(p)}>
                  Edit
                </button>
                <button
                  className="btn btn-sm"
                  disabled={!p.isActive || pending}
                  onClick={() => run(() => deactivatePricingPlan(p.id))}
                >
                  Deactivate
                </button>
                <button
                  className="btn btn-sm btn-danger"
                  disabled={pending}
                  onClick={() => {
                    if (confirm('Delete this pricing plan?')) run(() => deletePricingPlan(p.id))
                  }}
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
          {plans.length === 0 ? (
            <tr>
              <td colSpan={8} className="small muted">
                No pricing plans found.
              </td>
            </tr>
          ) : null}
        </tbody>
      </table>

      {open ? (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(11, 29, 51, 0.55)',
            display: 'flex',
            alignItems: 'flex-start',
            justifyContent: 'center',
            padding: '40px 16px',
            overflowY: 'auto',
            zIndex: 60,
          }}
          onClick={() => setOpen(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: 18,
              boxShadow: '0 14px 40px rgba(24, 45, 75, 0.08)',
              width: 'min(800px, 95vw)',
              maxHeight: '90vh',
              overflow: 'auto',
              padding: 32,
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-semibold mb-4">
              {editing ? 'Edit pricing plan' : 'New pricing plan'}
            </h3>
            <form action={submit} className="form-grid space-y-6">
              {!editing ? (
                <>
                  <div className="field">
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Country
                    </label>
                    <select
                      name="country_id"
                      required
                      className="input"
                      value={countryId}
                      onChange={(e) => setCountryId(e.target.value)}
                    >
                      {countries.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="field">
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      City
                    </label>
                    <select name="city_id" required className="input">
                      {cityOptions.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="field">
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Vehicle type
                    </label>
                    <select name="vehicle_type_id" required className="input">
                      {vehicleTypes.map((v) => (
                        <option key={v.id} value={v.id}>
                          {v.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="field">
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Code
                    </label>
                    <input name="code" required className="input" />
                  </div>
                </>
              ) : (
                <input type="hidden" name="code" value={editing.code} />
              )}
              <div className="field">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Name
                </label>
                <input
                  name="name"
                  required
                  defaultValue={editing?.name ?? ''}
                  className="input"
                />
              </div>
              <div className="field">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description
                </label>
                <input
                  name="description"
                  defaultValue={editing ? '' : ''}
                  className="input"
                />
              </div>
              <div className="field">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Currency
                </label>
                <input
                  name="currency_code"
                  defaultValue={editing?.currency ?? 'TZS'}
                  className="input"
                />
              </div>
              <div className="field">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Base fare
                </label>
                <input
                  name="base_fare"
                  type="number"
                  min="0"
                  step="0.01"
                  defaultValue={editing?.baseFare ?? 0}
                  className="input"
                />
              </div>
              <div className="field">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Per km rate
                </label>
                <input
                  name="per_km_rate"
                  type="number"
                  min="0"
                  step="0.01"
                  defaultValue={editing?.perKm ?? 0}
                  className="input"
                />
              </div>
              <div className="field">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Per minute rate
                </label>
                <input
                  name="per_min_rate"
                  type="number"
                  min="0"
                  step="0.01"
                  defaultValue={editing?.perMin ?? 0}
                  className="input"
                />
              </div>
              <div className="field">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Minimum charge
                </label>
                <input
                  name="minimum_charge"
                  type="number"
                  min="0"
                  step="0.01"
                  defaultValue={editing?.minimum ?? 0}
                  className="input"
                />
              </div>
              <div className="field">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  VAT rate (fraction)
                </label>
                <input
                  name="vat_rate"
                  type="number"
                  min="0"
                  max="1"
                  step="0.01"
                  defaultValue={editing?.vat ?? 0.18}
                  className="input"
                />
              </div>
              {editing ? (
                <div className="field">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Active
                  </label>
                  <select
                    name="is_active"
                    defaultValue={editing.isActive ? 'true' : 'false'}
                    className="input"
                  >
                    <option value="true">Active</option>
                    <option value="false">Disabled</option>
                  </select>
                </div>
              ) : null}
              <div className="form-row">
                <div className="flex items-end justify-end space-x-3">
                  <button type="button" className="btn btn-outline" onClick={() => setOpen(false)}>
                    Cancel
                  </button>
                  <button type="submit" className="btn btn-primary" disabled={pending}>
                    {pending ? 'Saving…' : 'Save'}
                  </button>
                </div>
              </div>
            </form>
            {error ? (
              <div className="mt-4 p-3 rounded-md bg-red-100 text-red-800 text-sm alert">
                <strong>Error:</strong> {error}
              </div>
            ) : null}
          </div>
        </div>
      ) : null}
    </>
  )
}