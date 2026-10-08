# How to Secure and Mask Data in Snowflake

Row-level and column-level security on one shared customer table, with a mapping table, a row access policy and masking policies. Includes three ways a correct-looking setup still leaks, and how to test for each.

This is the SQL script for the video **"How to Secure and Mask Data in Snowflake"**. Run it top to bottom in a Snowflake trial account and you will reproduce everything shown in the demo.

> Video: `<add video link here>`
> Part of the Business Engineer series.

---

## The scenario

Imagine a global company. Three sales teams (EMEA, APAC and AMER) and one analytics team all need the same customer table, which holds names, emails and phone numbers.

| Who | Which rows | Email | Phone |
| --- | --- | --- | --- |
| Sales EMEA | Own region only (4 customers) | Visible | Visible |
| Sales APAC | Own region only (4 customers) | Visible | Visible |
| Sales AMER | Own region only (3 customers) | Visible | Visible |
| Global analytics | Every region (all 12 customers) | Masked | Masked |

The table has 12 customers: four in EMEA, four in APAC, three in AMER, and one with no region at all. That last one matters later.

The question: **how do four people share one table, safely?**

## What you will build

- Four roles, one per sales region plus one for global analytics.
- A mapping table that says which role may see which region.
- A **row access policy** that reads the mapping table, so each role sees only its own rows.
- Two **masking policies** that hide email and phone from everyone except the sales roles.
- A test for each of three leaks: secondary roles, role hierarchy, and an orphan row.

One copy of the data. One rule, attached to the table. No per-region copies and no per-team views.

## Requirements

- A Snowflake account on **Enterprise Edition or higher**. Row access policies and masking policies are not available on Standard Edition. A free trial account on Enterprise Edition works.
- The `ACCOUNTADMIN` role, which a trial account gives you by default.
- A warehouse. A trial account includes one called `COMPUTE_WH`. If yours has a different name, replace it wherever it appears.
- Your Snowflake username, for the grants in Part 2.

## How to run it

1. In Snowsight, go to **Projects**, then **Workspaces**, and create a new SQL file.
2. Paste in one part at a time and run the statements in order. Each statement ends with a semicolon.
3. Replace `<your_username>` in Part 2 with your own username.
4. Read the comments. Each block says what it is trying to achieve and why.

Run Parts 0 to 6 first. They build and prove the design. Part 7 breaks it on purpose. Part 8 cleans up.

| Part | What it does |
| --- | --- |
| 0 | Set up the database, schemas and the sample data |
| 1 | Look at the data with a plain SELECT |
| 2 | Create the roles and give them access |
| 3 | Prove the problem: a salesperson sees every region |
| 4 | Row-level security with a mapping table and a row access policy |
| 5 | Column-level security with masking policies |
| 6 | Four people, one table |
| 7 | Break it: three leaks, plus a common mistake |
| 8 | Reset or clean up |

---

## Part 0: Set up the data

Skip this part if you already loaded the data from the script linked in the video description.

```sql
-- GOAL: Create the database, the two schemas and the customer table with 12 rows.
-- WHY:  Everything else in this script runs against this one table, so we start by
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
-- WHY:  The row with no region (NULL) is deliberate. It is one of the traps in Part 7.
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
  (12, 'Orphan Account Ltd',  NULL,   'UK',        'hello@orphan.example',       '+44 161 496 0000',   300000);
```

---

## Part 1: Look at the data

```sql
-- GOAL: Look at the table exactly as it stands today.
-- WHY:  This is the starting point of the demo. Nothing is protected yet, so every
--       person with access to this table would see all of this.
-- EXPECT: 12 rows, every region, real emails and real phone numbers.
USE ROLE ACCOUNTADMIN;

SELECT * FROM sales_db.crm.customers ORDER BY customer_id;
```

---

## Part 2: Create the roles

A role is how Snowflake knows who is asking. We create one per sales region, one for analytics, and a shared role that holds the read privileges so we only define them once.

