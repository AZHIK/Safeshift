import type { CountryOption, IconOption } from '@/lib/catalog';

export type VehicleTypeDefaults = {
  id?: string;
  code?: string;
  name?: string;
  description?: string;
  iconUrl?: string;
  countryId?: string;
  capacityKgMin?: number | null;
  capacityKgMax?: number | null;
  capacityM3Min?: number | null;
  capacityM3Max?: number | null;
  numberOfWheels?: number | null;
  requiresSpecialLicence?: boolean;
  displayOrder?: number | null;
  isActive?: boolean;
};

export type CargoTypeDefaults = {
  id?: string;
  code?: string;
  name?: string;
  description?: string;
  iconUrl?: string;
  countryId?: string;
  categoryId?: string;
  requiresSpecialHandling?: boolean;
  requiresDeclaredValue?: boolean;
  requiresInsurance?: boolean;
  maxValueTzs?: number | null;
  displayOrder?: number | null;
  allowedVehicleTypeCodes?: string[];
  prohibitedVehicleTypeCodes?: string[];
  isActive?: boolean;
};

function ScopeField({ countries, selected }: { countries: CountryOption[]; selected?: string }) {
  return (
    <div className="field">
      <label htmlFor="country_id">Country scope</label>
      <select className="input" id="country_id" name="country_id" defaultValue={selected ?? ''}>
        <option value="">Global — every market</option>
        {countries.map((country) => (
          <option key={country.id} value={country.id}>
            {country.name} ({country.isoCode})
          </option>
        ))}
      </select>
    </div>
  );
}

function IconField({
  id,
  options,
  selected,
}: {
  id: string;
  options: IconOption[];
  selected?: string;
}) {
  return (
    <div className="field">
      <label htmlFor={id}>Icon</label>
      <input
        className="input"
        id={id}
        name="icon_url"
        list={`${id}-options`}
        defaultValue={selected ?? ''}
        placeholder="vehicle/pickup.svg"
      />
      <datalist id={`${id}-options`}>
        {options.map((option) => (
          <option key={option.path} value={option.path}>
            {option.label}
          </option>
        ))}
      </datalist>
      <span className="small muted">
        Path inside the <span className="mono">catalog-icons</span> bucket, or a full URL.
      </span>
    </div>
  );
}

/**
 * The fields of a vehicle category.
 *
 * The caller wraps this in the form and supplies the action, so the same
 * markup serves both "add" and "edit".
 */
export function VehicleTypeFields({
  defaults,
  countries,
  iconOptions,
}: {
  defaults: VehicleTypeDefaults;
  countries: CountryOption[];
  iconOptions: IconOption[];
}) {
  return (
    <>
      {defaults.id ? <input type="hidden" name="id" value={defaults.id} /> : null}
      <div className="form-row">
        <div className="field">
          <label htmlFor="vt-code">Code</label>
          <input
            className="input"
            id="vt-code"
            name="code"
            required
            defaultValue={defaults.code ?? ''}
            placeholder="refrigerated_truck"
          />
          <span className="small muted">Durable key used by pricing rules and the apps.</span>
        </div>
        <div className="field">
          <label htmlFor="vt-name">Name</label>
          <input
            className="input"
            id="vt-name"
            name="name"
            required
            defaultValue={defaults.name ?? ''}
            placeholder="Refrigerated truck"
          />
        </div>
        <div className="field">
          <label htmlFor="vt-order">Display order</label>
          <input
            className="input"
            id="vt-order"
            name="display_order"
            type="number"
            defaultValue={defaults.displayOrder ?? 0}
          />
        </div>
      </div>
      <div className="field">
        <label htmlFor="vt-description">Description</label>
        <input
          className="input"
          id="vt-description"
          name="description"
          defaultValue={defaults.description ?? ''}
          placeholder="What this vehicle is used for."
        />
      </div>
      <div className="form-row">
        <div className="field">
          <label htmlFor="vt-min">Min capacity (kg)</label>
          <input
            className="input"
            id="vt-min"
            name="capacity_kg_min"
            type="number"
            step="any"
            required
            min="0"
            defaultValue={defaults.capacityKgMin ?? ''}
          />
        </div>
        <div className="field">
          <label htmlFor="vt-max">Max capacity (kg)</label>
          <input
            className="input"
            id="vt-max"
            name="capacity_kg_max"
            type="number"
            step="any"
            required
            min="0"
            defaultValue={defaults.capacityKgMax ?? ''}
          />
        </div>
        <div className="field">
          <label htmlFor="vt-m3min">Min volume (m³)</label>
          <input
            className="input"
            id="vt-m3min"
            name="capacity_m3_min"
            type="number"
            step="any"
            min="0"
            defaultValue={defaults.capacityM3Min ?? ''}
          />
        </div>
        <div className="field">
          <label htmlFor="vt-m3max">Max volume (m³)</label>
          <input
            className="input"
            id="vt-m3max"
            name="capacity_m3_max"
            type="number"
            step="any"
            min="0"
            defaultValue={defaults.capacityM3Max ?? ''}
          />
        </div>
        <div className="field">
          <label htmlFor="vt-wheels">Wheels</label>
          <input
            className="input"
            id="vt-wheels"
            name="number_of_wheels"
            type="number"
            min="0"
            defaultValue={defaults.numberOfWheels ?? ''}
          />
        </div>
      </div>
      <div className="form-row">
        <IconField id="vt-icon" options={iconOptions} selected={defaults.iconUrl} />
        <ScopeField countries={countries} selected={defaults.countryId} />
        <div className="field">
          <label htmlFor="vt-licence">Special licence</label>
          <label className="inline small" htmlFor="vt-licence">
            <input
              id="vt-licence"
              name="requires_special_licence"
              type="checkbox"
              defaultChecked={defaults.requiresSpecialLicence ?? false}
            />
            Requires a special licence
          </label>
        </div>
      </div>
    </>
  );
}

