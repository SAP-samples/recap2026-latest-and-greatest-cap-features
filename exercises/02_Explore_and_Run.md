# Exercise 2 - Explore and Run the App

In this exercise, you will explore the xstravels application structure and run it locally.

## Prerequisites

Make sure you have completed [Exercise 1 - Setup](01_Introduction.md).


## Step 1 - Explore the code

The **xstravels** application combines ideas and artifacts from the public CAP samples **xflights** and **xtravels**.

Start by exploring the domain model in the `db` folder:

- The master data (for example flights, airlines, and related reference data) is defined in `db/flights.cds` and comes originally from the xflights sample.
- The travel business objects, including travel and booking entities, are modeled in `db/schema.cds`.

On top of that data model, the project exposes multiple services. The central service definition for this exercise is `srv/travel-service.cds`.

The UI is located in `app/travels`. It is a Fiori application that is served automatically when you run the project with `cds watch`.


## Step 2 - Run locally

Now run the application locally and walk through the main flow.

1. Start the CAP server with `cds watch`.
2. Open the local URL shown in the terminal (usually `http://localhost:4004`).
3. Launch the Fiori app from the welcome page. When prompted to sign in, use **`alice`** as the user and leave the password field **empty** — the sample runs with mocked auth in development.
4. In the app, open the list of travels and inspect the available entries.
5. Select one travel to view its object page and review the related details, including flight bookings.
6. Create a new travel using the draft flow.
7. Edit an existing travel and save your changes, again using the draft handling.

This gives you a first end-to-end impression of how CDS models, CAP services, and the Fiori UI work together in this sample.




 ## Summary

 In this exercise, you explored the main building blocks of the xstravels sample and understood how domain models, service definitions, and the Fiori UI are connected.

 You also started the application locally, navigated through the travel list and detail pages, and used the draft flow to create and update travel data.

 With this baseline, you are ready to explore the remaining exercises. Each is **self-contained** — pick whichever topic sounds most interesting; you don't have to go in order.

 If you'd like a natural next step, [Exercise 3 - Declarative Constraints](03_Declarative_Constraints.md) shows how validation logic moves from JavaScript handlers into the CDS model.
