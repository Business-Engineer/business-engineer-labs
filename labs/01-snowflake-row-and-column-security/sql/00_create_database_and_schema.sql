-- GOAL: Create the database, the two schemas and the customer table with 12 rows.
-- WHY:  Everything else in the demo runs against this one table, so we start by
--       making sure it exists and holds exactly the data the demo expects.
--       The "crm" schema holds the data. The "governance" schema holds the security
--       objects (the mapping table and the policies), which keeps them apart from the data.
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS sales_db;
CREATE SCHEMA   IF NOT EXISTS sales_db.crm;
CREATE SCHEMA   IF NOT EXISTS sales_db.governance;

-- GOAL: Stop the warehouse after 60 seconds idle.
-- WHY:  On a trial account every idle minute spends credits. Change COMPUTE_WH
--       if your warehouse has a different name.
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;

-- GOAL: Create the customer table.
CREATE OR REPLACE TABLE sales_db.crm.customers (
  customer_id        INT,
  customer_name      STRING,
  region             STRING,          -- EMEA, APAC or AMER (one row has no region)
  country            STRING,
  email              STRING,          -- personal detail: will be masked later
  phone              STRING,          -- personal detail: will be masked later
  annual_revenue_gbp NUMBER(12,2)
);

-- GOAL: Load 12 customers: 4 EMEA, 4 APAC, 3 AMER and one with no region (customer 12).
-- WHY:  The row with no region (NULL) is deliberate. It is one of the traps in the bonus
--       script, "Break it on purpose".
INSERT INTO sales_db.crm.customers VALUES
  (1,  'Northwind Ltd',       'EMEA', 'UK',        'ops@northwind.example',      '+44 20 7946 0101',  1200000),
  (2,  'Bavaria Parts GmbH',  'EMEA', 'Germany',   'einkauf@bavaria.example',    '+49 30 1234 5678',   860000),
  (3,  'Lyon Foods SA',       'EMEA', 'France',    'achats@lyonfoods.example',   '+33 1 23 45 67 89',  430000),
  (4,  'Nordic Steel AB',     'EMEA', 'Sweden',    'buy@nordicsteel.example',    '+46 8 123 456 78',  2100000),
  (5,  'Pune Motors Pvt',     'APAC', 'India',     'procure@punemotors.example', '+91 20 1234 5678',   950000),
  (6,  'Osaka Robotics KK',   'APAC', 'Japan',     'info@osakarobo.example',     '+81 6 1234 5678',   1750000),
  (7,  'Sydney Retail Pty',   'APAC', 'Australia', 'ap@sydretail.example',       '+61 2 1234 5678',    390000),
  (8,  'Singa Logistics',     'APAC', 'Singapore', 'ops@singalog.example',       '+65 6123 4567',      640000),
  (9,  'Texas Freight Inc',   'AMER', 'USA',       'billing@txfreight.example',  '+1 512 555 0101',   1400000),
  (10, 'Maple Energy Corp',   'AMER', 'Canada',    'supply@mapleenergy.example', '+1 416 555 0102',    780000),
  (11, 'Andes Mining SA',     'AMER', 'Chile',     'compras@andes.example',      '+56 2 2123 4567',   1100000),
  (12, 'Orphan Account Ltd',  NULL,   'UK',        'hello@orphan.example',       '+44 161 496 0000',    300000);
