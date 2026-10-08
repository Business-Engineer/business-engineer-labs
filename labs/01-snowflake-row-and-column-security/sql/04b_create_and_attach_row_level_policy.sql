-- GOAL: Create the rule itself (the row access policy).
-- HOW:  For every row, Snowflake passes that row's region into cust_region and asks
--       "may this session see this row?" The policy looks in the mapping table for a line
--       where the user holds that role AND the region matches (or is 'ALL').
--       No matching line means the row is hidden. That is "default deny".
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE ROW ACCESS POLICY sales_db.governance.region_rap
  AS (cust_region STRING) RETURNS BOOLEAN ->
  EXISTS (
    SELECT 1
    FROM sales_db.governance.region_access m
    WHERE IS_ROLE_IN_SESSION(m.role_name)
      AND (m.region = cust_region OR m.region = 'ALL')
  );


-- GOAL: Attach the policy to the region column.
-- WHY:  A policy does nothing until it is attached. After this, every query is filtered.

ALTER TABLE sales_db.crm.customers
ADD ROW ACCESS POLICY sales_db.governance.region_rap ON (region);


-- TEST THE POLICY

-- GOAL: Same table, one role at a time.

USE ROLE sales_emea;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region FROM sales_db.crm.customers ORDER BY customer_id;  -- 4

USE ROLE sales_apac;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region FROM sales_db.crm.customers ORDER BY customer_id;  -- 4

USE ROLE sales_amer;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region FROM sales_db.crm.customers ORDER BY customer_id;  -- 3

USE ROLE global_analytics;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region FROM sales_db.crm.customers ORDER BY customer_id;  -- 12

-- GOAL: What does the admin see? Admins are not exempt.
USE ROLE ACCOUNTADMIN;
USE SECONDARY ROLES NONE;
SELECT COUNT(*) AS rows_visible_to_admin FROM sales_db.crm.customers;  -- 0
