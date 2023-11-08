# LibreBudgeteer
An open source Budget Flutter app

- mint style budgeting
- automatic transaction sync and categorization using plaid service (Canada and US)
- custom transaction sync rules (substring matching, fitering, re-categorization)
- in-app transaction re-categorization and removal
- multiple users (couples budgeting)
- transaction and balanaces data is synced to your own InfluxDB database instance
- transaction rules and budget categories are hosted in notion.so

<img src="https://github.com/mzakharo/librebudgeteer/blob/main/images/dashboard.jpg" width="151" height="320"> <img src="https://github.com/mzakharo/librebudgeteer/blob/main/images/budgets.jpg" width="151" height="320"> <img src="https://github.com/mzakharo/librebudgeteer/blob/main/images/expenses.jpg" width="151" height="320"> <img src="https://github.com/mzakharo/librebudgeteer/blob/main/images/history.jpg" width="151" height="320"> 

# Setup

 - Setup plaid transaction rules page/database in notion.so. [example](https://github.com/mzakharo/librebudgeteer/blob/main/images/rules.PNG)
 - Setup budgets in another notion.so page/database [example](https://github.com/mzakharo/librebudgeteer/blob/main/images/budgets.png)
 - Setup influxDB database (I run mine from a docker container on a Raspberry PI). Setup a bucket for keeping transaction data
 - Setup [plaid-sync](https://github.com/mzakharo/librebudgeteer/tree/main/plaid-sync)
 - Build and run the [app](https://github.com/mzakharo/librebudgeteer/tree/main/app)
   
 
