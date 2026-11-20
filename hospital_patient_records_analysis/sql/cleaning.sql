-- HOSPITAL PATIENT RECORDS: CLEANING
-- Database: MySQL (hospital_db)
-- The original tables (patients, encounters, procedures, payers, organizations) are never edited.
-- Cleaning is done in views, so the raw data is always still there.

USE hospital_db;


-- STEP 1: CHECK THE DATA BEFORE CHANGING ANYTHING

-- 1a. How many rows are in each table?
-- expect: payers 10, patients 974, procedures 47701, encounters 27891
SELECT 'payers' AS table_name, COUNT(*) AS total_rows FROM payers
UNION ALL SELECT 'patients', COUNT(*) FROM patients
UNION ALL SELECT 'procedures', COUNT(*) FROM procedures
UNION ALL SELECT 'encounters', COUNT(*) FROM encounters;

-- 1b. Does every ID appear only once? A duplicate ID would double count rows.
-- expect: 0 for each
SELECT (SELECT COUNT(*) - COUNT(DISTINCT Id) FROM patients)   AS duplicate_patients,
       (SELECT COUNT(*) - COUNT(DISTINCT Id) FROM encounters) AS duplicate_encounters,
       (SELECT COUNT(*) - COUNT(DISTINCT Id) FROM payers)     AS duplicate_payers;

-- 1c. Does every encounter and procedure point to a row that exists?
-- A broken link means a row silently disappears when tables are joined.
-- expect: 0 for each
SELECT (SELECT COUNT(*) FROM encounters e LEFT JOIN patients p ON p.Id = e.PATIENT WHERE p.Id IS NULL)
           AS encounters_without_patient,
       (SELECT COUNT(*) FROM encounters e LEFT JOIN payers y ON y.Id = e.PAYER WHERE y.Id IS NULL)
           AS encounters_without_payer,
       (SELECT COUNT(*) FROM procedures x LEFT JOIN encounters e ON e.Id = x.ENCOUNTER WHERE e.Id IS NULL)
           AS procedures_without_encounter;

-- 1d. Do the dates make sense? An encounter cannot end before it starts.
-- expect: 0 rows ending early, dates from 2011-01-02 to 2022-02-05
SELECT SUM(`STOP` < `START`) AS ends_before_start,
       MIN(`START`) AS first_encounter,
       MAX(`START`) AS last_encounter
FROM encounters;

-- 1e. Do the costs make sense?
-- expect: 0 negative costs, 0 where coverage is bigger than the claim, 89 zero-cost encounters
SELECT SUM(BASE_ENCOUNTER_COST < 0 OR TOTAL_CLAIM_COST < 0 OR PAYER_COVERAGE < 0) AS negative_costs,
       SUM(PAYER_COVERAGE > TOTAL_CLAIM_COST) AS coverage_above_claim,
       SUM(TOTAL_CLAIM_COST = 0) AS zero_cost_encounters
FROM encounters;

-- The 89 zero-cost encounters are things like death certification and hospice admission.
-- They are real events with no charge, so they are kept and flagged, not deleted.
SELECT DESCRIPTION, COUNT(*) AS encounters
FROM encounters
WHERE TOTAL_CLAIM_COST = 0
GROUP BY DESCRIPTION
ORDER BY encounters DESC;

-- 1f. How long do encounters last?
-- expect: 75 last longer than 24 hours, 1077 last exactly 24 hours
SELECT SUM(TIMESTAMPDIFF(SECOND, `START`, `STOP`) > 86400)  AS longer_than_24h,
       SUM(TIMESTAMPDIFF(SECOND, `START`, `STOP`) = 86400)  AS exactly_24h,
       MAX(TIMESTAMPDIFF(DAY, `START`, `STOP`))             AS longest_days
FROM encounters;

-- 1g. Which columns have missing values?
-- A missing reason is normal: it means the visit was not for a specific condition.
-- expect: 19541 missing reasons, 1 missing marital status
SELECT COUNT(*) - COUNT(REASONCODE) AS encounters_without_reason,
       (SELECT COUNT(*) FROM patients WHERE MARITAL IS NULL OR MARITAL = '') AS patients_without_marital_status
