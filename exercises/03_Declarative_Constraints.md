# Exercise 3 - Declarative Constraints

In this exercise, you will learn how to add **declarative validation constraints** to your CDS model using the `@assert` annotation. Instead of writing custom code in service handlers to reject invalid input, you annotate your model with an expression — and CAP takes care of the rest.

## Prerequisites

Make sure you have completed [Exercise 2 - Explore and Run the App](02_Explore_and_Run.md).

## What is `@assert`?

`@assert` is a CDS annotation you attach to any element (field or association) of an entity. Its value is a **CDS expression** — typically a `case`-statement — that returns either `null` (no error) or an error **message key**. When the framework processes a write (`CREATE`, `UPDATE`, `PATCH`, or a nested composition write), it evaluates the expression:

- If it returns `null`, the write proceeds.
- If it returns a string, the write is rejected with a `400 Bad Request` and the returned string is either shown as the error message, or looked up in `i18n/messages*.properties` for translation.

The big advantages over hand-written handlers:

- **Declarative**: your model becomes the single source of truth for what "valid" means.
- **Runs at every write path**: OData, REST, drafts, deep-insert compositions, service-to-service calls — all consistent.
- **Translatable**: return a key like `ASSERT_BOOKING_FEE_NON_NEGATIVE` and CAP resolves it against `_i18n/messages_*.properties`.
- **Referential**: expressions can navigate associations (`$self.Travel.EndDate`) and check `exists`-style constraints in the database.

## Step 1 — Explore the constraints in the code

The constraints live in one file:

[xstravels/srv/travel-constraints.cds](../xstravels/srv/travel-constraints.cds)

Open it and take a look at the different patterns used. Rather than walking through every constraint (there are quite a few, and several are variations on the same idea), we've picked six that between them cover every pattern in the file.

### On `Travels`

| Field         | Pattern demonstrated                                                             | Message                                                     |
|---------------|----------------------------------------------------------------------------------|-------------------------------------------------------------|
| `Description` | Null check + string function (`length` / `trim`)                                 | `Description is required` / `Description is too short`      |
| `Agency`      | `@mandatory` shorthand **+** referential-integrity check via `not exists <assoc>` | `ASSERT_MANDATORY` / `Agency does not exist`                |
| `BeginDate`   | Cross-field compare (`EndDate < BeginDate`) **+** *filtered* `exists` from a parent into its to-many children | `ASSERT_BEGINDATE_BEFORE_ENDDATE` / `ASSERT_BOOKINGS_IN_TRAVEL_PERIOD` |

### On `Bookings`

| Field                | Pattern demonstrated                                                             | Message                                                |
|----------------------|----------------------------------------------------------------------------------|--------------------------------------------------------|
| `Flight.date`        | `$self` navigating *from a child up to its parent* + `not between` range check   | `ASSERT_BOOKING_IN_TRAVEL_PERIOD`                      |
| `Currency`           | Cross-entity equality — the child's value must match the parent's                | `ASSERT_BOOKING_CURRENCY_MATCHES_TRAVEL`               |
| `BookingDate`        | Constraint declared on a child but really fires when the *parent* is edited — see the draft-flow note below | `ASSERT_NO_BOOKINGS_AFTER_TRAVEL`                      |


### Patterns worth noticing

- **`case … end`** — follows the standard SQL/CQL syntax: can have multiple branches, success requires all of them falling through to `null`.
- **`@mandatory`** — a shorthand that plugs into the same framework and rejects `null` values with the built-in `ASSERT_MANDATORY` key.
- **`exists <assoc>`** — a lightweight referential-integrity check. `not exists Agency` means "no matching TravelAgency row for the given `Agency_ID`".
- **`$self`** — refers to the current row. Handy for looking up a parent-side value from a child (see `$self.Travel.BeginDate` in the `Bookings.Flight.date` constraint).
- **`exists Bookings [Flight.date < Travel.BeginDate]`** — a *filtered exists* on a to-many composition. Preferred over naive de-normalization (`Bookings.Flight.date < BeginDate`) because it does not duplicate error messages per row.
- **Message keys vs literals** — you can return either a literal message string (like `'Description is required'`) or a key such as `'ASSERT_BOOKING_FEE_NON_NEGATIVE'`. Keys get looked up in `app/_i18n/messages*.properties` and translated based on the caller's locale.
- **Draft-time validation** — for Fiori draft-enabled entities (like `Travels`), the framework evaluates constraints on *every* PATCH inside the draft **and** again at `draftActivate`. That's why the last request in the HTTP file — which shrinks a Travel's `EndDate` earlier than an existing booking's `BookingDate` — trips `ASSERT_NO_BOOKINGS_AFTER_TRAVEL` on activate, together with the sibling constraints affected by the same edit.

