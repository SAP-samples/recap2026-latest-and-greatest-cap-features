 # Exercise 7 - HCQL

 In this exercise, you will enable the HCQL (CQL over HTTP) protocol adapter on your travel service and use it to run powerful queries directly against your CAP service.

 ## Prerequisites

 Make sure you have completed [Exercise 6 - CDS REPL](06_CDS_REPL.md).

 ## What is HCQL?

 HCQL stands for **CQL over HTTP**. It exposes your CAP services via an HTTP endpoint that accepts CQL queries — either as CQN (JSON) or as plain CQL text (Node.js only). Compared to OData, REST, or GraphQL, CQL is the most native query language to CAP and thus the most efficient and feature-rich option for CAP-to-CAP service integrations and data federation scenarios.

 ## Steps

 ### 1. Enable HCQL on the Travel Service

 Create a new file `srv/travel-hcql.cds` with the following content:

 ```cds
 using { TravelService } from './travel-service';

 annotate TravelService with @hcql;
 ```

 ### 2. Restart the server

 If `cds watch` is running, it will pick up the change automatically. Otherwise start it:

 ```bash
 cds watch
 ```

 You should see the HCQL endpoint listed in the console output:

 ```
 [cds] - serving TravelService {
   at: [ '/hcql/travel' ],
   ...
 }
 ```

 > **Note:** Adding `@hcql` explicitly makes it the served protocol. The OData endpoint (`/odata/v4/travel`) is replaced by the HCQL endpoint. The Fiori UI will still work because it is served as a static app.

 ### 3. Query with CQL text (plain text body)

 Open a new terminal and send a CQL query as plain text:

 ```bash
 curl -X POST http://localhost:4004/hcql/travel \
   -H "Content-Type: text/plain" \
   -u alice: \
   -d 'SELECT from Travels { ID, Description, BeginDate, EndDate, TotalPrice, Currency.code as Currency }'
 ```

 > **Note:** We use `-u alice:` for mock authentication. In development mode, CAP uses mocked users by default.

 You should receive a JSON response with travel records containing just the selected fields.

 ### 4. Query with CQN JSON body

 Now try the same query using the CQN JSON notation:

 ```bash
 curl -X POST http://localhost:4004/hcql/travel \
   -H "Content-Type: application/json" \
   -u alice: \
   -d '{
     "SELECT": {
       "from": { "ref": ["Travels"] },
       "columns": [
         { "ref": ["ID"] },
         { "ref": ["Description"] },
         { "ref": ["BeginDate"] },
         { "ref": ["EndDate"] },
         { "ref": ["TotalPrice"] },
         { "ref": ["Currency", "code"], "as": "Currency" }
       ],
       "limit": { "rows": { "val": 5 } }
     }
   }'
 ```

 The result is the same — CQN JSON is the cross-runtime format that works on both CAP Node.js and CAP Java.

 ### 5. Use expands to query nested data

 One of HCQL's strengths is native support for deep reads with expands. Query travels with their bookings:

 ```bash
 curl -X POST http://localhost:4004/hcql/travel \
   -H "Content-Type: text/plain" \
   -u alice: \
   -d 'SELECT from Travels {
     ID, Description, Status.name as Status,
     Bookings {
       Pos, Flight.date as FlightDate,
       Flight.airline as Airline,
       FlightPrice, Currency.code as Currency
     }
   } limit 2'
 ```

 You should see travels with their nested bookings, including flight details resolved through associations.

 ### 6. Add filtering and ordering

 Query only open travels, sorted by begin date:

 ```bash
 curl -X POST http://localhost:4004/hcql/travel \
   -H "Content-Type: text/plain" \
   -u alice: \
   -d "SELECT from Travels {
     ID, Description, BeginDate, TotalPrice
   } where Status.code = 'O' order by BeginDate desc limit 5"
 ```

 ### 7. Use HCQL from a CAP client (bonus)

 When connecting to a remote CAP service that exposes `@hcql`, CAP automatically prefers HCQL over OData. This is the foundation for data federation:

 ```js
 const TravelService = await cds.connect.to('TravelService')
 const travels = await TravelService.read`Travels {
   ID, Description, Bookings { Pos, FlightPrice }
 }`
 ```

 > This works seamlessly in federated scenarios where services communicate across process boundaries.

 ## Summary

 You have learned how to:
 - Enable HCQL on a CAP service with the `@hcql` annotation
 - Send CQL queries as plain text (`text/plain`) — Node.js only
 - Send CQN queries as JSON (`application/json`) — cross-runtime
 - Use expands, filtering, and ordering via HCQL
 - Understand why HCQL is the preferred protocol for CAP-to-CAP integration

 Continue to - [Exercise 8 - AI Plugin](08_AI_Plugin.md)
