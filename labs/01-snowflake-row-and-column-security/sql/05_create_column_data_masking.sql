-- GOAL: Decide what each viewer sees in EMAIL and PHONE.
-- HOW:  Sales roles get the real value. Everyone else gets email with the name part
--       replaced by *****, and phone fully hidden.
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE MASKING POLICY sales_db.governance.email_mask
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SALES_EMEA')
      OR IS_ROLE_IN_SESSION('SALES_APAC')
      OR IS_ROLE_IN_SESSION('SALES_AMER') THEN val
    ELSE REGEXP_REPLACE(val, '^[^@]+', '*****')
  END;

CREATE OR REPLACE MASKING POLICY sales_db.governance.phone_mask
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SALES_EMEA')
      OR IS_ROLE_IN_SESSION('SALES_APAC')
      OR IS_ROLE_IN_SESSION('SALES_AMER') THEN val
    ELSE '*** MASKED ***'
  END;


-- GOAL: Attach each masking policy to its column.
-- WHY:  The stored data does not change. Only what each role gets back changes.

ALTER TABLE sales_db.crm.customers MODIFY COLUMN email
SET MASKING POLICY sales_db.governance.email_mask;

ALTER TABLE sales_db.crm.customers MODIFY COLUMN phone
SET MASKING POLICY sales_db.governance.phone_mask;

-- GOAL: Check and verify which policies are attached, to avoid issues.
-- EXPECT: one ROW_ACCESS_POLICY row for REGION, plus one MASKING_POLICY row each for
--         EMAIL and PHONE.

SELECT *
FROM TABLE(sales_db.INFORMATION_SCHEMA.POLICY_REFERENCES(
       REF_ENTITY_NAME   => 'sales_db.crm.customers',
       REF_ENTITY_DOMAIN => 'TABLE'));


-- TEST DATA MASKING
-- GOAL: Run the same query as each team role, one after another.
-- EXPECT: sales roles see real emails and phones. global_analytics sees masked values.
USE ROLE sales_emea;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region, email, phone FROM sales_db.crm.customers ORDER BY customer_id;

USE ROLE sales_apac;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region, email, phone FROM sales_db.crm.customers ORDER BY customer_id;

USE ROLE sales_amer;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region, email, phone FROM sales_db.crm.customers ORDER BY customer_id;

USE ROLE global_analytics;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region, email, phone FROM sales_db.crm.customers ORDER BY customer_id;

USE ROLE ACCOUNTADMIN;
