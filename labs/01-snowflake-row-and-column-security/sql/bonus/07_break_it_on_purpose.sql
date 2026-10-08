-- Business Engineer Labs | Lab 01: Row-level and column-level security in Snowflake
-- Needs Snowflake Enterprise Edition or higher. Run with the ACCOUNTADMIN role.
-- Run the main scripts (00 to 05) first. Replace <your_username> where it appears.

-- ============================================================
-- Part 7: Break it
-- ============================================================

-- ---- 7a. Leak 1: Secondary roles ----

-- GOAL: Show how a salesperson sees more than they should when secondary roles are on.
-- WHY:  Switching to sales_emea changes your PRIMARY role. With secondary roles set to ALL,
--       your other granted roles (including global_analytics) stay active in the background,
--       so the policy sees them and lets you through.
-- EXPECT: more than 4 rows (all 12, because global_analytics is active in the background).
USE ROLE sales_emea;
USE SECONDARY ROLES ALL;
SELECT COUNT(*) AS rows_with_secondary_roles_on FROM sales_db.crm.customers;

-- GOAL: Turn secondary roles off and run the same query.
-- EXPECT: 4 rows.
USE SECONDARY ROLES NONE;
SELECT COUNT(*) AS rows_with_secondary_roles_off FROM sales_db.crm.customers;

-- Check your user's default. A new session starts from this value again.
-- (Switch back to admin first: only an admin can describe a user.)
USE ROLE ACCOUNTADMIN;
DESC USER <your_username>;   -- look at the DEFAULT_SECONDARY_ROLES row

-- ---- 7b. Leak 2: Role hierarchy ----

-- GOAL: Show the account admin seeing data nobody meant to share with it.
-- WHY:  If a data role is granted to SYSADMIN, then SYSADMIN holds it, and ACCOUNTADMIN
--       inherits it from SYSADMIN. The policy sees that inherited role.
-- EXPECT: 4 rows (EMEA's customers) for ACCOUNTADMIN, which saw 0 rows in Part 4.
USE ROLE ACCOUNTADMIN;
USE SECONDARY ROLES NONE;

GRANT ROLE sales_emea TO ROLE SYSADMIN;
SELECT COUNT(*) AS rows_visible_to_admin FROM sales_db.crm.customers;

-- GOAL: Undo it and confirm we are back to default deny.
-- EXPECT: 0 rows.
REVOKE ROLE sales_emea FROM ROLE SYSADMIN;
SELECT COUNT(*) AS rows_visible_to_admin FROM sales_db.crm.customers;

-- ---- 7c. Leak 3: The orphan row ----

-- GOAL: Show who can see the customer that has no region.
-- WHY:  In SQL, NULL is never equal to anything, so no line in the mapping table can match a
--       row whose region is empty. Only a role mapped to 'ALL' can see it.
-- EXPECT: 1 row for global_analytics, 0 rows for sales_emea.
USE ROLE global_analytics;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region
FROM sales_db.crm.customers WHERE region IS NULL;

USE ROLE sales_emea;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region
FROM sales_db.crm.customers WHERE region IS NULL;

USE ROLE ACCOUNTADMIN;

-- ---- 7d. A common mistake: created but not attached ----

-- GOAL: Catch the mistake of creating a policy and never attaching it.
-- WHY:  A policy that is created but not attached protects nothing. The query runs, and
--       the real values come back. Compare this output with what you think you built.
-- EXPECT: one ROW_ACCESS_POLICY row for REGION, plus MASKING_POLICY rows for EMAIL and PHONE.
USE ROLE ACCOUNTADMIN;

SELECT *
FROM TABLE(sales_db.INFORMATION_SCHEMA.POLICY_REFERENCES(
       REF_ENTITY_NAME   => 'sales_db.crm.customers',
       REF_ENTITY_DOMAIN => 'TABLE'));
