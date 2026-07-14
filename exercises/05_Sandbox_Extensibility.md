# Exercise 5 - Sandbox Extensibility

In this exercise, you will turn a single line of an internal state machine into a **public extension point** — a hook that customers can implement without ever touching your source code. The customer's code runs in a WebAssembly sandbox managed by CDS-Oyster, with a strictly scoped data view. You'll enable multitenancy, add a dedicated extension service, wire it into the `submitForReview` action from Exercise 4, and use the pre-built [`xstravels-ext/`](../xstravels-ext/) template to write and push a real handler.

> This is a compressed single chapter for what the full [`cap-js/extensibility-sample`](https://github.com/cap-js/extensibility-sample) workshop covers in 11 chapters. If you're serious about shipping an extensible CAP app, work through that at some point.

## Prerequisites


## Patch-first — if you skipped Exercise 4

If you have completed [Exercise 4 - Status Flows](04_Status_Flows.md), skip this section and
proceed with [What we're building](#what-were-building).

Ex5 builds on the `submitForReview` action introduced in Ex4. If it isn't in your code yet, apply these two edits before starting:

**`xstravels/srv/travel-service.cds`** — add the action inside the `Travels` projection:

```cds
entity Travels as projection on our.Travels actions {
  action deductDiscount( percent: Percentage not null ) returns Travels;
  action acceptTravel();
  action rejectTravel();
  action reopenTravel();
  action submitForReview();     // 👈 add this
}
```

**`xstravels/srv/travel-flows.cds`** — extend the flow:

```cds
annotate TravelService.Travels with @flow.status: Status actions {
  deductDiscount   @from: [ #Open ];
  submitForReview  @from: [ #Open ]                @to: #InReview;   // 👈 add this
  acceptTravel     @from: [ #InReview ]            @to: #Accepted;   // 👈 InReview, not Open
  rejectTravel     @from: [ #InReview ]            @to: #Rejected;   // 👈 InReview, not Open
  reopenTravel     @from: [ #Rejected, #Accepted ] @to: #Open;
}
```

Verify `cds watch` still boots, then continue.

## What we're building

Today `submitForReview` is a pure state transition — every open travel can be pushed into review, no questions asked. What if a customer has a **budget policy**: no travel over 10 000 EUR can be reviewed by an ordinary reviewer? They'd have to fork xstravels or wrap it in a proxy service. Neither scales.

The pattern we introduce here:

1. Declare an **extension service** (`@kind: 'ext-service'`) that defines an action `validateReview` and exposes read-only projections of the data the extension needs.
2. Wire that action into `submitForReview` as a `before` handler. It runs before the framework's `@to` transition.
3. When no extension is deployed, the action call is a **silent no-op** — the transition proceeds normally.
4. When an extension **is** deployed, its handler runs inside a sandboxed VM (Node.js in debug, WebAssembly in production). Reading data is allowed only through the read-only projections. `req.reject(...)` vetoes the transition.

The extension code lives in a **separate project** (`xstravels-ext/`) that customers own. They pull the app's model, write their handler, and push the bundle to the tenant via the mtx sidecar. No code sharing, no re-deployment of the app, no source access.

## Step 1 — Enable multitenancy, extensibility, and the sandbox

In `xstravels/`:

```sh
cds add multitenancy
cds add extensibility
```

These two facets add `@sap/cds-mtxs`, create `mtx/sidecar/`, and set the `with-mtx-sidecar` profile in `package.json`. Then add the sandbox runtime — install `@sap/cds-oyster`:

```sh
npm i @sap/cds-oyster
```

Also install it in the sidecar so it can process extension pushes:

```sh
cd mtx/sidecar && npm i @sap/cds-oyster && cd ../..
```

Add the `code-extensibility` block to the `cds.requires` section of `xstravels/package.json`:

```jsonc
"cds": {
  "profile": "with-mtx-sidecar",
  "requires": {
    "[production]":   { "multitenancy": true },
    "[with-mtx]":     { "multitenancy": true },
    "extensibility":  true,
    "code-extensibility": {
      "runtime":   "oyster",
      "maxTime":   1000,
      "maxMemory": 4
    }
  }
}
```

Start the sidecar in a **separate terminal** — it must be up **before** the main app so the app can resolve the mtx bindings on boot:

```sh
# Terminal 1 — sidecar
cd xstravels
cds watch mtx/sidecar
# → listening on http://localhost:4005
```

Then in your existing terminal, start the main app with the mtx profile turned on:

```sh
# Terminal 2 — main app
cds watch --with-mtx
# → listening on http://localhost:4004, connected to sidecar
```

Finally, subscribe a tenant. This creates the tenant DB the extension will be pushed to:

```sh
# Terminal 3 — one-time tenant subscription
cds subscribe t1 --to http://localhost:4005
```

## Step 2 — Declare the extension service

The extension service is the **fence** that decides what an extension can see and do. Everything reachable from an `@kind: 'ext-service'` service is available to extension handlers; nothing else is.

Create `xstravels/srv/extension-service.cds`:

```cds
using { sap.capire.travels as db } from '../db/schema';

@kind: 'ext-service'
service TravelExtensionService {

  // Extension point: called BEFORE a travel transitions from Open to InReview.
  action validateReview(travelID: Integer, user: String, timestamp: String);

  // Read-only projections available to extension code via `this.entities`.
  @readonly entity Travels        as projection on db.Travels;
  @readonly entity Bookings       as projection on db.Bookings;
  @readonly entity TravelAgencies as projection on db.TravelAgencies;
}
```

Two things worth noting:

- **The action's payload is minimal** — just the travel ID plus who kicked off the review. The handler uses the read-only projections to look up whatever else it needs. Keeping the payload small keeps the API stable.
- **No handler for the action is registered here.** The framework treats an action on an `@kind: 'ext-service'` as an **extension point**: if there's no implementation, the call returns silently.

`cds watch` reloads. You should now see two services in the log — `TravelService` at `/odata/v4/travel` (still your main app) and `TravelExtensionService` at `/odata/v4/travel-extension` (the fence for extensions).

## Step 3 — Wire the extension point into `submitForReview`

Extend the existing `status_flows()` block in `xstravels/srv/travel-service.js` — actually, add a **new** method (keeping concerns separate). At the top of `init()`:

```javascript
async init() {
  this.generate_primary_keys()
  this.deduct_discounts()
  this.update_totals()
  this.status_flows()
  await this.extension_points()     // 👈 add this
  this.data_export()
  return super.init()
}
```

Then add the method itself:

```javascript
/**
 * Call the extension point before submitForReview transitions the status.
 * If no extension is deployed, the action returns silently and the transition
 * proceeds. If an extension is deployed and calls req.reject(...), the
 * transition is aborted.
 */
async extension_points() {

  const ext = await cds.connect.to('TravelExtensionService')
  const { Travels } = this.entities
  const { submitForReview } = Travels.actions

  this.before(submitForReview, Travels, async req => {
    await ext.validateReview({
      travelID:  req.params[0].ID,
      user:      req.user.id,
      timestamp: req.timestamp?.toISOString()
    })
  })
}
```

`cds watch` reloads. `submitForReview` still works exactly as before — the extension call is a no-op until we deploy one.

## Step 4 — Use the pre-built extension template

The workshop repo already contains a ready-to-use extension template at [`xstravels-ext/`](../xstravels-ext/). It's a **standalone project** (not part of the xstravels workspace) that a customer would fork or clone.

### What's inside the template

```
xstravels-ext/
├── .base/                          # compiled base model (shipped with template)
├── @cds-models/                    # generated types for IntelliSense
├── app/travels/webapp/             # Fiori Elements UI (copied from base app)
├── jsconfig.json                   # wires typed models into VS Code
├── package.json                    # extends "@capire/xstravels", "@sap/cds-oyster"
├── srv/
│   ├── server.js                   # READ-ONLY reference wiring — not part of the extension
│   ├── extension.cds               # add custom entities / model extensions here
│   └── TravelExtensionService/
│       └── on-validateReview.js    # your handler
├── test/
│   ├── requests.http               # HTTP tests
│   └── data/                       # seed CSVs (Travels, Bookings, Flights, ...)
└── README.md
```

Five files/folders are worth understanding:

- **`srv/server.js`** — a bootstrap that re-provides the extension-point wiring (`submitForReview → validateReview`) and the primary-key generation from the base app. That's what lets you `cds watch` the ext project **standalone** and see your handler fire — no mtx sidecar needed. At `cds push` time this file is ignored (only files inside `srv/<ServiceName>/` are packaged).
- **`test/data/`** — a copy of the seed CSVs from the base app, so the standalone `cds watch` has Travels/Bookings/Flights to work with.
- **`app/travels/webapp/`** — the Fiori Elements UI copied from the base app so you can browse and drive the extension from the browser at <http://localhost:4006/travels/webapp/index.html>. The UI annotations themselves already sit inside `.base/index.csn`, so only the HTML/JS shell needs to travel with the template. When the browser asks for credentials, use **`alice`** with an **empty password** (mocked auth).
- **`@cds-models/`** — TypeScript definitions generated by `@cap-js/cds-typer` from the current model. This drives VS Code auto-completion for `this.entities`, `req.data`, and CQL builders. Regenerate with `npm run typer` after editing `srv/extension.cds`.
- **`jsconfig.json`** — points VS Code at `@cds-models/` and `@cap-js/cds-types` so that IntelliSense wires up out of the box.

### How it was built (high-level — you don't need to redo this)

The extension template was bootstrapped once with roughly these steps:

1. `mkdir xstravels-ext && cd xstravels-ext` and create a minimal `package.json` with `extends: "@capire/xstravels"`, `workspaces: [".base"]`, and `@sap/cds-oyster` as a dependency.
2. With the sidecar running on 4005: `cds pull --from http://localhost:4005 -u bob:` populates `.base/index.csn` — a compiled snapshot of the app's model. This is what makes `using ... from '@capire/xstravels'` resolve inside the extension.
3. `npm install` — wires the `.base` workspace so the base model is on the module path.
4. Add handler stubs following the `srv/<ServiceName>/on-<action>.js` convention.
5. Copy seed CSVs from the base app into `test/data/`, add `db.data.folders` config in `package.json` to pick them up, and drop a `srv/server.js` bootstrap that reproduces the base app's wiring for standalone runs. Copy the base app's `app/travels/webapp/` too so the Fiori UI is reachable via `cds watch`.
6. Add `@cap-js/cds-typer` + `@cap-js/cds-types` as devDependencies, drop a `jsconfig.json` at the project root, and run `npm run typer` once to generate `@cds-models/` for IntelliSense.

### Boot the template (two options)

**A — standalone (fast local iteration, no mtx):**

```sh
cd xstravels-ext
npm install
cds watch          # → http://localhost:4006
```

`cds watch` reloads on every edit; no push cycle. This is what you'll use for the rest of this exercise.

**B — push to the tenant (production-like round-trip):**

```sh
cd xstravels-ext
npm install
cds push --to http://localhost:4005 -u bob:     # after each edit
```

The compiled base model (`.base/`) is shipped with the template — no `cds pull` step required.

> **Why `bob`?** In the default mocked-auth config, `bob` has the `cds.ExtensionDeveloper` role required by the sidecar's extensibility service.

## Step 5 — Write a real handler

We'll build the policy in two passes. First a simple total-price cap, then extend it with a per-booking cap so you see how easy it is to iterate on a live extension.

### 5.1 — Total-price cap

Open [xstravels-ext/srv/TravelExtensionService/on-validateReview.js](../xstravels-ext/srv/TravelExtensionService/on-validateReview.js). The stub is a no-op. Replace it with a check that rejects any travel whose total price exceeds 10 000:

```javascript
module.exports = async function validateReview(req) {
  const { travelID, user, timestamp } = req.data
  const { Travels } = this.entities

  const travel = await SELECT.one.from(Travels).where({ ID: travelID })
  if (travel?.TotalPrice > 10000) {
    req.reject(409, `Total price ${travel.TotalPrice} exceeds the 10000 policy limit — cannot submit for review.`)
  }
}
```

A few points worth noticing:

- `this.entities` gives you the read-only projections from the extension service — `Travels`, `Bookings`, `TravelAgencies`. Anything else in the app model is invisible.
- `req.data` holds the action parameters — the same `{ travelID, user, timestamp }` we send from `travel-service.js`.
- `req.reject(status, message)` produces a standard error response. From the client's point of view, this looks identical to a `@from`-violation error.
- The whole file is wrapped in `module.exports`. Anything you write at the module top level runs at *load* time — before `this` and `SELECT` are bound. Keep the logic inside the exported function.

### 5.2 — See it fire (standalone)

With option A's `cds watch` running, save the file. `cds watch` reloads. Two request files cover the same flow, use whichever is closer at hand:

- [`xstravels-ext/test/requests.http`](../xstravels-ext/test/requests.http) — lives inside the ext template.
- [`tests/05_sandbox_extensibility.http`](../tests/05_sandbox_extensibility.http) — the recap workshop's HTTP file (same layout as Ex3/Ex4), with an `@app` variable that lets you switch between the ext template's port `4006` and the sidecar-fronted app on `4004`.

Open one of them with the REST Client extension and send the requests:

1. Requests 1 & 2 list a cheap and an expensive open travel — copy their IDs.
2. Request 3 submits the cheap one → **succeeds** (handler returns silently, `@to` transition runs, Status flips to `P`).
3. Request 4 submits the expensive one → **fails with 409** and your policy message.

The 409 response:

```json
{
  "error": {
    "message": "Total price 12405 exceeds the 10000 policy limit — cannot submit for review.",
    "code": "409",
    "@Common.numericSeverity": 4
  }
}
```

Iterate freely — every save is picked up by `cds watch`. If you'd rather click through the flow, open the Fiori app at <http://localhost:4006/travels/webapp/index.html>, find an expensive travel, and hit the **Submit For Review** button — the policy message shows up as a message-strip on the object page.

### 5.3 — Extend the handler with a per-booking cap

A total-price cap is easy to game — split one expensive flight across two travels. A **per-booking cap** stops that: no single booking's `FlightPrice` may exceed 5 000. And while we're at it: an **empty travel** shouldn't reach review at all — there's nothing to look at. Extend the handler with both:

```javascript
module.exports = async function validateReview(req) {
  const { travelID, user, timestamp } = req.data
  const { Travels, Bookings } = this.entities

  // Rule 1: overall budget
  const travel = await SELECT.one.from(Travels).where({ ID: travelID })
  if (travel?.TotalPrice > 10000) {
    req.reject(409, `Total price ${travel.TotalPrice} exceeds the 10000 policy limit.`)
  }

  // Rule 2: must have at least one booking + per-booking cap
  const bookings = await SELECT.from(Bookings).where({ Travel_ID: travelID })
  if (!bookings.length) {
    req.reject(409, `Travel has no bookings — cannot submit for review.`)
  }
  if (bookings.some(b => b.FlightPrice > 5000)) {
    req.reject(409, `At least one booking exceeds the 5000 per-booking cap.`)
  }
}
```

Two things to notice about the second block:

- `!bookings.length` handles the empty case explicitly — a `for … of []` loop would silently skip it, so the check has to stand on its own.
- `bookings.some(...)` is enough here because we only want to know *whether* there's any offender, not which one. If you'd like to name the exact booking in the message, swap `some` for a `for … of` loop and reject inside it.

We tap the second projection (`Bookings`) with a filter on the FK — the ext service exposed both, so both are on `this.entities`. If you tried to reach an entity that *isn't* in `TravelExtensionService` (say `TravelStatus` texts), the query would fail — the fence you drew in [Step 2](#step-2--declare-the-extension-service) is what forbids it.

### 5.4 — Verify all three rules

Save the file and re-fire the tests. Three cases to walk through:

**Rule 2b (per-booking cap)** — pick a travel whose **total is under 10 000 but one of its bookings is > 5 000**. In the default seed data, Travel 660 is a good candidate — its single booking sits at 6 053 with a total of 6 096, so it clears rule 1 and gets caught by 2b. Since it's usually seeded as `Rejected`, reopen it first:

```http
### Reopen Travel 660 back to Open
POST http://localhost:4006/odata/v4/travel/Travels(ID=660,IsActiveEntity=true)/TravelService.reopenTravel
Authorization: Basic alice:
Content-Type: application/json

{}

### Submit — hits the per-booking rule
POST http://localhost:4006/odata/v4/travel/Travels(ID=660,IsActiveEntity=true)/TravelService.submitForReview
Authorization: Basic alice:
Content-Type: application/json

{}
```

You should see:

```json
{
  "error": {
    "message": "At least one booking exceeds the 5000 per-booking cap.",
    "code": "409",
    "@Common.numericSeverity": 4
  }
}
```

**Rule 1 (total-price cap)** — Travel 6 (USD, Total ≈ 12 405) trips this one independently.

**Rule 2a (no bookings)** — create a fresh travel in the Fiori UI without adding any bookings, activate the draft, then hit **Submit For Review**. You'll get `"Travel has no bookings — cannot submit for review."`

### 5.5 — Push to a real tenant

Once you're happy with the handler, run option B's push cycle:

```sh
cd xstravels-ext
cds push --to http://localhost:4005 -u bob:
```

The push command builds the extension (`gen/extension.tgz`), sends it to the sidecar, which activates it for the tenant. `cds watch` on the main xstravels app picks up the change automatically — no restart needed. Verify by re-running the same requests, but this time against the sidecar-fronted app on port 4004.

### 5.6 — Bonus: currency-aware limits

*Optional* — try this if you'd like to see how an extension can ship its **own data model** alongside its handler code.

The hard-coded `10000` / `5000` limits are fine for USD, but a European or Singaporean travel would need different caps. Rather than duplicating the handler per currency, let the extension **own a small policy table** and look up the right limit at runtime. The `@assert` constraint we added back in Exercise 3 already guarantees all bookings share the travel's currency, so a single row per currency is enough.

**Step 1 — extend [`xstravels-ext/srv/extension.cds`](../xstravels-ext/srv/extension.cds)** with the DB entity and its service-level projection:

```cds
using { TravelExtensionService } from '@capire/xstravels';

// Persistent table shipped with the extension. Deployed to the tenant DB
// on `cds push`; seeded from test/data/ during standalone `cds watch`.
namespace ext.policy;

entity CurrencyLimits {
  key Currency_code : String(3);
      MaxBooking    : Decimal(9,4);
      MaxTravel     : Decimal(9,4);
}

// Alias the DB entity so we can reference it below without a namespace lookup
// (CDS requires an explicit alias when the reference lives inside the same
// file that also declares the namespace).
using { ext.policy.CurrencyLimits as CurrencyLimitsDB };

// Read-only projection exposed on the extension service. Handlers see this
// via `this.entities`; OData clients cannot write to it.
extend service TravelExtensionService with {
  @readonly entity CurrencyLimits as projection on CurrencyLimitsDB;
}
```

Two parts, one file:

- The **entity in the `ext.policy` namespace** produces the actual table in the tenant DB — a plain top-level entity in CDS becomes persistence at `cds push` time.
- The **projection** exposes that table on the extension service, so it appears on `this.entities` for the handler. `@readonly` blocks OData writes; the handler itself still reads freely via `SELECT`.

**Step 2 — seed some data.** Add `xstravels-ext/test/data/ext.policy-CurrencyLimits.csv` — the filename matches the **DB entity's** fully-qualified name, not the projection:

```csv
Currency_code;MaxBooking;MaxTravel
USD;5000;10000
EUR;4500;9000
GBP;4000;8000
SGD;11000;14000
```

Standalone `cds watch` picks it up automatically via the `db.data.folders` config we saw in Step 4.

**Step 3 — consult the table from the handler.** Replace the hard-coded thresholds in `on-validateReview.js`:

```javascript
module.exports = async function validateReview(req) {
  const { travelID } = req.data
  const { Travels, Bookings, CurrencyLimits } = this.entities

  const travel = await SELECT.one.from(Travels).where({ ID: travelID })
  const limit  = await SELECT.one.from(CurrencyLimits).where({ Currency_code: travel?.Currency_code })
  if (!limit) return  // no policy defined for this currency → let it pass

  if (Number(travel.TotalPrice) > Number(limit.MaxTravel)) {
    req.reject(409, `Total ${travel.TotalPrice} exceeds MaxTravel ${limit.MaxTravel} for ${travel.Currency_code}`)
  }

  const bookings = await SELECT.from(Bookings).where({ Travel_ID: travelID })
  if (!bookings.length) {
    req.reject(409, `Travel has no bookings — cannot submit for review.`)
  }
  if (bookings.some(b => Number(b.FlightPrice) > Number(limit.MaxBooking))) {
    req.reject(409, `At least one booking exceeds MaxBooking ${limit.MaxBooking} for ${travel.Currency_code}`)
  }
}
```

Two things to notice:

- `CurrencyLimits` shows up on `this.entities` — it's exposed by the extension service, and the ext service is exactly the fence around what the handler can see.
- The `Number(...)` wrappers are not cosmetic. CDS returns `Decimal` values as **strings** — comparing them with `>` would fall back to lexical order, so `"858.8" > "10000"` would be `true`. Wrap both sides in `Number()` or the check silently returns wrong results.

**Step 4 — verify.** With `cds watch` still running:

- Travel 6 (USD, Total ≈ 12 405) → rejected against USD `MaxTravel` 10 000.
- Travel 13 (USD, Total ≈ 947) → passes.
- Travel 533 (SGD, Total ≈ 10 927) → **passes** despite being over 10 000 — because SGD `MaxTravel` is 14 000. This is the whole point of moving the caps into data.

The policy is now editable **without touching handler code**: change the CSV (or, in a deployed tenant, INSERT into `CurrencyLimits`), and the caps take effect on the next request.

## Step 6 — Iterate: `debug` vs `oyster` runtime

`code-extensibility.runtime` in the xstravels `package.json` can be either:

| Runtime | Where handlers run | `console.log` | Debugger |
|---------|--------------------|:---:|:---:|
| `oyster` | WebAssembly sandbox | rejected at push | no |
| `debug`  | Node.js `vm` in-process | printed to app log | yes (VS Code attach) |

Set it to `"debug"` during local iteration, then switch to `"oyster"` before you're done. The push command will reject `console` statements when the runtime is oyster — so you'll notice any leftover debug output immediately.

## Step 7 — What we skipped, and why

To keep this chapter tight, we didn't cover:

- **Custom entities in the extension** — add `entity MyPolicy { key ID: UUID; name: String; }` to `srv/extension.cds` and it'll be deployed to the tenant DB on push. Handy for storing policy data alongside the handler.
- **`@extensible.code`** — the fine-grained annotation that opens *specific* entities in the main service for CRUD-hook extensions (e.g. `after-READ` on `TravelService.Travels`). We stayed inside the ext-service fence, which is cleaner for a first extension.
- **Draft draft support, i18n, testing, `cds push` in CI** — all in the full workshop.

## Summary

- An **extension point** is an action on an `@kind: 'ext-service'` service, called from your main app's business logic. No implementation ⇒ silent no-op.
- Extension code lives in a **separate project** with a copy of your app's model (`.base/`) and runs in a sandbox. It can only see what the ext service projects.
- The `cds push` workflow bundles the handler + model and activates it on the tenant, mediated by the mtx sidecar. (`cds pull` refreshes the local base model when the app's model changes — this template ships with `.base/` prebuilt, so you don't need to run it.)
- **Design tip**: pass keys and identity in the action payload, keep data lookups in the handler. This keeps the ext-service contract minimal and forward-compatible.

Continue to - [Exercise 6 - CDS REPL](06_CDS_REPL.md)
