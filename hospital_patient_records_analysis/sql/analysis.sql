-- HOSPITAL PATIENT RECORDS: ANALYSIS
-- Database: MySQL (hospital_db)
-- Uses the views built in hospital_cleaning.sql:
--   v_patients_clean, v_encounters_clean, v_procedures_clean
-- One row in v_encounters_clean is one hospital encounter.

USE hospital_db;


-- OBJECTIVE 1: ENCOUNTERS OVERVIEW

-- 1a. How many encounters happened each year?
-- 2011 and 2022 are partial years (data runs from 2011-01-02 to 2022-02-05).
SELECT encounter_year,
       COUNT(*) AS total_encounters
FROM v_encounters_clean
GROUP BY encounter_year
ORDER BY encounter_year;

-- 1b. What share of each year's encounters does each encounter class make up?
SELECT encounter_year,
       encounter_class,
       COUNT(*) AS encounters,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY encounter_year), 1) AS pct_of_year
FROM v_encounters_clean
GROUP BY encounter_year, encounter_class
ORDER BY encounter_year, encounters DESC;

-- 1c. How many encounters lasted longer than 24 hours, and how many did not?
SELECT stay_length,
       COUNT(*) AS encounters,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_all
FROM v_encounters_clean
GROUP BY stay_length
ORDER BY encounters;

-- 1d. Which encounter classes have the long stays?
SELECT encounter_class,
       COUNT(*) AS encounters,
       SUM(stay_length = 'Over 24 hours') AS over_24_hours,
       ROUND(AVG(duration_hours), 1) AS avg_hours
FROM v_encounters_clean
GROUP BY encounter_class
ORDER BY encounters DESC;


-- OBJECTIVE 2: COST AND COVERAGE

-- 2a. How many encounters had no payer coverage, and what share is that?
SELECT SUM(is_zero_coverage) AS zero_coverage_encounters,
       COUNT(*) AS total_encounters,
       ROUND(100 * SUM(is_zero_coverage) / COUNT(*), 2) AS pct_zero_coverage
FROM v_encounters_clean;

-- 2b. What are the 10 most common procedures, and what does each cost on average?
SELECT procedure_name,
       COUNT(*) AS times_performed,
       ROUND(AVG(base_cost), 2) AS avg_base_cost
FROM v_procedures_clean
GROUP BY procedure_code, procedure_name
ORDER BY times_performed DESC, procedure_name
LIMIT 10;

-- 2c. What are the 10 procedures with the highest average base cost?
-- The count is shown because a high average built on a few cases is less reliable.
SELECT procedure_name,
       ROUND(AVG(base_cost), 2) AS avg_base_cost,
       COUNT(*) AS times_performed
FROM v_procedures_clean
GROUP BY procedure_code, procedure_name
ORDER BY avg_base_cost DESC
LIMIT 10;

-- 2d. What is the average total claim cost for each payer?
-- Includes how much of the claim each payer actually covers.
SELECT payer_name,
       COUNT(*) AS encounters,
       ROUND(AVG(total_claim_cost), 2) AS avg_claim_cost,
       ROUND(AVG(payer_coverage), 2) AS avg_covered,
       ROUND(100 * SUM(payer_coverage) / SUM(total_claim_cost), 1) AS pct_of_cost_covered
FROM v_encounters_clean
GROUP BY payer_name
ORDER BY avg_claim_cost DESC;

-- 2e. Is "no coverage" only a problem for uninsured patients?
SELECT payer_name,
       COUNT(*) AS encounters,
       SUM(is_zero_coverage) AS zero_coverage,
       ROUND(100 * SUM(is_zero_coverage) / COUNT(*), 1) AS pct_zero_coverage
FROM v_encounters_clean
GROUP BY payer_name
ORDER BY zero_coverage DESC;


-- OBJECTIVE 3: PATIENT BEHAVIOUR

-- 3a. How many different patients had an encounter in each quarter?
SELECT encounter_year,
       encounter_quarter,
       COUNT(DISTINCT patient_id) AS unique_patients
