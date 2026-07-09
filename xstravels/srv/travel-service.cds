using { sap.capire.travels as our, sap } from '../db/schema';
using { sap.capire.travels.flights as f } from '../db/flights';

@fiori service TravelService {

  entity Travels as projection on our.Travels actions {
    action deductDiscount( percent: Percentage not null ) returns Travels;
    action acceptTravel();
    action rejectTravel();
    action reopenTravel();
  }

  // Also expose related entities as read-only projections
  @readonly entity TravelAgencies as projection on our.TravelAgencies;
  @readonly entity Currencies     as projection on sap.common.Currencies;
  @readonly entity Customers      as projection on our.Customers;
  @readonly entity Flights        as projection on f.Flights;
  @readonly entity Supplements    as projection on f.Supplements;

}

// Custom type for percentage values
type Percentage : Integer @assert.range: [1,100];
