
select * FROM v_churn_clean;


-- Q0: THE BASELINE. How many customers did the bank lose?
-- Finding: 2,037 of 10,000 customers left, a churn rate of 20.37 percent.

SELECT COUNT(*)                                  AS total_customers,
       SUM(exited)                               AS customers_churned,
       ROUND(100.0 * SUM(exited) / COUNT(*), 2)  AS churn_rate_pct
FROM v_churn_clean;



-- Q1: WHICH COUNTRY LOSES THE MOST CUSTOMERS?
-- Finding: Germany churns at 32.4 percent, about double France (16.2)
-- and Spain (16.7). Germany has only half as many customers as France
-- but almost the same number of leavers.

SELECT geography,
       COUNT(*)                                     AS customers,
       SUM(exited)                                  AS churned,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY geography
ORDER BY churn_rate_pct DESC;

-- Q1b: where do the lost customers come from? (share of all leavers)
-- Finding: Germany 40.0 percent, France 39.8, Spain 20.3.
SELECT geography,
       SUM(exited) AS churned,
       ROUND(100.0 * SUM(exited) / (SELECT SUM(exited) FROM v_churn_clean), 1) AS share_of_all_leavers_pct
FROM v_churn_clean
GROUP BY geography
ORDER BY churned DESC;



-- Q2: DO WOMEN AND MEN CHURN DIFFERENTLY?
-- Finding: women churn at 25.1 percent, men at 16.5.
-- The gap holds in every age group (see Q9).

SELECT gender,
       COUNT(*)                                     AS customers,
       SUM(exited)                                  AS churned,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY gender
ORDER BY churn_rate_pct DESC;



-- Q3: WHICH AGE GROUPS LEAVE?
-- Finding: churn rises sharply with age and peaks at 50-59 (56.0 percent).
-- Under 40 it is low (7.6 and 10.9 percent). Over 60 it falls back to 27.9.
-- Caution: "Unknown" is the 3 customers with no age. Ignore that row.

SELECT age_group,
       COUNT(*)                                     AS customers,
       SUM(exited)                                  AS churned,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY age_group
ORDER BY age_group;



-- Q4: DOES THE NUMBER OF PRODUCTS MATTER?
-- Finding: 2 products is the safest: only 7.6 percent leave.
--   1 product: 27.7 percent
--   3 products: 82.7 percent, 4 products: 100 percent
-- Caution: only 260 customers have 3 products and 60 have 4. The rates
-- are extreme but the groups are small, so describe them as "worth
-- investigating", not as a proven cause.

SELECT num_of_products,
       COUNT(*)                                     AS customers,
       SUM(exited)                                  AS churned,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY num_of_products
ORDER BY num_of_products;



-- Q5: DO INACTIVE MEMBERS LEAVE MORE?
-- is_active_member: 1 = active, 0 = inactive
-- Finding: inactive members churn at 26.9 percent, active ones at 14.3.
-- This is one of the few drivers the bank can act on.

SELECT is_active_member,
       COUNT(*)                                     AS customers,
       SUM(exited)                                  AS churned,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY is_active_member
ORDER BY is_active_member;



-- Q6: DOES HAVING MONEY IN THE ACCOUNT CHANGE THINGS?
-- Finding: customers with a balance churn at 24.1 percent, customers
-- with a zero balance at 13.8. About 36 percent of customers have a
-- zero balance, which is real data, not an error.

SELECT balance_status,
       COUNT(*)                                     AS customers,
       SUM(exited)                                  AS churned,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY balance_status
ORDER BY churn_rate_pct DESC;



-- Q7: IS GERMANY'S HIGH CHURN JUST A BALANCE EFFECT?
-- Germany has NO zero-balance customers, while about 48 percent of
-- France and Spain do. Zero-balance customers churn less (Q6), so we
-- must check that Germany is not simply "all customers have a balance".
-- Compare like with like: customers WITH a balance only.
-- Finding: among customers with a balance, Germany still churns at
--   32.4 percent against 18.2 (France) and 19.6 (Spain).
--   So balance does NOT explain the Germany gap.

