 # Exercise 9 - MCP

 In this exercise, you will expose your CAP Travel Service as an MCP (Model Context Protocol) server, allowing AI agents to interact with your travel data through natural language.

 ## Prerequisites

 Make sure you have completed [Exercise 8 - AI Plugin](08_AI_Plugin.md).

 You also need:
 - Access to an LLM (e.g., an Anthropic API key or OpenAI API key configured for your MCP client)
 - One of the following MCP clients installed:
   - [Claude Code](https://code.claude.com/docs/en/overview) — `brew install claude-code`
   - [OpenCode](https://opencode.ai/) — `npm i -g opencode-ai`

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

 annotate TravelService with @mcp;
 ```

 ### 3. Add custom instructions for the AI agent (optional)

 You can provide context to help the AI agent understand your service better. Update `srv/travel-mcp.cds`:

 ```cds
 using { TravelService } from './travel-service';

 annotate TravelService with @mcp
   @mcp.instructions: 'This service manages travel bookings. Use describe to explore available entities like Travels, Bookings, Customers, and Flights. Use query to search travels by status, date range, or agency.';
 ```

 ### 4. Start the server

 ```bash
 cds watch
 ```

 Observe the console output — you should see the MCP endpoint listed:

 ```
 [cds] - serving TravelService {
   at: [ ..., '/mcp/travel' ],
   ...
 }
 ```

 The plugin also **autowires** the MCP server into your local MCP clients (Claude Code, OpenCode). This means no additional client configuration is needed for local development.

 ### 5. Query your service with natural language

 Open your MCP client and ask questions about your travel data:

 **With Claude Code:**
 ```bash
 claude "list all open travels with their agency and total price"
 ```

 **With OpenCode:**
 ```bash
 opencode run "list all open travels with their agency and total price"
 ```

 The AI agent will use the `describe` tool to understand your data model, then the `query` tool to fetch the data. You should see something like:

 ```
 ⏺ cds:TravelService - describe (MCP)()
 ⏺ cds:TravelService - query (MCP)(entity: "Travels", select: ["ID","Description","Agency.Name","TotalPrice","Status.name"], where: [...], limit: 20)
 ```

 ### 6. Try more complex queries

 Ask the agent more interesting questions:

 - *"Which travel agencies have the most bookings?"*
 - *"Show me travels starting next month sorted by total price"*
 - *"List all flights used in bookings for travel 1"*
 - *"What is the average booking fee across all open travels?"*

 ### 7. Inspect with the MCP Inspector (optional)

 You can also use the official MCP Inspector to explore the tools:

 ```bash
 npx @modelcontextprotocol/inspector
 ```

 1. Select **Streamable HTTP** as Transport Type
 2. Enter the URL: `http://localhost:4004/mcp/travel`
 3. Select **Via Proxy** and click **Connect**
 4. Go to the **Tools** tab and click **List Tools**
 5. Select the **describe** tool and run it to see your data model
 6. Select the **query** tool, choose an entity, and run it to fetch data

 ### 8. Check the server logs

 Back in your `cds watch` terminal, observe the MCP requests being logged:

 ```js
 [mcp] - query {
   service: 'TravelService',
   entity: 'Travels',
   select: [
     { ref: [ 'ID' ] },
     { ref: [ 'Description' ] },
     { ref: [ 'Agency', 'Name' ] },
     { ref: [ 'TotalPrice' ] },
     { ref: [ 'Status', 'name' ] }
   ]
 }
 ```

 This shows how the AI agent translates natural language into structured CQL queries against your service.

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
 - Query your service using natural language from an AI agent
 - Inspect MCP tools with the MCP Inspector
 - Understand how natural language is translated into CQL queries

 Continue to - [Exercise 10 - Recap and Next Steps](10_Recap.md)
