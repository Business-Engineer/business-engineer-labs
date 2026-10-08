-- GOAL: Write down which role may see which region, as data.
-- WHY:  Changing who sees what becomes one row, not a rewrite of the policy.
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE TABLE sales_db.governance.region_access (
  role_name STRING,   -- role, in UPPERCASE
  region    STRING    -- 'ALL' means every region
);

INSERT INTO sales_db.governance.region_access VALUES
  ('SALES_EMEA',       'EMEA'),
  ('SALES_APAC',       'APAC'),
  ('SALES_AMER',       'AMER'),
  ('GLOBAL_ANALYTICS', 'ALL');

-- GOAL: Check the rules were saved.
-- EXPECT: 4 rows.
SELECT * FROM sales_db.governance.region_access;