/** The fields of a cargo type. */
export function CargoTypeFields({
  defaults,
  countries,
  categories,
  iconOptions,
  vehicleTypeCodes,
}: {
  defaults: CargoTypeDefaults;
  countries: CountryOption[];
  categories: { id: string; name: string }[];
  iconOptions: IconOption[];
  vehicleTypeCodes: string[];
}) {
  const allowed = defaults.allowedVehicleTypeCodes ?? [];
  const prohibited = defaults.prohibitedVehicleTypeCodes ?? [];

  return (
    <>
      {defaults.id ? <input type="hidden" name="id" value={defaults.id} /> : null}
      <div className="form-row">
        <div className="field">
          <label htmlFor="ct-code">Code</label>
          <input
            className="input"
            id="ct-code"
            name="code"
            required
            defaultValue={defaults.code ?? ''}
            placeholder="building_materials"
          />
          <span className="small muted">Durable key used by pricing rules and the apps.</span>
        </div>
        <div className="field">
          <label htmlFor="ct-name">Name</label>
          <input
            className="input"
            id="ct-name"
            name="name"
            required
            defaultValue={defaults.name ?? ''}
            placeholder="Building materials"
          />
        </div>
        <div className="field">
          <label htmlFor="ct-category">Category</label>
          <select
            className="input"
            id="ct-category"
            name="category_id"
            defaultValue={defaults.categoryId ?? ''}
          >
            <option value="">No category</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="ct-order">Display order</label>
          <input
            className="input"
            id="ct-order"
            name="display_order"
            type="number"
            defaultValue={defaults.displayOrder ?? 0}
          />
        </div>
      </div>
      <div className="field">
        <label htmlFor="ct-description">Description</label>
        <input
          className="input"
          id="ct-description"
          name="description"
          defaultValue={defaults.description ?? ''}
          placeholder="What this cargo covers."
        />
      </div>
      <div className="form-row">
        <IconField id="ct-icon" options={iconOptions} selected={defaults.iconUrl} />
        <ScopeField countries={countries} selected={defaults.countryId} />
        <div className="field">
          <label htmlFor="ct-max-value">Declared value cap (TZS)</label>
          <input
            className="input"
            id="ct-max-value"
            name="max_value_tzs"
            type="number"
            step="any"
            min="0"
            defaultValue={defaults.maxValueTzs ?? ''}
          />
        </div>
      </div>
      <div className="form-row">
        <div className="field">
          <label className="inline small">
            <input
              name="requires_special_handling"
              type="checkbox"
              defaultChecked={defaults.requiresSpecialHandling ?? false}
            />
            Special handling
          </label>
        </div>
        <div className="field">
          <label className="inline small">
            <input
              name="requires_declared_value"
              type="checkbox"
              defaultChecked={defaults.requiresDeclaredValue ?? false}
            />
            Declared value required
          </label>
        </div>
        <div className="field">
          <label className="inline small">
            <input
              name="requires_insurance"
              type="checkbox"
              defaultChecked={defaults.requiresInsurance ?? false}
            />
            Insurance required
          </label>
        </div>
      </div>
      {vehicleTypeCodes.length > 0 ? (
        <div className="form-row">
          <div className="field">
            <label htmlFor="ct-allowed">Allowed vehicle types</label>
            <select
              className="input"
              id="ct-allowed"
              name="allowed_vehicle_type_codes"
              multiple
              size={Math.min(6, vehicleTypeCodes.length)}
              defaultValue={allowed}
            >
              {vehicleTypeCodes.map((code) => (
                <option key={code} value={code}>
                  {code}
                </option>
              ))}
            </select>
            <span className="small muted">None selected means every vehicle type.</span>
          </div>
          <div className="field">
            <label htmlFor="ct-prohibited">Prohibited vehicle types</label>
            <select
              className="input"
              id="ct-prohibited"
              name="prohibited_vehicle_type_codes"
              multiple
              size={Math.min(6, vehicleTypeCodes.length)}
              defaultValue={prohibited}
            >
              {vehicleTypeCodes.map((code) => (
                <option key={code} value={code}>
                  {code}
                </option>
              ))}
            </select>
            <span className="small muted">These vehicle types can never carry this cargo.</span>
          </div>
        </div>
      ) : null}
    </>
  );
}
