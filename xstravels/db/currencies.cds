using { sap } from '@sap/cds/common';

/**
 * Extend sap.common.Currencies with ISO-4217 details.
 * Originally from @capire/common, inlined here for self-containment.
 *
 * Currencies.code = ISO 4217 alphabetic three-letter code
 * with the first two letters being equal to ISO 3166 alphabetic country codes.
 * See also:
 * [1] https://www.iso.org/iso-4217-currency-codes.html
 * [2] https://www.currency-iso.org/en/home/tables/table-a1.html
 */
extend sap.common.Currencies with {
  numcode  : Integer;
  exponent : Integer; //> e.g. 2 --> 1 Dollar = 10^2 Cent
  minor    : String;  //> e.g. 'Cent'
}