FROM encounters;


-- STEP 2: BUILD THE CLEAN VIEWS

-- 2a. Patients
-- Names in this data have numbers added to them (like Nikita578), so the digits are removed.
-- Codes like M and F are replaced with readable words.
-- Age is worked out at the date of death, or at 2022-02-05 (the last date in the data) for living patients.
DROP VIEW IF EXISTS v_patients_clean;

CREATE VIEW v_patients_clean AS
SELECT
    patient_id,
    first_name,
    last_name,
    birth_date,
    death_date,
    CASE WHEN death_date IS NULL THEN 0 ELSE 1 END AS is_deceased,
    age,
    CASE WHEN age < 30 THEN 'Under 30'
         WHEN age < 45 THEN '30-44'
         WHEN age < 60 THEN '45-59'
         WHEN age < 75 THEN '60-74'
         ELSE '75+'
    END AS age_group,
    gender,
    marital_status,
    race,
    ethnicity,
    city,
    county,
    zip
FROM (
    SELECT
        Id AS patient_id,
        TRIM(REGEXP_REPLACE(`FIRST`, '[0-9]+', '')) AS first_name,
        TRIM(REGEXP_REPLACE(`LAST`, '[0-9]+', ''))  AS last_name,
        BIRTHDATE AS birth_date,
        DEATHDATE AS death_date,
        TIMESTAMPDIFF(YEAR, BIRTHDATE, COALESCE(DEATHDATE, '2022-02-05')) AS age,
        CASE GENDER WHEN 'M' THEN 'Male' WHEN 'F' THEN 'Female' ELSE 'Unknown' END AS gender,
        CASE MARITAL WHEN 'M' THEN 'Married' WHEN 'S' THEN 'Single' ELSE 'Unknown' END AS marital_status,
        CONCAT(UPPER(LEFT(RACE, 1)), SUBSTRING(RACE, 2)) AS race,
        CASE ETHNICITY WHEN 'hispanic' THEN 'Hispanic' WHEN 'nonhispanic' THEN 'Non-Hispanic' ELSE 'Unknown' END AS ethnicity,
        CITY AS city,
        COUNTY AS county,
        ZIP AS zip
    FROM patients
) p;


-- 2b. Encounters
-- This is the main table. It adds the year and quarter, how long the stay was, the payer name,
-- how much the patient paid, and whether the encounter came within 30 days of the previous one.
-- To find the previous encounter, each patient's encounters are put in date order and
-- LAG() looks at the end time of the one before.
-- A stay is "over 24 hours" only if it lasts longer than 24 hours (exactly 24 hours is not over).
DROP VIEW IF EXISTS v_encounters_clean;