SELECT geography,
       balance_status,
       COUNT(*)                                     AS customers,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY geography, balance_status
ORDER BY geography, balance_status;



-- Q8: WHAT DOES NOT MATTER?  (just as useful to report)
-- Credit score, salary and tenure show little or no pattern.
-- Finding: churn stays between about 18 and 22 percent across every
-- credit score band, and between 20 and 21.5 percent across salary
-- bands. Tenure moves between 17 and 23 percent with no clear trend.

-- Q8a: credit score
SELECT credit_score_band,
       COUNT(*)                                     AS customers,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY credit_score_band
ORDER BY credit_score_band;

-- Q8b: salary (3 customers have no salary and are shown as Unknown)
SELECT CASE WHEN estimated_salary IS NULL THEN 'Unknown'
            WHEN estimated_salary < 50000  THEN '1. Under 50k'
            WHEN estimated_salary < 100000 THEN '2. 50k-99k'
            WHEN estimated_salary < 150000 THEN '3. 100k-149k'
            ELSE '4. 150k+'
       END                                          AS salary_band,
       COUNT(*)                                     AS customers,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY salary_band
ORDER BY salary_band;

-- Q8c: tenure (years with the bank)
SELECT tenure,
       COUNT(*)                                     AS customers,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY tenure
ORDER BY tenure;



-- Q9: DOES THE GENDER GAP SURVIVE ONCE WE COMPARE SAME-AGE CUSTOMERS?
-- Finding: yes. Women churn more than men in every age group, for
-- example 36.1 vs 26.0 percent at 40-49 and 62.9 vs 49.6 at 50-59.
-- So the gender gap is not caused by women simply being older.

SELECT age_group,
       gender,
       COUNT(*)                                     AS customers,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
WHERE age_group <> 'Unknown'
GROUP BY age_group, gender
ORDER BY age_group, gender;



-- Q10: WHAT DOES THE AVERAGE LEAVER LOOK LIKE?
-- Finding: leavers are older (44.8 vs 37.4 years) and hold higher
-- balances (about 91,000 vs 73,000). Salary, credit score, number of
-- products and tenure are close to the same for both groups.

SELECT CASE WHEN exited = 1 THEN 'Churned' ELSE 'Stayed' END AS status,
       COUNT(*)                         AS customers,
       ROUND(AVG(age), 1)               AS avg_age,
       ROUND(AVG(balance), 0)           AS avg_balance,
       ROUND(AVG(estimated_salary), 0)  AS avg_salary,
       ROUND(AVG(credit_score), 0)      AS avg_credit_score,
       ROUND(AVG(num_of_products), 2)   AS avg_products,
       ROUND(AVG(tenure), 1)            AS avg_tenure
FROM v_churn_clean
GROUP BY exited
ORDER BY exited DESC;



-- Q11: WHICH GROUPS OF CUSTOMERS ARE AT THE HIGHEST RISK?
-- Combines three factors. HAVING COUNT(*) >= 50 drops small groups so
-- one unlucky handful of customers cannot top the list (same idea as the
-- 30-game minimum in the video games project).
-- Finding: INACTIVE customers aged 50 and over are the danger zone, with
-- churn between about 78 and 89 percent in every country. For example,
-- inactive 50-59 year olds in Germany: 146 customers, 86.3 percent left.
-- Active customers in the same age groups churn far less.

SELECT geography,
       age_group,
       is_active_member,
       COUNT(*)                                     AS customers,
       SUM(exited)                                  AS churned,
       ROUND(100.0 * SUM(exited) / COUNT(*), 1)     AS churn_rate_pct
FROM v_churn_clean
GROUP BY geography, age_group, is_active_member
HAVING COUNT(*) >= 50
ORDER BY churn_rate_pct DESC
LIMIT 10;


