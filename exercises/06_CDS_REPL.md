# Exercise 6 - CDS REPL

In this exercise, you will learn how to use the **CDS REPL** — an interactive Node.js shell that boots your CAP application in-process. From the prompt you can query the database, invoke services, and evaluate CQL directly, without running `cds watch` and issuing HTTP requests.

## Prerequisites

Make sure you have completed [Exercise 5 - Sandbox Extensibility](05_Sandbox_Extensibility.md).

## What is the CDS REPL?

The CDS REPL is a Read-Eval-Print Loop built on top of Node's standard REPL, launched via `cds repl`. When started with the `--run <project>` option, it loads the given CAP application, deploys the schema to an in-memory database, and puts the resulting services on the global scope. `cds`, `SELECT`, `INSERT`, `UPDATE`, and `DELETE` are pre-imported.

### Advantages over `cds watch` + HTTP

- **Direct database access**: `db.read(...)` returns raw rows without going through the OData layer.
- **Service-level calls**: `TravelService.read(...)` runs the same `before`/`on`/`after` handlers a REST client would trigger, but without HTTP or JSON.
- **Native CQL**: `.ql` mode accepts CQL statements verbatim — the same syntax used in `.cds` files.
- **State preservation**: intermediate values remain bound in the REPL session, so a query can be refined and re-run without restarting.

## Step 1 — Start a REPL against xstravels

From `xstravels/`:

```sh
cds repl --run .
```

After the usual boot messages (schema deployed, both services served), you'll see the REPL's global-context summary and the `>` prompt:

```
------------------------------------------------------------------------
Following variables are made available in your repl's global context:

from cds.services: {
  db,
  scheduling,
  TravelExtensionService,
  TravelService,
}

Simply type e.g. TravelService in the prompt to use the respective objects.
>
```

Two things worth noting:

- **`--run .`** boots the CAP server from the current directory. Without it, `cds repl` opens without an application loaded — useful for pure JavaScript experiments, not for querying data.
- The globals include the two application services (`TravelService`, `TravelExtensionService`) and the database service (`db`). Entities are not on the global scope directly — they live under each service and need to be destructured.

## Step 2 — Explore the model

Type `.help` to see the REPL commands available in a CAP session:

```
> .help
.break     Sometimes you get stuck, this gets you out
.clear     Alias for .break
.exit      Exit the REPL
.help      Print this help message
.inspect   Sets options for util.inspect, e.g. `.inspect .depth=1`.
.load      Load JS from a file into the REPL session
.ql        Switch to cql repl mode, evaluating cql queries
.run       Runs a cds server from a given CAP project folder, or module name like @capire/bookshop.
.save      Save all evaluated commands in this REPL session to a file
```

`.ql`, `.run`, and `.inspect` are the CAP-specific additions on top of Node's standard REPL commands.

Use `.inspect` to browse any object with adjustable depth:

```
> .inspect .depth=1 TravelService.entities
```

The output lists the entities exposed on the service — `Travels`, `Bookings`, `TravelStatus`, `Currencies`, and so on.

Destructure the entities you'll need for the following steps:

```
> const { Travels, Bookings, TravelStatus } = TravelService.entities
```

## Step 3 — Run queries

### CQL via `cds.ql` template literal

```
> await cds.ql`SELECT from ${Travels} { ID, Description, Status_code } limit 3`
[
  { ID: 1, Description: 'Business Trip for Christine, Pierre', Status_code: 'O' },
  { ID: 2, Description: 'Vacation', Status_code: 'O' },
  { ID: 3, Description: 'Vacation', Status_code: 'O' }
]
```

### Builder-style SELECT

The same query written as a JavaScript builder:

```
> await SELECT.from(Travels).columns('ID','Description','Status_code').limit(3)
```

Filtered:

```
> await SELECT.from(Travels).where({ Status_code: 'O' }).columns('ID','TotalPrice').limit(5)
```

Aggregated:

```
> await SELECT.one`count(*) as total`.from(Travels).where({ Status_code: 'O' })
{ total: 2469 }
```

### CRUD-style on a service

To trigger the full handler chain — the same code path an HTTP request follows — go through the service:

```
> await TravelService.read(Travels).where({ ID: 100 })
> await TravelService.read(Travels).columns('ID','TotalPrice','Currency_code').where({ Currency_code: 'SGD' }).limit(3)
```

The service-level read applies `@readonly` projections, `@restrict` rules, and every registered handler. `db.read(...)` skips all of that and queries the SQL table directly.

## Step 4 — CQL mode

For pure query work, switch to CQL mode with `.ql`. The prompt changes to `cql>` and accepts CQL statements without any JavaScript wrapping:

```
> .ql
cql> select from TravelService.Travels { count(*) as total, Currency_code } group by Currency_code order by total desc
[
  { total: 1577, Currency_code: 'EUR' },
  { total: 1202, Currency_code: 'USD' },
  { total: 745, Currency_code: 'SGD' },
  { total: 609, Currency_code: 'JPY' }
]
```

In CQL mode, entities must be referenced by their **fully qualified** service path (`TravelService.Travels`) — the local JavaScript bindings from Step 2 are not visible.

Switch back to JavaScript mode with `.js`:

```
cql> .js
>
```

## Step 5 — Call an action

Actions declared on a service are exposed as methods on the service object. Unbound actions take the parameters as their only argument; bound actions take the target entity, the key, and then the parameters.

**Unbound-style call** — passing the key inside the payload:

```
> await TravelService.submitForReview({ ID: 13 })
```

If the travel is Open and passes all constraints, the call returns silently and the row transitions to InReview. Otherwise the error is thrown and can be caught:

```
> try { await TravelService.submitForReview({ ID: 2 }) } catch (e) { console.log(e.code, e.message) }
```

**Bound-style call** — target, key, payload:

```
> await TravelService.deductDiscount(Travels, { ID: 13 }, { percent: 10 })
```

> **Note**: `deductDiscount` is restricted to the `reviewer` role (see `srv/travel-access-control.cds`). The REPL runs unauthenticated by default, so this call returns HTTP 401. `submitForReview` has no role restriction and works as shown above.

## Step 6 — Inspect a query before executing it

Every builder expression is a plain JavaScript object with the parsed CQN attached. To see what the CDS engine will send to the database, dump the `.SELECT` property before the query is awaited:

```
> q = SELECT.from(Travels).where`Status_code='O' and TotalPrice > 10000`
> q.SELECT                  // parsed CQN — from clause, where predicate, columns
> await q                   // execute the same query
```

Intermediate values remain in scope, so subsequent queries can build on previous ones without re-fetching:

```
> b = await SELECT.one.from(Bookings).where({ Travel_ID: 100, Pos: 2 })
> await SELECT.one.from(Travels).where({ ID: b.Travel_ID })
```

## Step 7 — Save the session

`.save` writes the current REPL session's command history to a file:

```
> .save /tmp/xstravels-repl-session.js
```

The resulting `.js` file can be replayed with `.load`, turned into a test case, or shared with a colleague.

## Summary

- `cds repl --run .` boots the application and drops you into a Node REPL with services on the global scope.
- Destructure entities from a service before querying: `const { Travels } = TravelService.entities`.
- Queries can be written three ways: `cds.ql` template literals, `SELECT.from(...)` builder, or CQL mode (`.ql`).
- Actions are called directly as methods on the service — unbound with a single payload argument, bound with `(target, key, payload)`.
- `.inspect` browses object structure, `q.SELECT` dumps the parsed CQN of a query, `.save` exports the session as `.js`.

Continue to - [Exercise 7 - HCQL](07_HCQL.md)
