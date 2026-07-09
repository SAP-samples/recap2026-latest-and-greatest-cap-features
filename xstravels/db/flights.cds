using { sap, managed, cuid, Currency, Country, sap.common.CodeList } from '@sap/cds/common';

namespace sap.capire.travels.flights;


/**
 * A scheduled flight on a specific date with a specific aircraft and price.
 *
 * This is the raw data table (fed by CSV). The public consumption entity is
 * `Flights` below — a denormalized view that flattens airline/airport paths.
 */
entity FlightSchedules : managed {
  key flight     : Association to FlightConnections;
  key date       : Date;
  aircraft       : String;
  price          : Decimal(9,4);
  currency       : Currency;
  maximum_seats  : Integer;
  occupied_seats : Integer;
  free_seats     : Integer = maximum_seats - occupied_seats;
}

/**
 * Denormalized view of a flight schedule. Consumed by Bookings, the service
 * projection, and the Fiori UI. Mirrors the flattened shape the original
 * xflights data-service exposed via its projection.
 */
entity Flights as select from FlightSchedules {
  key flight.ID  as ID,
  key date,
      aircraft,
      price,
      currency,
      maximum_seats,
      occupied_seats,
      free_seats,
      modifiedAt,
      flight.airline.icon     as icon @UI.IsImageURL,
      flight.airline.name     as airline,
      flight.origin.name      as origin,
      flight.destination.name as destination,
      flight.departure        as departure,
      flight.arrival          as arrival,
};

/**
 * A flight connection between two airports operated by an airline.
 */
entity FlightConnections {
  key ID      : String(11); // e.g. LH4711
  airline     : Association to Airlines;
  origin      : Association to Airports;
  destination : Association to Airports;
  departure   : Time;
  arrival     : Time;
  distance    : Integer; // in kilometers
}

entity Airlines : cuid, managed {
  name     : String;
  icon     : String;
  currency : Currency;
  flights  : Association to many FlightConnections on flights.airline = $self;
}

entity Airports : cuid, managed {
  name       : String;
  city       : String;
  country    : Country;
  arrivals   : Association to many FlightConnections on arrivals.destination = $self;
  departures : Association to many FlightConnections on departures.origin = $self;
}

entity Supplements : cuid, managed {
  type     : Association to SupplementTypes;
  descr    : localized String(1111);
  price    : Decimal(9,4);
  currency : Currency;
}

entity SupplementTypes : CodeList {
  key code : String(2) enum {
    Beverage = 'BV';
    Meal     = 'ML';
    Luggage  = 'LU';
    Extra    = 'EX';
  }
}
