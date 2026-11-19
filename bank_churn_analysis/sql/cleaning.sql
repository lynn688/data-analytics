-- Active: 1794225778658@@127.0.0.1@3306
select *
from churn_data
limit 10
;

--1.lets check for duplicates
--lets check whether customer id is unique or not
-- the unique count of customer id should equal the total rows that is if theres no duplicates
select count(*) as total_customers,
count( distinct customerid) as unique_customers
from churn_data;

-- unique ids are 10000 and the total rows are 10001 meaning theres a duplicate customer id, lets find out which one is duplicated

with duplicates as (
select *,row_number() over(partition by customerid order by customerid) as row_num
from churn_data)

select *
from duplicates
where row_num > 1;

-- the duplicate customer id is 15628319, lets check the data for this customer id
select *
from churn_data
where customerid='15628319';

--2.lets profile the data 
--GENDER
select distinct Gender
from churn_data;
-- we only have female and male 

select count(*) as total_customers,Gender
from churn_data
group by Gender;

--GEOGRAPHY
select distinct geography
from churn_data;
--we have france,french and fra which represent the same thing
-- and should all be labelled as one ,we also have spain and gremany

--CREDITSCORE
select min(creditscore) as min_credit_score,max(creditscore) as max_credit_score,round(avg(creditscore),2) as avg_credit_score
from churn_data;

--min:350,max:850,avg:650.54

--AGE
select min(age) as min_age,max(age) as max_age,round(avg(age),0) as avg_age
from churn_data;

--min:18,max:92,avg:39

--TENURE
select min(tenure) as min_tenure,max(tenure) as max_tenure,round(avg(tenure),2) as avg_tenure
from churn_data;

--min:0,max:10,avg:5.01

--ESTIMATEDSALARY
select min(estimatedsalary) as min_estimated_salary,max(estimatedsalary) as max_estimated_salary
from churn_data;
--min:-999999,max:99984
--we cant find avg salary since the column is text type, we will do that in the new table after we clean it up

-- exact match on the text
SELECT * FROM churn_data WHERE estimatedsalary = '-€999999';
--these values are negative and we need to turn them into nulls ,also we will get rid of 
--the pound sign and convert the column from text to real type 

--lets check for nulls in the data
-- this is the best way count(*) includes nulls and count(column_name) excludes nulls, so if we subtract the two we will get the number of nulls in that column
SELECT COUNT(*)                         AS total_rows,
       COUNT(*) - COUNT(customerid)     AS customerid_nulls,
       COUNT(*) - COUNT(surname)        AS surname_nulls,
       COUNT(*) - COUNT(creditscore)    AS creditscore_nulls,
       COUNT(*) - COUNT(geography)      AS geography_nulls,
       COUNT(*) - COUNT(gender)         AS gender_nulls,
       COUNT(*) - COUNT(age)            AS age_nulls,
       COUNT(*) - COUNT(tenure)         AS tenure_nulls,
       COUNT(*) - COUNT(estimatedsalary) AS salary_nulls
FROM churn_data;

-- 0 nulls in credit score ,3 nulls in age ,0 nulls in geography, 0 nulls in gender, 0 nulls in tenure, 0 nulls in estimated salary, 0 nulls in balance, 0 nulls in num of products, 0 nulls in has credit card, 0 nulls in is active member, 0 nulls in exited

SELECT SUM(TRIM(surname) = '')   AS blank_surname,
       SUM(TRIM(geography) = '') AS blank_geography,
       SUM(TRIM(gender) = '')    AS blank_gender
FROM churn_data;


SELECT estimatedsalary,
       REPLACE(estimatedsalary, '€', '') AS salary_text
FROM churn_data
LIMIT 10;

SELECT CAST(REPLACE(estimatedsalary, '€', '') AS real(12,2)) AS salary
FROM churn_data;


SELECT NULLIF(CAST(REPLACE(estimatedsalary, '€', '') AS DECIMAL(12,2)), -999999) AS salary
FROM churn_data;


