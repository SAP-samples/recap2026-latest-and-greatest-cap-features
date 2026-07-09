# @capire/xstravels

A **self-contained** travel booking sample for the recap2026 workshop. This is a simplified, single-package version of the [`@capire/xtravels`](https://github.com/capire/xtravels) app — everything the app depends on (flights master data, currency extensions, business partners) has been inlined into one project so the reader can `npm install && cds watch` without wiring workspaces, submodules, or remote services.

## What was inlined

| Originally from | Now inside xstravels |
|---|---|
| `@capire/xtravels` (main branch) | The Travels/Bookings core, Fiori annotations, i18n, service handlers |
| `@capire/xflights` | `db/flights.cds` — full flight-master-data schema (`Flights`, `FlightConnections`, `Airlines`, `Airports`, `Supplements`) |
| `@capire/s4` — Business Partner mock | `Customers` — a plain local entity with the same shape the S4 projection exposed |
| `@capire/common` | `db/currencies.cds` + `db/regions.cds` |

## What was dropped

- **All federation and outbox plumbing** — no more `@federated` annotations, `data-federation.js`, `service_integration()`, remote service connections, or replication schedules. Flights and Customers are first-class local entities.
- **The `xflights-api-shortcut` proxy package** — no longer needed.
- **The workspace root** — this is a plain, standalone project.

## Get started

```sh
npm install
cds watch
```

Then open the Fiori preview at http://localhost:4004.

## Refresh the seed data

The Travels/Bookings/Flights CSVs ship with dates from 2023–2024. To bring them into a rolling window around today (± 60 / +90 days), run:

```sh
npm run update-dates
```

This rewrites the CSVs **in place** — it's a local convenience, not something to commit.

## Files

```
xstravels/
├── db/
│   ├── schema.cds         — Travels, Bookings, TravelAgencies, TravelStatus, Customers
│   ├── flights.cds        — Flights master data (was @capire/xflights)
│   ├── currencies.cds     — Currencies extension (was @capire/common)
│   ├── regions.cds        — Regions/Cities/Districts (was @capire/common)
│   └── data/              — CSV seed data
├── srv/
│   ├── travel-service.cds     — the service definition
│   ├── travel-service.js      — handlers: primary keys, discounts, totals, flows, exports
│   ├── travel-flows.cds       — @flow.status state machine annotations
│   ├── travel-constraints.cds — declarative @assert constraints
│   ├── travel-exports.cds     — CSV/JSON export actions
│   └── travel-access-control.cds — @restrict role-based access
├── app/
│   ├── common/            — shared annotations (labels, value helps, code lists)
│   ├── travels/           — Fiori Elements UI for Travels
│   └── _i18n/             — English/German/French translations
└── package.json
```

## License

Apache-2.0
