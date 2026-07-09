using { sap, managed, Country, Currency } from '@sap/cds/common';
using { sap.capire.travels.flights as f } from './flights';

namespace sap.capire.travels;

type Price : Decimal(9,4);


entity Travels : managed {
  key ID       : Integer @readonly;
  Description  : String(1024);
  BeginDate    : Date default $now;
  EndDate      : Date default $now;
  BookingFee   : Price default 0;
  TotalPrice   : Price @readonly;
  Currency     : Currency default 'EUR';
  Status       : Association to TravelStatus default 'O';
  Agency       : Association to TravelAgencies;
  Customer     : Association to Customers;
  Bookings     : Composition of many Bookings on Bookings.Travel = $self;
}


entity Bookings {
  key Travel      : Association to Travels;
  key Pos         : Integer @readonly;
      Flight      : Association to f.Flights;
      FlightPrice : Price;
      Currency    : Currency;
      Supplements : Composition of many {
        key ID   : UUID;
        booked   : Association to f.Supplements;
        Price    : Price;
        Currency : Currency;
      };
      BookingDate : Date default $now;
}


entity TravelAgencies {
  key ID           : String(6);
      Name         : String(80);
      Street       : String(60);
      PostalCode   : String(10);
      City         : String(40);
      Country      : Country;
      PhoneNumber  : String(30);
      EMailAddress : String(256);
      WebAddress   : String(256);
};


entity TravelStatus : sap.common.CodeList {
  key code : String(1) enum {
    Open     = 'O';
    InReview = 'P';
    Blocked  = 'B';
    Accepted = 'A';
    Rejected = 'X';
  }
}


/**
 * Customer master data. In the extensibility-sample this comes from S/4's
 * Business Partner API — here it's a plain local entity so xstravels stays
 * self-contained. Same field shape as the S4 projection.
 */
entity Customers {
  key ID              : String(10);
      Name            : String(80);
      modifiedAt      : Date;
      modifiedAtTime  : Time;
      Travels         : Association to many Travels on Travels.Customer = $self;
}


// Note: no back-navigation from Flights to Bookings — Flights is a
// denormalized view (see db/flights.cds), views cannot be extended with
// associations. If needed, navigate via Bookings.Flight instead.
