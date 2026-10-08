-- GOAL: Create one role per team, plus a shared read-only role.
-- WHY:  Security rules are written in terms of roles, not people.
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS crm_reader;
CREATE ROLE IF NOT EXISTS sales_emea;
CREATE ROLE IF NOT EXISTS sales_apac;
CREATE ROLE IF NOT EXISTS sales_amer;
CREATE ROLE IF NOT EXISTS global_analytics;

-- GOAL: Give crm_reader just enough access to read the table.
-- WHY:  A role needs the warehouse, database, schema and SELECT to run a query.
GRANT USAGE  ON WAREHOUSE COMPUTE_WH             TO ROLE crm_reader;
GRANT USAGE  ON DATABASE  sales_db               TO ROLE crm_reader;
GRANT USAGE  ON SCHEMA    sales_db.crm           TO ROLE crm_reader;
GRANT SELECT ON TABLE     sales_db.crm.customers TO ROLE crm_reader;

-- GOAL: Give every team role that read access.
GRANT ROLE crm_reader TO ROLE sales_emea;
GRANT ROLE crm_reader TO ROLE sales_apac;
GRANT ROLE crm_reader TO ROLE sales_amer;
GRANT ROLE crm_reader TO ROLE global_analytics;

-- GOAL: Grant the four team roles to your user so you can switch between them.
-- WHY:  In real life each person would hold only their own role. Here you hold all four
--       so you can test every view.
-- ACTION: Replace <your_username> with your Snowflake username.
GRANT ROLE sales_emea       TO USER <your_username>;
GRANT ROLE sales_apac       TO USER <your_username>;
GRANT ROLE sales_amer       TO USER <your_username>;
GRANT ROLE global_analytics TO USER <your_username>;
