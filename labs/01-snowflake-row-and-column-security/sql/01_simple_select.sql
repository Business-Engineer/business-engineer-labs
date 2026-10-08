-- GOAL: Look at the data exactly as it stands today.
-- WHY:  This is the starting point. Nothing is protected yet.
USE ROLE ACCOUNTADMIN;

SELECT * FROM sales_db.crm.customers ORDER BY customer_id;