CREATE VIEW v_encounters_clean AS
WITH enc AS (
    SELECT
        e.Id AS encounter_id,
        e.PATIENT AS patient_id,
        e.`START` AS start_time,
        e.`STOP` AS stop_time,
        e.PAYER AS payer_id,
        e.ENCOUNTERCLASS AS class_code,
        e.DESCRIPTION AS description,
        e.REASONDESCRIPTION AS reason,
        e.BASE_ENCOUNTER_COST AS base_cost,
        e.TOTAL_CLAIM_COST AS total_claim_cost,
        e.PAYER_COVERAGE AS payer_coverage,
        LAG(e.`STOP`) OVER (PARTITION BY e.PATIENT ORDER BY e.`START`, e.`STOP`, e.Id) AS previous_stop
    FROM encounters e
)
SELECT
    enc.encounter_id,
    enc.patient_id,
    enc.start_time,
    DATE(enc.start_time) AS encounter_date,
    YEAR(enc.start_time) AS encounter_year,
    QUARTER(enc.start_time) AS encounter_quarter,
    CONCAT(YEAR(enc.start_time), ' Q', QUARTER(enc.start_time)) AS year_quarter,
    enc.stop_time,
    CASE enc.class_code WHEN 'urgentcare' THEN 'Urgent care'
         ELSE CONCAT(UPPER(LEFT(enc.class_code, 1)), SUBSTRING(enc.class_code, 2))
    END AS encounter_class,
    TRIM(REGEXP_REPLACE(enc.description, '\\s*\\([a-z/ ]+\\)$', '')) AS encounter_type,
    TRIM(REGEXP_REPLACE(enc.reason, '\\s*\\([a-z/ ]+\\)$', '')) AS reason,
    ROUND(TIMESTAMPDIFF(SECOND, enc.start_time, enc.stop_time) / 3600, 2) AS duration_hours,
    CASE WHEN TIMESTAMPDIFF(SECOND, enc.start_time, enc.stop_time) > 86400
         THEN 'Over 24 hours' ELSE '24 hours or less'
    END AS stay_length,
    CASE WHEN y.NAME = 'NO_INSURANCE' THEN 'No insurance' ELSE y.NAME END AS payer_name,
    enc.base_cost,
    enc.total_claim_cost,
    enc.payer_coverage,
    ROUND(enc.total_claim_cost - enc.payer_coverage, 2) AS patient_paid,
    CASE WHEN enc.payer_coverage = 0 THEN 1 ELSE 0 END AS is_zero_coverage,
    CASE WHEN enc.total_claim_cost = 0 THEN 1 ELSE 0 END AS is_zero_cost,
    ROUND(TIMESTAMPDIFF(SECOND, enc.previous_stop, enc.start_time) / 86400, 1) AS days_since_previous_encounter,
    CASE WHEN enc.previous_stop IS NOT NULL
          AND TIMESTAMPDIFF(SECOND, enc.previous_stop, enc.start_time) BETWEEN 0 AND 2592000
         THEN 1 ELSE 0
    END AS is_readmission_30d
FROM enc
LEFT JOIN payers y ON y.Id = enc.payer_id;


-- 2c. Procedures
-- Descriptions end with a medical tag like (procedure). The tag is removed so charts read cleanly.
DROP VIEW IF EXISTS v_procedures_clean;

CREATE VIEW v_procedures_clean AS
SELECT
    ENCOUNTER AS encounter_id,
    PATIENT AS patient_id,
    `START` AS start_time,
    `STOP` AS stop_time,
    CODE AS procedure_code,
    TRIM(REGEXP_REPLACE(DESCRIPTION, '\\s*\\([a-z/ ]+\\)$', '')) AS procedure_name,
    BASE_COST AS base_cost,
    TRIM(REGEXP_REPLACE(REASONDESCRIPTION, '\\s*\\([a-z/ ]+\\)$', '')) AS reason
FROM procedures;


-- STEP 3: CHECK THE CLEAN VIEWS

-- 3a. No rows lost
-- expect: 974, 27891, 47701
SELECT (SELECT COUNT(*) FROM v_patients_clean)   AS patients,
       (SELECT COUNT(*) FROM v_encounters_clean) AS encounters,
       (SELECT COUNT(*) FROM v_procedures_clean) AS procedures;

-- 3b. Every encounter has a patient and a payer name
-- expect: 0 and 0
SELECT (SELECT COUNT(*) FROM v_encounters_clean e LEFT JOIN v_patients_clean p ON p.patient_id = e.patient_id WHERE p.patient_id IS NULL) AS no_patient,
       (SELECT COUNT(*) FROM v_encounters_clean WHERE payer_name IS NULL) AS no_payer;

-- 3c. The readable labels worked
-- expect: six encounter classes, three marital statuses, 154 deceased patients
SELECT encounter_class, COUNT(*) AS encounters
FROM v_encounters_clean
GROUP BY encounter_class
ORDER BY encounters DESC;

SELECT marital_status, COUNT(*) AS patients FROM v_patients_clean GROUP BY marital_status;
SELECT SUM(is_deceased) AS deceased_patients FROM v_patients_clean;

-- 3d. Flags
-- expect: 13586 zero coverage, 89 zero cost, 75 over 24 hours
SELECT SUM(is_zero_coverage) AS zero_coverage,
       SUM(is_zero_cost) AS zero_cost,
       SUM(stay_length = 'Over 24 hours') AS over_24_hours,
       SUM(is_readmission_30d) AS encounters_within_30_days_of_previous
FROM v_encounters_clean;
