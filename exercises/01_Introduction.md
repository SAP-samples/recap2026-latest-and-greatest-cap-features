 # Exercise 0 - Setup
 
 In this exercise, you will clone the repository and set up your development environment.
 
 ## Prerequisites
 
 Make sure you have the following installed:
 - Git
 - Visual Studio Code
 
 ## Steps
 
 1. Open Visual Studio Code
 
 2. On the Welcome screen, click on **Clone Git Repository**
 
 3. Enter the repository URL:
    ```
    https://github.com/SAP-samples/recap2026-latest-and-greatest-cap-features.git
    ```
 
 4. Select a folder location to clone the repository
 
 5. When prompted, click **Open** to open the cloned repository in VS Code
 
 6. Open a terminal in VS Code (Terminal > New Terminal)
 
 7. Install the latest `@sap/cds-dk` version
 
    ```bash
    npm i -g @sap/cds-dk
    ```
 
 8. Navigate to the `xstravels` directory and install dependencies:
    ```bash
    cd xstravels
    npm install
    ```
 
 ## Summary
 
 You have successfully cloned the repository, installed the dependencies, and opened it in VS Code. You're now ready to start working with the CAP application.
 
 Continue to - [Exercise 2 - Explore and Run the App](02_Explore_and_Run.md)
 