Have a quick look at [xstravels/app/\_i18n/messages_en.properties](../xstravels/app/_i18n/messages_en.properties) and [messages_de.properties](../xstravels/app/_i18n/messages_de.properties) to see how the same key resolves to English and German text.

## Step 2 — See constraints fire against a running app

Before running the tests, make sure the seed data is anchored to today so realistic dates are available:

```bash
cd xstravels
npm run update-dates
cds watch
```

This rewrites the CSV data files in place (local-only — don't commit) so that flights, travels and bookings sit in a ±60/+90-day window around today.

### Option A — Run the HTTP requests

The file [tests/03_declarative_constraints.http](../tests/03_declarative_constraints.http) contains one **success** and one **failure** request per pattern from the table above — six pairs, not eleven. Each block starts with a comment stating what it exercises and what error is expected.

1. Install the [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension in VS Code.
2. Open `tests/03_declarative_constraints.http`.
3. First run the three **Helpers** requests at the top of the file — they list a few Travels and Flights so you can pick real IDs and dates. If your rolling window has drifted from the sample dates in the file, adjust `BeginDate` / `EndDate` / `Flight_ID` / `Flight_date` accordingly.
4. Click **Send Request** above each block.

Every failing request returns a `400 Bad Request` with a JSON body like:

```json
{
  "error": {
    "message": "Description is too short",
    "code": "400",
    "target": "Description",
    "@Common.numericSeverity": 4
  }
}
```

When more than one constraint is violated by the same write, the framework groups them under `MULTIPLE_ERRORS` with a `details` array — one entry per violated field. Try the "BeginDate after EndDate" request to see both `ASSERT_BEGINDATE_BEFORE_ENDDATE` and `ASSERT_ENDDATE_AFTER_BEGINDATE` reported at once.

### Option B — Try it in the Fiori UI

Open http://localhost:4004 and navigate to the **Travels** app.

- Click **Create** and try to save a travel with a blank Description, an empty Agency, or an EndDate that lies before BeginDate — the constraints show up as **field-level messages** next to the offending inputs.
- Open an existing travel, click **Edit** to enter draft mode, and edit one of its bookings — try changing the booking's currency to `EUR` while the travel is in `USD`, or setting a `Flight_date` outside the travel window. On **Save**, the same constraint messages appear at the top of the object page.

Because `@assert` fires on every write path, the Fiori UI, direct HTTP, and any programmatic client all get the same validation — with no extra handler code.

## Step 3 — Add your own constraint

Time to add a real business rule. We'll implement:

> **A customer cannot have two travels whose periods overlap.**

This example builds on the patterns from Step 1 and adds two new twists worth calling out:

- **Back-navigation from an association** — from a `Travels` row we reach the same customer's *other* Travels via `Customer.Travels`, then filter with a multi-condition predicate.
- **A self-exclusion clause** (`ID != $self.ID`) — without it, updating any existing travel would find itself as an overlap and fail.

Plus you'll add an i18n key and see raw-vs-translated messages.

### 3.1 Extend the `Customer` constraint

Open [xstravels/srv/travel-constraints.cds](../xstravels/srv/travel-constraints.cds) and extend the existing `Customer @assert:` block with a third `when` branch. Note that we're **merging into the existing annotation**, not adding a second one — CDS otherwise warns *"Assignment for `@assert` is overwritten by another one below"* and only the last one wins.

> ⚠️ **Heads-up:** re-annotating the same field or entity with `@assert` (in a separate `annotate` block or via `extend`) does **not** merge the checks — the new expression **replaces** the previous one wholesale, and the earlier branches are silently dropped. Always merge new `when`-branches into the existing `case … end`.

```cds
Customer @assert: (case
  when Customer is null then 'Customer must be specified'
  when not exists Customer then 'Customer does not exist'
  when exists Customer.Travels [
         ID != $self.ID
     and BeginDate <= $self.EndDate
     and EndDate   >= $self.BeginDate
  ] then 'ASSERT_NO_OVERLAPPING_TRAVELS_PER_CUSTOMER'
end);
```

**How the overlap check works** — two intervals `[a1, a2]` and `[b1, b2]` overlap **iff** `a1 <= b2 AND a2 >= b1`. Here the current row plays the role of interval `A` (`$self.BeginDate` .. `$self.EndDate`) and every sibling travel plays the role of interval `B` (`BeginDate` .. `EndDate` inside the filter). The condition returns `true` for any sibling whose period touches ours — and `exists [...]` reduces that to a single boolean.

**Why the self-exclusion?** Without `ID != $self.ID`, an UPDATE to any existing travel would find itself as the "other" row (same customer, same dates) and always fail. `$self.ID` is `null` on a fresh CREATE, so the clause is always true then — creates aren't affected.

**A note on inclusive boundaries** — as written, the check treats a **same-day handoff** as overlap: if trip A ends on the 8th and trip B starts on the 8th, that trips the constraint. To allow contiguous back-to-back trips, use strict comparisons: `BeginDate < $self.EndDate and EndDate > $self.BeginDate`.

Save the file and `cds watch` reloads automatically.

### 3.2 See it fire — raw message first

Send this request against a customer that already has a travel in the seed data. (Run the *Helpers → List a couple of Travels* request first to find a customer + a period that collides with an existing one; customer `000001` is a safe bet.)

```http
POST http://localhost:4004/odata/v4/travel/Travels
Content-Type: application/json
Authorization: Basic alice:

{
  "Description":  "Overlap trip",
  "BeginDate":    "<some date inside an existing travel of this customer>",
  "EndDate":      "<some date inside the same existing travel>",
  "Currency_code":"USD",
  "Agency_ID":    "070001",
  "Customer_ID":  "000001"
}
```

You should get back:

```json
{
  "error": {
    "message": "ASSERT_NO_OVERLAPPING_TRAVELS_PER_CUSTOMER",
    "code": "400",
    "target": "Customer_ID",
    "@Common.numericSeverity": 4
  }
}
```

Notice the `message` is the **raw key** — no i18n entry for it exists yet, so CAP falls back to returning the literal string.

### 3.3 Add the i18n entry

Append these lines to [xstravels/app/\_i18n/messages_en.properties](../xstravels/app/_i18n/messages_en.properties) (and the German/French variants if you like):

```properties
ASSERT_NO_OVERLAPPING_TRAVELS_PER_CUSTOMER=This customer already has another travel in the same period
```

Send the same failing POST again — this time the `message` is the human-readable text; `code` still carries the key so client code can react programmatically:

```json
{
  "error": {
    "message": "This customer already has another travel in the same period",
    "code": "ASSERT_NO_OVERLAPPING_TRAVELS_PER_CUSTOMER",
    "target": "Customer_ID",
    "@Common.numericSeverity": 4
  }
}
```

### 3.4 Verify the constraint does not misfire on self-updates

Prove the `ID != $self.ID` clause pulls its weight — edit an *existing* travel of the same customer without touching its dates, and confirm the write goes through. Using the draft flow shown in the HTTP file:

```http
### Put existing Travel 550 (Customer 000001) into edit mode
POST http://localhost:4004/odata/v4/travel/Travels(ID=550,IsActiveEntity=true)/TravelService.draftEdit
Authorization: Basic alice:
Content-Type: application/json

{ "PreserveChanges": true }

### Change Description only, activate the draft
PATCH http://localhost:4004/odata/v4/travel/Travels(ID=550,IsActiveEntity=false)
Authorization: Basic alice:
Content-Type: application/json

{ "Description": "renamed" }

POST http://localhost:4004/odata/v4/travel/Travels(ID=550,IsActiveEntity=false)/TravelService.draftActivate
Authorization: Basic alice:
Content-Type: application/json

{}
```

The activate returns `200` — the row is not treated as its own overlap.

### 3.5 Extension ideas

If you have time left, try adding one of these on your own:

- **Same-agency lock**: forbid moving a travel to a different agency once it has bookings (`when exists Bookings and Agency_ID != <previous value>` — hint: use a `before UPDATE` handler if you need the *old* value; declarative constraints only see the *new* one).
- **BookingFee cap** relative to the total price: `when BookingFee > TotalPrice * 0.5` — a Business rule saying the fee can't exceed 50 % of the trip.
- **Localize** the new key to `messages_de.properties` and switch the browser locale via `?sap-language=de` to see the German error text.

## Summary

- `@assert` lets you declare validation rules **directly in the CDS model** — a `case`-expression that returns `null` (valid) or a message (or i18n key).
- Constraints fire on every write path: OData, drafts, deep-inserts, direct handler calls — no extra handler code needed.
- A handful of patterns — null/length checks, `not exists`, cross-field compares, `$self`, filtered `exists` — cover most real-world validation.

Continue to - [Exercise 4 - Status Flows](04_Status_Flows.md)
