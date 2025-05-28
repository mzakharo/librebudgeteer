# LibreBudgeteer
An open source Budget Flutter app

- mint.com style budgeting
- custom transaction sync rules (substring matching, filtering, re-categorization)
- multiple users (couples budgeting)
- transaction and balances data is synced to your local InfluxDB database
- transaction rules and budget categories are hosted in notion.so
- App tested with Android/Windows/Linux

<img src="https://github.com/mzakharo/librebudgeteer/blob/main/images/dashboard.jpg" width="151" height="320"> <img src="https://github.com/mzakharo/librebudgeteer/blob/main/images/budgets.jpg" width="151" height="320"> <img src="https://github.com/mzakharo/librebudgeteer/blob/main/images/expenses.jpg" width="151" height="320"> <img src="https://github.com/mzakharo/librebudgeteer/blob/main/images/history.jpg" width="151" height="320"> 

# Setup

 - Setup transaction rules page/database in notion.so. [example](https://github.com/mzakharo/librebudgeteer/blob/main/images/rules.PNG)
 - Setup budgets in another notion.so page/database [example](https://github.com/mzakharo/librebudgeteer/blob/main/images/budgets.png)
 - Setup InfluxDB 2.0 database: [Installation Instructions](https://docs.influxdata.com/influxdb/v2/install/?t=Docker) 
 - Upload some transactions to InfluxDB. Examples in `tangerine` (csv import) or `wealthica` (G-Sheets)
 - Build and run the [app](https://github.com/mzakharo/librebudgeteer/tree/main/app)


   
 