--finds the min,max and avg of the salary after getting rid of the pound sign and removing the placeholder negative values,and converting to decimal format
SELECT MIN(salary), MAX(salary), ROUND(AVG(salary), 2), COUNT(*) - COUNT(salary) AS nulls
FROM (
  SELECT NULLIF(CAST(REPLACE(estimatedsalary, '€', '') AS DECIMAL(12,2)), -999999) AS salary
  FROM churn_data
) t;

--lets check the second table 

select *from churn_messy
limit 10;

--check for duplicates in the second table
select count(*) as total_rows,count(distinct customerid) as unique_customers
from churn_messy;
--the total rows are 10002 and unique customers are 10000 meaning we have duplicates, lets find out which ones are duplicated

--finding the duplicates in the second table
with duplicates as (
select *,row_number() over(partition by customerid order by customerid) as row_num
from churn_messy);

select *
from duplicates
where row_num > 1;

-- the duplicate customer ids are 15628319 and 15634602, lets check the data for these customer ids
select *
from churn_messy
where customerid in ('15628319','15634602');

--the repeated rows have the same exact data as the original rows, so we can just remove the duplicates and keep the original rows

--lets find nulls in the second table
SELECT COUNT(*)                         AS total_rows,
       COUNT(*) - COUNT(customerid)     AS customerid_nulls,
       COUNT(*) - COUNT(NumOfProducts)    AS num_of_products_nulls,
       COUNT(*) - COUNT(HasCrCard)      AS has_cr_card_nulls,
       COUNT(*) - COUNT(IsActiveMember)         AS is_active_member_nulls,
       COUNT(*) - COUNT(Exited)            AS exited_nulls,
       COUNT(*) - COUNT(tenure)         AS tenure_nulls,
       COUNT(*) - COUNT(Balance) AS balance_nulls
FROM churn_messy;
--no null values for all columns 


--min,max in the second table
SELECT MIN(balance), MAX(balance), ROUND(AVG(balance), 2), COUNT(*) - COUNT(balance) AS nulls
FROM (
  SELECT CAST(REPLACE(balance, '€', '') AS DECIMAL(12,2)) AS balance
  FROM churn_messy
) t;
-- we find the avg by first converting the balance column from text to real type and then calculating the avg, we also find that there are no nulls in the balance column
-- we also removed the pound sign


-- CLEANING
-- Raw tables (churn_data, churn_messy) are left untouched; cleaning is done in views.

-- Customer table: remove duplicate, standardise geography, fix salary


CREATE VIEW v_customer_clean AS
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customerid ORDER BY customerid) AS row_num
    FROM churn_data
)
SELECT
    customerid,
    creditscore,
    CASE WHEN UPPER(TRIM(geography)) IN ('FRANCE', 'FRENCH', 'FRA') THEN 'France'
         ELSE TRIM(geography)
    END AS geography,
    gender,
    CAST(age AS SIGNED) AS age,
    tenure,
    -- strip the euro sign, convert to a number, turn the -999999 placeholder into NULL
    NULLIF(CAST(REPLACE(estimatedsalary, '€', '') AS DECIMAL(12,2)), -999999) AS estimated_salary
FROM ranked
WHERE row_num = 1;


-- Account table: remove duplicates, fix balance, convert Yes/No to 1/0
-- hascrcard is left out: it is identical to isactivemember in every row, so it can't be trusted


CREATE VIEW v_account_clean AS
WITH ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customerid ORDER BY customerid) AS row_num
    FROM churn_messy
)
SELECT
    customerid,
    tenure AS tenure_account,
    CAST(REPLACE(balance, '€', '') AS DECIMAL(12,2)) AS balance,
    numofproducts AS num_of_products,
    CASE WHEN LOWER(TRIM(isactivemember)) = 'yes' THEN 1
         WHEN LOWER(TRIM(isactivemember)) = 'no'  THEN 0
    END AS is_active_member,
    exited
FROM ranked
WHERE row_num = 1;


-- Final view: join the two clean tables and add grouping columns for analysis
-- The 3 customers with no age or salary are kept and flagged rather than deleted