```sql
-- GOAL: Create the roles.
-- WHY:  The security rules in later parts are written in terms of roles, not people.
--       "crm_reader" only carries the basic read privileges. The four others are the
--       team roles from the scenario.
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS crm_reader;        -- holds the object privileges
CREATE ROLE IF NOT EXISTS sales_emea;
CREATE ROLE IF NOT EXISTS sales_apac;
CREATE ROLE IF NOT EXISTS sales_amer;
CREATE ROLE IF NOT EXISTS global_analytics;

-- GOAL: Give crm_reader just enough access to read the customer table.
-- WHY:  To run a SELECT a role needs to use a warehouse, the database and the schema,
--       and to have SELECT on the table. Without USAGE on the warehouse, a role switch
--       fails with a "no active warehouse" error.
GRANT USAGE  ON WAREHOUSE COMPUTE_WH             TO ROLE crm_reader;
GRANT USAGE  ON DATABASE  sales_db               TO ROLE crm_reader;
GRANT USAGE  ON SCHEMA    sales_db.crm           TO ROLE crm_reader;
GRANT SELECT ON TABLE     sales_db.crm.customers TO ROLE crm_reader;

-- GOAL: Give each team role that read access.
GRANT ROLE crm_reader TO ROLE sales_emea;
GRANT ROLE crm_reader TO ROLE sales_apac;
GRANT ROLE crm_reader TO ROLE sales_amer;
GRANT ROLE crm_reader TO ROLE global_analytics;

-- GOAL: Grant the four team roles to YOUR user so you can switch between them and play
--       each person in the demo.
-- WHY:  In real life each person would hold only their own role. Here you hold all
--       four so you can test every view. This is also what sets up the secondary-roles
--       trap in Part 7.
-- ACTION: Replace <your_username> with your Snowflake username.
GRANT ROLE sales_emea       TO USER <your_username>;
GRANT ROLE sales_apac       TO USER <your_username>;
GRANT ROLE sales_amer       TO USER <your_username>;
GRANT ROLE global_analytics TO USER <your_username>;
```

---

## Part 3: Prove the problem

```sql
-- GOAL: Reproduce the leak: an EMEA salesperson running one simple query.
-- WHY:  The roles can read the table, but nothing yet limits WHICH rows they read.
-- EXPECT: 12 rows. The EMEA salesperson sees customers in APAC and AMER too.
USE ROLE sales_emea;
USE SECONDARY ROLES NONE;   -- test as this one role only (explained in Part 7)

SELECT customer_id, customer_name, region, email
FROM sales_db.crm.customers ORDER BY customer_id;

-- Return to admin so the session is left in a known state.
USE ROLE ACCOUNTADMIN;
```

---

## Part 4: Row-level security

Three small steps: write the rule down as data, turn it into a policy, attach the policy to the table.

### Step 1: The mapping table

```sql
-- GOAL: Write down, in a table, which role may see which region.
-- WHY:  Keeping the rule as DATA, not hard-coded inside the policy, means the business
--       can change who sees what by editing one row. Nobody has to rewrite the policy.
USE ROLE ACCOUNTADMIN;   -- governance objects are created by an admin, never by the sales roles

CREATE OR REPLACE TABLE sales_db.governance.region_access (
  role_name STRING,      -- the role, in UPPERCASE (Snowflake stores unquoted role names that way)
  region    STRING       -- the region that role may see; 'ALL' means every region
);

-- GOAL: Fill in the rules. Each regional role sees only its own region.
--       The analytics role sees everything (its personal details get masked in Part 5).
INSERT INTO sales_db.governance.region_access VALUES
  ('SALES_EMEA',       'EMEA'),
  ('SALES_APAC',       'APAC'),
  ('SALES_AMER',       'AMER'),
  ('GLOBAL_ANALYTICS', 'ALL');

-- Note: no role is granted access to this table. The policy reads it with its owner's
-- rights, so salespeople can never read or edit these rules themselves.
```

### Step 2: The row access policy

```sql
-- GOAL: Create the rule itself (the row access policy).
-- HOW IT WORKS: for every row, Snowflake passes that row's region into cust_region and
--       asks "TRUE or FALSE: may this session see this row?"
--       The EXISTS subquery looks for a line in the mapping table where:
--         (a) the user currently holds that role     -> IS_ROLE_IN_SESSION(...)
--         (b) the line's region matches this row's region, or is 'ALL'
--       No matching line means FALSE, so the row is hidden. That is "default deny".
-- WHY IS_ROLE_IN_SESSION and not CURRENT_ROLE(): Snowflake recommends it for policies
--       because it also looks at secondary roles and the role hierarchy. That is exactly
--       where two of the leaks in Part 7 come from.
CREATE OR REPLACE ROW ACCESS POLICY sales_db.governance.region_rap
  AS (cust_region STRING) RETURNS BOOLEAN ->
  EXISTS (
    SELECT 1
    FROM sales_db.governance.region_access m
    WHERE IS_ROLE_IN_SESSION(m.role_name)
      AND (m.region = cust_region OR m.region = 'ALL')
  );
```

### Step 3: Attach the policy

```sql
-- GOAL: Attach the rule to the table's region column.
-- WHY:  A policy does nothing until it is attached. From this moment EVERY query on this
--       table, from any tool or dashboard, is filtered automatically.
--       No copies of the data and no per-team views.
ALTER TABLE sales_db.crm.customers
  ADD ROW ACCESS POLICY sales_db.governance.region_rap ON (region);
```

