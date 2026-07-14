 # Exercise 8 - AI Plugin

 In this exercise, you will add the `@cap-js/ai` plugin to your travel application. The plugin provides out-of-the-box AI-powered field recommendations in Fiori Elements UIs, leveraging SAP RPT-1. You will first test it locally (with a mock service) and then optionally connect it to a real SAP AI Core instance.

 
 ## What is the AI Plugin?

 The [`@cap-js/ai`](https://github.com/cap-js/ai) plugin bundles two AI capabilities:

 1. **UI Recommendations** — Automatically detects fields with value helps (`@Common.ValueList` or `@cds.odata.valuelist`) and provides intelligent recommendations in draft-enabled Fiori UIs using SAP RPT-1.
 2. **Simplified AI Core usage** — Embeds SAP AI Core as a standard CAP service following the Calesi pattern, with automatic service binding resolution and tenant-aware access.

 Our xstravels app already has value help annotations on fields like Status, Agency, Customer, Currency, and Flight — so the plugin will automatically provide recommendations for these fields without any custom handler code.

 ## Steps

 ### 1. Install the AI plugin

 In your terminal (inside the `xstravels` directory), install the plugin:

 ```bash
 npm add @cap-js/ai
 ```

 ### 2. Start the application

 ```bash
 cds watch
 ```

 Observe the console output. You should see a message indicating that the AI plugin is active. The plugin automatically:
 - Detects draft-enabled entities with value-helped fields
 - Adds `@UI.Recommendations` annotations
 - Creates synthetic companion entities (`Travels_Recommendations`, `Bookings_Recommendations`) for the recommendation data

 ### 3. Test locally with the mock service

 Without an SAP AI Core binding, the plugin uses a **MockAICoreService**. This mock service returns the first non-null value of each target column from existing data as the "prediction" — useful for UI smoke tests but not representative of real AI quality.

 1. Open the Fiori Elements UI at http://localhost:4004/travels/webapp/index.html
 2. Click **Create** to start a new travel (draft)
 3. Click into a field that has a value help (e.g., **Agency** or **Customer**)
 4. You should see recommendation values pre-filled or suggested in the value help dropdown

 > **Limitation:** The mock service simply picks existing values from your data as "recommendations." It does not use an actual AI model. The recommendations are deterministic and not context-aware. This is purely for verifying the UI integration works end-to-end.

 ### 4. Understand what happens under the hood

 The plugin:
 - Hooks into READ requests on draft entities that expand `SAP_Recommendations`
 - Sends up to 2000 rows from the **active** entity as context to RPT-1
 - Strips `createdAt`, `createdBy`, `modifiedAt`, `modifiedBy` and binary fields
 - Returns predictions with score values that Fiori Elements renders as soft-fill defaults

 ### 5. Exclude sensitive fields (optional)

 If you want to prevent a field from being included in recommendations (e.g., for data privacy reasons), annotate it with `@UI.RecommendationState: 0`:

 ```cds
 annotate TravelService.Travels with {
   Customer @UI.RecommendationState: 0;
 }
 ```

 You can also use dynamic expressions:

 ```cds
 annotate TravelService.Travels with {
   Agency @UI.RecommendationState: (TotalPrice > 10000 ? 0 : 1);
 }
 ```

 ---

 ## Optional: Connect to SAP AI Core

 > This section requires access to an SAP AI Core service instance on BTP. Skip this if you do not have one available.

 ### 6. Log in to Cloud Foundry

 Before you can bind to cloud services, you need to be logged in to your Cloud Foundry environment:

 ```bash
 cf login -a <your-cf-api-endpoint>
 ```

 Make sure you target the org and space where your AI Core service instance is located. You can verify with:

 ```bash
 cf target
 ```

 ### 7. Bind to your AI Core instance

 Use `cds bind` to create a local binding to your AI Core service instance:

 ```bash
 cds bind AICore -2 <your-ai-core-instance-name>
 ```

 Example output:
 ```
 [bind] - Retrieving data from Cloud Foundry...
 [bind] - Binding AICore to Cloud Foundry managed service my-ai-core:my-ai-core-key with kind AICore.
 [bind] - Saving bindings to .cdsrc-private.json in profile hybrid.
 [bind] -
 [bind] - TIP: Run with cloud bindings: cds watch --profile hybrid
 ```

 ### 8. Run with the hybrid profile

 Start the application with the `hybrid` profile to use the real AI Core binding:

 ```bash
 cds watch --profile hybrid
 ```

 The plugin will now:
 - Connect to your real SAP AI Core instance
 - Automatically create an RPT-1 deployment (if none exists) in the `default` resource group
 - Return actual AI-powered predictions based on patterns in your data

 ### 9. Test real recommendations

 1. Open the Fiori Elements UI
 2. Create a new travel
 3. Fill in some fields (e.g., Description, BeginDate, EndDate)
 4. Observe that the Agency, Customer, and Status fields now show intelligent recommendations based on patterns learned from existing data

 > **Note:** The first prediction call may take a moment as it provisions the RPT-1 deployment. Subsequent calls reuse the cached deployment.

 ## Summary

 You have learned how to:
 - Install the `@cap-js/ai` plugin with a single `npm add` command
 - Test recommendations locally with the built-in mock service
 - Understand the limitations of local testing (no real AI model)
 - Exclude fields from recommendations with `@UI.RecommendationState`
 - (Optional) Bind to a real SAP AI Core instance using `cds bind`
 - (Optional) Run in hybrid mode for real AI-powered predictions

 Continue to - [Exercise 9 - MCP](09_MCP.md)
