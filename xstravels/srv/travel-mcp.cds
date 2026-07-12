using { TravelService } from './travel-service';

annotate TravelService with @mcp
  @mcp.instructions: 'This service manages travel bookings. Use describe to explore available entities like Travels, Bookings, Customers, and Flights. Use query to search travels by status, date range, or agency.';