FROM v_encounters_clean
GROUP BY encounter_year, encounter_quarter
ORDER BY encounter_year, encounter_quarter;

-- 3a (inpatient only). The same count for hospital admissions only.
SELECT encounter_year,
       encounter_quarter,
       COUNT(DISTINCT patient_id) AS unique_inpatients
FROM v_encounters_clean
WHERE encounter_class = 'Inpatient'
GROUP BY encounter_year, encounter_quarter
ORDER BY encounter_year, encounter_quarter;

-- 3b. How many patients came back within 30 days of a previous encounter?
-- A return is an encounter that starts within 30 days after the end of the same patient's previous one.
SELECT COUNT(DISTINCT patient_id) AS patients_with_a_return,
       (SELECT COUNT(*) FROM v_patients_clean) AS total_patients,
       ROUND(100 * COUNT(DISTINCT patient_id) / (SELECT COUNT(*) FROM v_patients_clean), 1) AS pct_of_patients
FROM v_encounters_clean
WHERE is_readmission_30d = 1;

-- 3b (inpatient only). The stricter version: a patient admitted again as an inpatient
-- within 30 days of leaving a previous inpatient stay.
WITH inpatient AS (
    SELECT patient_id,
           start_time,
           LAG(stop_time) OVER (PARTITION BY patient_id ORDER BY start_time, stop_time) AS previous_stop
    FROM v_encounters_clean
    WHERE encounter_class = 'Inpatient'
)
SELECT COUNT(DISTINCT patient_id) AS patients_readmitted_to_hospital,
       COUNT(*) AS readmissions
FROM inpatient
WHERE previous_stop IS NOT NULL
  AND TIMESTAMPDIFF(SECOND, previous_stop, start_time) BETWEEN 0 AND 2592000;

-- 3c. Which patients had the most returns within 30 days?
SELECT p.patient_id,
       CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
       p.age,
       p.gender,
       COUNT(*) AS returns_within_30_days
FROM v_encounters_clean e
JOIN v_patients_clean p ON p.patient_id = e.patient_id
WHERE e.is_readmission_30d = 1
GROUP BY p.patient_id, p.first_name, p.last_name, p.age, p.gender
ORDER BY returns_within_30_days DESC, p.patient_id
LIMIT 10;


-- EXTRA QUESTIONS FOR THE DASHBOARD

-- E1. Cost and coverage by encounter class
SELECT encounter_class,
       COUNT(*) AS encounters,
       ROUND(AVG(total_claim_cost), 2) AS avg_claim_cost,
       ROUND(100 * SUM(payer_coverage) / SUM(total_claim_cost), 1) AS pct_of_cost_covered
FROM v_encounters_clean
GROUP BY encounter_class
ORDER BY avg_claim_cost DESC;

-- E2. Total cost, what payers covered and what patients paid, by year
SELECT encounter_year,
       ROUND(SUM(total_claim_cost), 0) AS total_claim_cost,
       ROUND(SUM(payer_coverage), 0) AS covered_by_payers,
       ROUND(SUM(patient_paid), 0) AS paid_by_patients,
       ROUND(100 * SUM(payer_coverage) / SUM(total_claim_cost), 1) AS pct_covered
FROM v_encounters_clean
GROUP BY encounter_year
ORDER BY encounter_year;

-- E3. The 10 most common reasons for an encounter
SELECT reason,
       COUNT(*) AS encounters
FROM v_encounters_clean
WHERE reason IS NOT NULL
GROUP BY reason
ORDER BY encounters DESC
LIMIT 10;

-- E4. Which age groups have the most encounters?
SELECT p.age_group,
       COUNT(DISTINCT p.patient_id) AS patients,
       COUNT(*) AS encounters,
       ROUND(COUNT(*) / COUNT(DISTINCT p.patient_id), 1) AS encounters_per_patient
FROM v_encounters_clean e
JOIN v_patients_clean p ON p.patient_id = e.patient_id
GROUP BY p.age_group
ORDER BY p.age_group;
