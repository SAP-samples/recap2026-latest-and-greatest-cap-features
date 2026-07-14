# xstravels-ext — Extension Template

An extension template for [`@capire/xstravels`](../xstravels/). Implement the
`validateReview` extension point to add your own policy checks that fire when
a travel is submitted for review.

## Two ways to run

### A) Standalone (fast local iteration)

Boot the ext project on its own — no mtx sidecar needed. `srv/server.js`
provides just enough reference code (extension-point wiring + primary-key
generation) to make `submitForReview` fire `validateReview`, and the seed
CSVs in `test/data/` give you real Travels/Bookings/Flights to work with.

```sh
npm install
cds watch          # → http://localhost:4006
```

Edit `srv/TravelExtensionService/on-validateReview.js`, save, `cds watch`
reloads, run `test/requests.http` — or open the Fiori app at
<http://localhost:4006/travels/webapp/index.html> to try things through the UI.

### B) Push to a real tenant (via mtx sidecar)

The setup you'd use once you're happy with the handler.

```sh
# Assumes xstravels/ has multitenancy + sandbox enabled and both the sidecar
# (port 4005) and the main app (port 4004) are running. Tenant t1 subscribed
# via: `cds subscribe t1 --to http://localhost:4005 -u yves:`

npm install
cds push --to http://localhost:4005 -u bob:     # after each edit
```

> **Different users per call**: `cds subscribe/unsubscribe` needs **yves**
> (has `internal-user`); `cds pull/push` needs **bob** (has
> `cds.ExtensionDeveloper`); everyday HTTP tests against the running app use
> **alice** (admin). All three log in with an empty password.

The base model (`.base/`) is shipped with this template — no `cds pull` step required.

## Extension Point

| Action | Fires when | Parameters |
|--------|------------|------------|
| `validateReview` | Before a travel transitions Open → InReview (`submitForReview`) | `travelID: Integer`, `user: String`, `timestamp: String` |

Return silently to allow the transition; call `req.reject(409, "…")` to veto.

## Entity Access

Your handler can read via `this.entities`:

- `Travels` — travel records (look up the current row by `travelID`)
- `Bookings` — booking rows
- `TravelAgencies` — agency master data

All are read-only projections in `TravelExtensionService`.

## Project Layout

```
xstravels-ext/
├── .base/                          # compiled base model (shipped with template)
├── @cds-models/                    # generated types (from `npm run typer`)
├── app/travels/webapp/             # Fiori Elements UI (copied from base app)
├── jsconfig.json                   # wires IntelliSense to @cds-models
├── package.json                    # extends "@capire/xstravels"
├── srv/
│   ├── server.js                   # READ-ONLY reference wiring (not pushed)
│   ├── extension.cds               # add custom entities / model extensions here
│   └── TravelExtensionService/
│       └── on-validateReview.js    # your handler
└── test/
    ├── requests.http               # HTTP tests
    └── data/                       # seed CSVs (not pushed)
```

Handler file naming follows `srv/<ServiceName>/<when>-<WHAT>.js` — e.g.
`srv/TravelExtensionService/on-validateReview.js` for an action handler.

## IntelliSense

The project ships with typed models under `@cds-models/` and a `jsconfig.json`
that lets VS Code auto-complete `this.entities`, `req.data`, and CQL builders.
If you edit `srv/extension.cds`, regenerate the types:

```sh
npm run typer
```

## Debugging locally

The extension runs inside a sandboxed VM even during standalone `cds watch`.
The runtime is set to `"debug"` in `package.json` (`cds.requires.code-extensibility.runtime`)
— that means the handler executes in a Node.js `vm` context in the same
process as the server, so `console.log` prints to the `cds watch` terminal
and the VS Code debugger can attach to it.

### Console logs

`console.log(...)` in `on-validateReview.js` appears in the terminal running
`cds watch`. Handy for a quick "did we even get here" check. Remove before
switching to the `oyster` runtime — `cds push` rejects handlers that call
`console.*` when the runtime is `oyster`.

### Breakpoints in VS Code

1. Start `cds watch` with the Node inspector enabled:

   ```sh
   NODE_OPTIONS=--inspect cds watch
   ```

   You'll see a line like `Debugger listening on ws://127.0.0.1:9229/...` in
   addition to the usual boot log.

2. In VS Code, run **Debug: Attach to Node Process** (Cmd/Ctrl+Shift+P) and
   pick the `cds` process. VS Code shows a small orange bar at the bottom
   once attached.

3. Open [`srv/TravelExtensionService/on-validateReview.js`](srv/TravelExtensionService/on-validateReview.js)
   and set breakpoints on:

   - the first line of the exported function — to see the incoming request
   - the line after `const travel = await SELECT.one...` — to see what came
     back from the DB
   - inside the `bookings.some(...)` check — to inspect each row before the
     policy fires

4. Fire request 3 or 4 from [`test/requests.http`](test/requests.http). The
   handler pauses at the first breakpoint.

5. In the **Variables** pane, explore:

   | Value | What you'll see |
   |---|---|
   | `req.data` | `{ travelID: 100, user: 'alice', timestamp: '2026-…' }` — the action's inputs. |
   | `req.user` | The mocked user record — `id`, `roles`, `tenant`. |
   | `this.entities` | `{ Travels, Bookings, TravelAgencies }` — the read-only projections from `TravelExtensionService`. Nothing else is reachable, by design. |
   | `travel` (after `await SELECT.one`) | The full Travels row — `TotalPrice`, `Status_code`, `BookingFee`, etc. Confirms the query hit the right row. |
   | `bookings` (after `await SELECT.from`) | An array of Booking rows. Each has `Pos`, `Flight_ID`, `FlightPrice`, `Currency_code`, `BookingDate`. Empty array ⇒ our "no bookings" rule fires. |

6. Step through with **F10** (over) / **F11** (into). Watch `req.reject`
   being invoked — the response the client sees is built right here.

### Watching the wire

The server prints one line per OData request. If a handler seems not to
fire, check the log for the `POST .../submitForReview` entry — if it's
missing, the flow rejected the transition before your handler was reached
(typically an `INVALID_FLOW_TRANSITION_SINGLE` from `@from`).