### Step 4: Prove it

```sql
-- GOAL: Prove the rule works. Same table, one role at a time.
-- EXPECT: EMEA 4 rows, APAC 4 rows, AMER 3 rows, global analytics 12 rows, admin 0 rows.
-- WHY secondary roles NONE: your user holds all four roles at once, which would mix
--       their views together and hide the effect we are testing (see Part 7a).

USE ROLE sales_emea;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region FROM sales_db.crm.customers ORDER BY customer_id;  -- 4 rows

USE ROLE sales_apac;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region FROM sales_db.crm.customers ORDER BY customer_id;  -- 4 rows

USE ROLE sales_amer;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region FROM sales_db.crm.customers ORDER BY customer_id;  -- 3 rows

USE ROLE global_analytics;
USE SECONDARY ROLES NONE;
SELECT customer_id, customer_name, region FROM sales_db.crm.customers ORDER BY customer_id;  -- 12 rows, including customer 12

-- GOAL: Check what the account admin sees. EXPECT: 0.
-- WHY:  Admins are not exempt. No line in the mapping table gives ACCOUNTADMIN a region,
--       so default deny applies even to the most powerful role.
USE ROLE ACCOUNTADMIN;
USE SECONDARY ROLES NONE;
SELECT COUNT(*) AS rows_visible_to_admin FROM sales_db.crm.customers;
```

---

## Part 5: Column-level security

The row policy decides which customers you see. Masking policies decide what you can read about them. Sales needs real emails and phone numbers to do the job. Analytics only needs patterns, not people.

### Step 1: Create the masking policies

```sql
-- GOAL: Create a rule that decides what a viewer sees in the EMAIL column.
-- HOW IT READS: val is the real value stored in the column.
--       The regional sales roles get the real value back. Everyone else gets the part
--       before the @ replaced with *****, so ops@northwind.example becomes
--       *****@northwind.example. Analytics can still count customers per domain.
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE MASKING POLICY sales_db.governance.email_mask
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SALES_EMEA')
      OR IS_ROLE_IN_SESSION('SALES_APAC')
      OR IS_ROLE_IN_SESSION('SALES_AMER') THEN val           -- sales: real email
    ELSE REGEXP_REPLACE(val, '^[^@]+', '*****')              -- everyone else: masked
  END;

-- GOAL: Same idea for the PHONE column, but fully hidden.
-- WHY:  A partly masked phone number cannot be analysed in any useful way,
--       so there is nothing worth keeping.
CREATE OR REPLACE MASKING POLICY sales_db.governance.phone_mask
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('SALES_EMEA')
      OR IS_ROLE_IN_SESSION('SALES_APAC')
      OR IS_ROLE_IN_SESSION('SALES_AMER') THEN val           -- sales: real phone
    ELSE '*** MASKED ***'                                    -- everyone else: hidden
  END;
```

### Step 2: Attach them to the columns

```sql
-- GOAL: Attach each masking policy to its column.
-- WHY:  Same as before: creating a policy does nothing until it is attached.
--       The stored data does not change. What changes is what each role gets back.
--       We are protecting the VIEW of the data, not making copies of it.
-- NOTE: The region column already has the row access policy. Snowflake does not allow
--       one column to be in both a row access policy and a masking policy, which is
--       why we mask email and phone only.
ALTER TABLE sales_db.crm.customers MODIFY COLUMN email
  SET MASKING POLICY sales_db.governance.email_mask;

ALTER TABLE sales_db.crm.customers MODIFY COLUMN phone
  SET MASKING POLICY sales_db.governance.phone_mask;
```

### Step 3: Check what is attached

```sql
-- GOAL: Ask Snowflake which policies are attached to this table, and to which columns.
-- WHY:  Creating and attaching are two separate steps. This is how you confirm what is
--       actually enforced instead of assuming.
-- EXPECT: one ROW_ACCESS_POLICY row for REGION, and one MASKING_POLICY row each for
--         EMAIL and PHONE.
USE ROLE ACCOUNTADMIN;

SELECT *
FROM TABLE(sales_db.INFORMATION_SCHEMA.POLICY_REFERENCES(
       REF_ENTITY_NAME   => 'sales_db.crm.customers',
       REF_ENTITY_DOMAIN => 'TABLE'));
```

---

## Part 6: Four people, one table

```sql
-- GOAL: Put the four people from the scenario in front of the same table, one after another.
-- EXPECT:
--   sales_emea       4 rows,  real emails and phones
--   sales_apac       4 rows,  real emails and phones
--   sales_amer       3 rows,  real emails and phones
--   global_analytics 12 rows, emails like *****@northwind.example, phones *** MASKED ***
-- WHY secondary roles NONE: so each test uses one role only.

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

-- GOAL: Show that analytics can still do its job without personal details: totals by region.
--       Look at the NULL region row. That is customer 12, and it is the third trap below.
SELECT region, COUNT(*) AS customers, SUM(annual_revenue_gbp) AS revenue_gbp
FROM sales_db.crm.customers GROUP BY region ORDER BY region;

USE ROLE ACCOUNTADMIN;
```

