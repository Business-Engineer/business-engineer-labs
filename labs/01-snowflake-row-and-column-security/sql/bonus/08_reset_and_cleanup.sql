-- Business Engineer Labs | Lab 01: Row-level and column-level security in Snowflake
-- Needs Snowflake Enterprise Edition or higher. Run with the ACCOUNTADMIN role.
-- Run the main scripts (00 to 05) first. Replace <your_username> where it appears.

-- ============================================================
-- Part 8: Reset or clean up
-- Everything below is commented out on purpose, so "Run all" cannot delete your work.
-- Select the lines you want and uncomment them to use them.
-- ============================================================

-- ---- Reset the policies only ----

-- GOAL: Remove the policies from the table so you can re-run Parts 3 to 6.
-- WHY:  A policy must be detached from the table before it can be dropped.
-- USE ROLE ACCOUNTADMIN;

-- ALTER TABLE sales_db.crm.customers DROP ROW ACCESS POLICY sales_db.governance.region_rap;
-- ALTER TABLE sales_db.crm.customers MODIFY COLUMN email UNSET MASKING POLICY;
-- ALTER TABLE sales_db.crm.customers MODIFY COLUMN phone UNSET MASKING POLICY;

-- DROP ROW ACCESS POLICY IF EXISTS sales_db.governance.region_rap;
-- DROP MASKING POLICY    IF EXISTS sales_db.governance.email_mask;
-- DROP MASKING POLICY    IF EXISTS sales_db.governance.phone_mask;

-- ---- Remove everything ----

-- GOAL: Delete everything this script created.
-- WARNING: this permanently deletes the sales_db database, its data and the roles below.
-- USE ROLE ACCOUNTADMIN;

-- DROP DATABASE IF EXISTS sales_db;
-- DROP ROLE IF EXISTS sales_emea;
-- DROP ROLE IF EXISTS sales_apac;
-- DROP ROLE IF EXISTS sales_amer;
-- DROP ROLE IF EXISTS global_analytics;
-- DROP ROLE IF EXISTS crm_reader;
