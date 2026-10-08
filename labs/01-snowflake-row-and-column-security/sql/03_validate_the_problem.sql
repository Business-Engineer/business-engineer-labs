-- GOAL: Reproduce the leak with an EMEA salesperson.
-- WHY:  The role can read the table, but nothing limits WHICH rows yet.
-- EXPECT: 12 rows, including customers in APAC and AMER.

USE ROLE sales_emea;
USE SECONDARY ROLES NONE;   -- test as this one role only (see the bonus script for why)
SELECT customer_id, customer_name, region, email FROM sales_db.crm.customers ORDER BY customer_id;

USE ROLE ACCOUNTADMIN;
