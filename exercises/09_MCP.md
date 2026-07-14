 # Exercise 9 - MCP

 In this exercise, you will expose your CAP Travel Service as an MCP (Model Context Protocol) server, allowing AI agents to interact with your travel data through natural language.

 
 ## What is MCP?

 The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) is an open-source standard that enables direct integration between LLM applications and external data sources. From a CAP developer's perspective, `@mcp` is just another protocol — similar to `@odata`, `@graphql`, `@rest`, or `@hcql`. The adapter takes care of the rest, and all standard CAP features work out of the box.

 The [`@cap-js/mcp`](https://github.com/cap-js/mcp) plugin creates an MCP server for each annotated service, exposing tools that AI agents can use to:
 - **describe** — Explore entities, elements, actions, and their documentation
 - **query** — Read data using CQL-style queries with filtering, sorting, grouping
 - **call_action** — Invoke unbound actions and functions

 ## Steps

 ### 1. Install the MCP plugin

 In your terminal (inside the `xstravels` directory):

 ```bash
 npm add @cap-js/mcp
 ```

 ### 2. Annotate the Travel Service with @mcp

 Create a new file `srv/travel-mcp.cds`:

 ```cds
 using { TravelService } from './travel-service';

 annotate TravelService with @mcp
   @mcp.instructions: 'This service manages travel bookings. Use describe to explore available entities like Travels, Bookings, Customers, and Flights. Use query to search travels by status, date range, or agency.';
 ```

 ### 3. Start the server

 ```bash
 cds watch
 ```

 Observe the console output — you should see the MCP endpoint listed:

 ```
 [cds] - serving TravelService {
   at: [ '/odata/v4/travel', '/hcql/travel', '/mcp/travel' ],
   ...
 }
 ```

 ### 4. Explore with the MCP Inspector

 The MCP Inspector is a web-based tool to explore and test your MCP server — no LLM required.

 In a **new terminal**, run:

 ```bash
 npx @modelcontextprotocol/inspector
 ```

 This opens a browser window. Configure it:

 1. Select **Streamable HTTP** as Transport Type
 2. Enter the URL: `http://localhost:4004/mcp/travel`
 3. Add an Authorization header: `Basic YWxpY2U6` (this is `alice:` base64-encoded)
 4. Select **Via Proxy** and click **Connect**

 ### 5. Discover the data model

 In the Inspector:

 1. Go to the **Tools** tab and click **List Tools**
 2. You should see three tools: `describe`, `query`, and `call_action`
 3. Select the **describe** tool and click **Run Tool**

 The response shows all entities (Travels, Bookings, Customers, Flights, etc.) with their fields, types, and descriptions. This is what an AI agent uses to understand your data.

 4. Run **describe** again, this time with the `entities` parameter set to `["Travels"]` to see its full element details.

 ### 6. Query data through MCP

 Still in the Inspector:

 1. Select the **query** tool
 2. Set `entity` to `Travels`
 3. Add a `select` parameter:
    ```json
    [{"ref":["ID"]}, {"ref":["Description"]}, {"ref":["TotalPrice"]}, {"ref":["Status","name"], "as":"Status"}]
    ```
 4. Set `limit` to `5`
 5. Click **Run Tool**

 You should see travel records returned in TOON format (a compact, token-efficient representation).

 Try a filtered query — add a `where` parameter:
 ```json
 [{"ref":["Status","code"]}, "=", {"val":"O"}]
 ```

 ### 7. Check the server logs

 Back in your `cds watch` terminal, observe the MCP requests being logged:

 ```js
 [mcp] - query {
   service: 'TravelService',
   entity: 'Travels',
   select: [
     { ref: [ 'ID' ] },
     { ref: [ 'Description' ] },
     { ref: [ 'TotalPrice' ] },
     { ref: [ 'Status', 'name' ] }
   ]
 }
 ```

 This shows how tool calls are translated into CQL queries against your service.

 ---

 ## Optional: Query with natural language (requires LLM access)

 If you have access to an LLM, you can use an MCP client to interact with your service using natural language. The CAP MCP adapter **autowires** into local clients automatically during `cds watch`.

 ### Using Claude Code

 Install: `brew install claude-code`

 ```bash
 claude "list all open travels with their agency and total price"
 ```

 ### Using OpenCode

 Install: `npm i -g opencode-ai`

 ```bash
 opencode run "list all open travels with their agency and total price"
 ```

 The agent will call `describe` to understand the model, then `query` to fetch data:

 ```
 ⏺ cds:TravelService - describe (MCP)()
 ⏺ cds:TravelService - query (MCP)(entity: "Travels", select: ["ID","Description","Agency.Name","TotalPrice","Status.name"], where: [...], limit: 20)
 ```

 Try more questions:
 - *"Which travel agencies have the most bookings?"*
 - *"Show me travels starting next month sorted by total price"*
 - *"What is the average booking fee across all open travels?"*

 > **Note:** Output varies depending on the LLM's interpretation of your question.

 ## Good to Know

 - **Autowiring** is only active during local development (`cds watch`). The MCP client configuration is added on start and removed on stop.
 - **Authentication**: The autowired config uses mock user `alice` by default. You can customize this in `package.json`:
   ```json
   {
     "cds": {
       "mcp": {
         "autowire": {
           "user": "admin",
           "password": "admin"
         }
       }
     }
   }
   ```
 - **Current limitation**: The MCP adapter currently supports reading data (`query`) and calling unbound actions (`call_action`). Direct CREATE/UPDATE/DELETE via MCP is not yet available — data modifications should be exposed as unbound actions.
 - **TOON format**: Results are returned in [TOON format](https://www.npmjs.com/package/@toon-format/toon) by default (compact, token-efficient). Set `cds.mcp.toon_format: false` for JSON output.

 ## Summary

 You have learned how to:
 - Install the `@cap-js/mcp` plugin with `npm add @cap-js/mcp`
 - Expose a CAP service via MCP with the `@mcp` annotation
 - Add custom instructions with `@mcp.instructions`
 - Explore and test MCP tools using the MCP Inspector (no LLM needed)
 - Query your service using natural language from an AI agent (optional)
 - Understand how tool calls are translated into CQL queries

 Continue to - [Exercise 10 - Recap and Next Steps](10_Recap.md)
