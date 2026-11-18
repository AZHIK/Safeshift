/**
 * The catalogue of countries the platform supports.
 *
 * The JSON file next to this module is the source of truth for a country's
 * identity: its ISO code, its name, the currency and language it starts in,
 * the phone code its phone numbers use and the time zone it runs in.
 *
 * The catalogue grows with the platform: adding a country is adding an entry
 * to countries.json and then creating the country row in the admin console.
 * The console only ever offers the countries listed here, so an operator
 * cannot invent a market the platform has no currency or language for.
 */

import catalogueJson from './countries.json';

export type CountryCatalogueEntry = {
  /** The two-letter ISO 3166-1 code, in capitals. */
  isoCode: string;
  /** The name of the country as the operator writes it. */
  name: string;
  /** The currency the market settles in. */
  currencyCode: string;
  currencyName: string;
  currencySymbol: string;
  /** The language the customer and driver apps start in. */
  languageCode: string;
  languageName: string;
  /** The dialling code the country's phone numbers use. */
  phoneCode: string;
  /** The IANA time zone the market runs in. */
  timeZone: string;
};

/** Every supported country, in the order the catalogue lists them. */
export const countryCatalogue: CountryCatalogueEntry[] = catalogueJson.countries;

/** The catalogue entry for an ISO code, or undefined when it is not listed. */
export function countryByIsoCode(isoCode: string): CountryCatalogueEntry | undefined {
  const wanted = String(isoCode ?? '')
    .trim()
    .toUpperCase();
  return countryCatalogue.find((entry) => entry.isoCode === wanted);
}

/** The catalogue entry for a country name, or undefined when it is not listed. */
export function countryByName(name: string): CountryCatalogueEntry | undefined {
  const wanted = String(name ?? '')
    .trim()
    .toLowerCase();
  return countryCatalogue.find((entry) => entry.name.toLowerCase() === wanted);
}