---

## Part 7: Break it

A correct policy can still leak. Run these on purpose so you recognise them when they happen to you.

### 7a. Leak 1: Secondary roles

By default, a Snowflake user can hold all of their granted roles at the same time. These extra roles are called secondary roles. A policy written with `IS_ROLE_IN_SESSION` sees them all.

```sql
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
```

**The fix:** turn secondary roles off while you test, and remember that a new session goes back to the default.

### 7b. Leak 2: Role hierarchy

Roles can be granted to other roles. Privileges flow upward: a parent role gets everything its child roles can do. `ACCOUNTADMIN` sits above `SYSADMIN`.

```sql
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
```

**The fix:** grant data roles to people and teams, not upwards into system roles.

### 7c. Leak 3: The orphan row

```sql
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
```

**The fix:** this one is a decision, not a setting. Someone has to own customers with no region. Fix it at the source by assigning every customer a region, or write an explicit rule for unassigned customers.

### 7d. A common mistake: created but not attached

```sql
-- GOAL: Catch the mistake of creating a policy and never attaching it.
-- WHY:  A policy that is created but not attached protects nothing. The query runs, and
--       the real values come back. Compare this output with what you think you built.
-- EXPECT: one ROW_ACCESS_POLICY row for REGION, plus MASKING_POLICY rows for EMAIL and PHONE.
USE ROLE ACCOUNTADMIN;

SELECT *
FROM TABLE(sales_db.INFORMATION_SCHEMA.POLICY_REFERENCES(
       REF_ENTITY_NAME   => 'sales_db.crm.customers',
       REF_ENTITY_DOMAIN => 'TABLE'));
```

---

## Part 8: Reset or clean up

### Reset the policies only

Use this to run the demo again from Part 3.

```sql
-- GOAL: Remove the policies from the table so you can re-run Parts 3 to 6.
-- WHY:  A policy must be detached from the table before it can be dropped.
USE ROLE ACCOUNTADMIN;

ALTER TABLE sales_db.crm.customers DROP ROW ACCESS POLICY sales_db.governance.region_rap;
ALTER TABLE sales_db.crm.customers MODIFY COLUMN email UNSET MASKING POLICY;
ALTER TABLE sales_db.crm.customers MODIFY COLUMN phone UNSET MASKING POLICY;

DROP ROW ACCESS POLICY IF EXISTS sales_db.governance.region_rap;
DROP MASKING POLICY    IF EXISTS sales_db.governance.email_mask;
DROP MASKING POLICY    IF EXISTS sales_db.governance.phone_mask;
```

### Remove everything

```sql
-- GOAL: Delete everything this script created.
-- WARNING: this permanently deletes the sales_db database, its data and the roles below.
USE ROLE ACCOUNTADMIN;

DROP DATABASE IF EXISTS sales_db;
DROP ROLE IF EXISTS sales_emea;
DROP ROLE IF EXISTS sales_apac;
DROP ROLE IF EXISTS sales_amer;
DROP ROLE IF EXISTS global_analytics;
DROP ROLE IF EXISTS crm_reader;
```

---

## Troubleshooting

| What you see | Likely cause | What to do |
| --- | --- | --- |
| "No active warehouse" after `USE ROLE` | The role has no `USAGE` on the warehouse | Re-run the warehouse grant in Part 2 |
| `USE ROLE sales_emea` fails | The role was not granted to your user | Re-run the four `GRANT ROLE ... TO USER` lines in Part 2 with your username |
| A salesperson sees all 12 rows after Part 4 | Secondary roles are on, or the policy was never attached | Run `USE SECONDARY ROLES NONE`, then the check in Part 5, Step 3 |
| Emails are not masked | The masking policy was created but not attached | Run the two `ALTER TABLE ... SET MASKING POLICY` statements in Part 5, Step 2 |
| "Already attached" on an `ALTER TABLE` | That policy is already in place | Carry on |
| Policy statements fail on creation | Your account is on Standard Edition | Row access and masking policies need Enterprise Edition or higher |

## Notes

- This is a teaching example on a small sample dataset. Test any security design as every role before you rely on it, including admin roles, and review it against your own organisation's requirements.
- The customer data is made up. The `.example` email domains are reserved for examples and do not receive mail.
- Policy behaviour can change between Snowflake releases. If something differs from what is written here, check the current Snowflake documentation for row access policies and masking policies.