CREATE VIEW v_churn_clean AS
SELECT
    c.customerid        AS customer_id,
    c.creditscore       AS credit_score,
    CASE WHEN c.creditscore < 580 THEN '1. Under 580'
         WHEN c.creditscore < 670 THEN '2. 580-669'
         WHEN c.creditscore < 740 THEN '3. 670-739'
         WHEN c.creditscore < 800 THEN '4. 740-799'
         ELSE '5. 800+'
    END                 AS credit_score_band,
    c.geography,
    c.gender,
    c.age,
    CASE WHEN c.age IS NULL THEN 'Unknown'
         WHEN c.age < 30 THEN '18-29'
         WHEN c.age < 40 THEN '30-39'
         WHEN c.age < 50 THEN '40-49'
         WHEN c.age < 60 THEN '50-59'
         ELSE '60+'
    END                 AS age_group,
    c.tenure,
    c.estimated_salary,
    a.balance,
    CASE WHEN a.balance = 0 THEN 'Zero balance' ELSE 'Has balance' END AS balance_status,
    a.num_of_products,
    a.is_active_member,
    a.exited,
    CASE WHEN c.age IS NULL OR c.estimated_salary IS NULL THEN 1 ELSE 0 END AS has_missing_data
FROM v_customer_clean c
JOIN v_account_clean a
  ON c.customerid = a.customerid;


-- VALIDATION

-- one row per customer (10000 / 10000)
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT customer_id) AS unique_customers
FROM v_churn_clean;

-- no customer lost in the join (0 and 0)
SELECT COUNT(*) AS in_customer_not_in_account
FROM v_customer_clean c
LEFT JOIN v_account_clean a ON c.customerid = a.customerid
WHERE a.customerid IS NULL;

SELECT COUNT(*) AS in_account_not_in_customer
FROM v_account_clean a
LEFT JOIN v_customer_clean c ON c.customerid = a.customerid
WHERE c.customerid IS NULL;

-- tenure agrees between the two tables (0)
SELECT COUNT(*) AS tenure_mismatches
FROM v_customer_clean c
JOIN v_account_clean a ON c.customerid = a.customerid
WHERE c.tenure <> a.tenure_account;

-- geography standardised (France, Germany, Spain)
SELECT DISTINCT geography
FROM v_churn_clean;

-- remaining nulls (3 in age, 3 in salary, none elsewhere)
SELECT COUNT(*) - COUNT(customer_id)      AS customer_id_nulls,
       COUNT(*) - COUNT(credit_score)     AS credit_score_nulls,
       COUNT(*) - COUNT(geography)        AS geography_nulls,
       COUNT(*) - COUNT(gender)           AS gender_nulls,
       COUNT(*) - COUNT(age)              AS age_nulls,
       COUNT(*) - COUNT(tenure)           AS tenure_nulls,
       COUNT(*) - COUNT(estimated_salary) AS salary_nulls,
       COUNT(*) - COUNT(balance)          AS balance_nulls,
       COUNT(*) - COUNT(num_of_products)  AS products_nulls,
       COUNT(*) - COUNT(is_active_member) AS active_nulls,
       COUNT(*) - COUNT(exited)           AS exited_nulls
FROM v_churn_clean;

-- salary and balance ranges (salary 11.58 to 199992.48, avg 100092.22; balance avg 76485.89)
SELECT MIN(estimated_salary) AS min_salary,
       MAX(estimated_salary) AS max_salary,
       ROUND(AVG(estimated_salary), 2) AS avg_salary,
       MIN(balance) AS min_balance,
       MAX(balance) AS max_balance,
       ROUND(AVG(balance), 2) AS avg_balance
FROM v_churn_clean;

-- baseline churn (2037 customers, 20.37%)
SELECT SUM(exited) AS customers_churned,
       COUNT(*) AS total_customers,
       ROUND(100.0 * SUM(exited) / COUNT(*), 2) AS churn_rate_pct
FROM v_churn_clean;

-- the flagged customers
SELECT *
FROM v_churn_clean
WHERE has_missing_data = 1;