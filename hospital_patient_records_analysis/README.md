# Hospital Patient Records Analysis

An analysis of patient encounters, procedures, and payer coverage using MySQL.
The SQL cleaning script creates views and leaves the source tables unchanged.

## Data

The supplied files in `data/raw/` contain:

| File | Rows |
|---|---:|
| `patients.csv` | 974 |
| `encounters.csv` | 27,891 |
| `procedures.csv` | 47,701 |
| `payers.csv` | 10 |
| `organizations.csv` | 1 |

`data_dictionary.csv` describes the source fields.

## Cleaning

[`sql/cleaning.sql`](sql/cleaning.sql) checks row counts, duplicate IDs, foreign-key links,
dates, costs, and missing values before creating three views:

- `v_patients_clean`: readable demographic labels, names without generated digits, age and age group
  (including an `Under 30` group for the two younger patients).
- `v_encounters_clean`: readable encounter labels, calendar fields, duration, patient-paid amount,
  coverage flags, and a 30-day return flag.
- `v_procedures_clean`: readable procedure and reason descriptions.

The raw tables are not modified. The supplied database setup script includes all 974 patients
and the organization row from the CSV files.

## Analysis

[`sql/analysis.sql`](sql/analysis.sql) queries encounter trends and lengths, costs and payer
coverage, common procedures, unique patients by quarter, and returns within 30 days.

## Reproduce

1. Use a disposable MySQL database environment. `sql/create_hospital_db.sql` starts with
   `DROP DATABASE IF EXISTS hospital_db`, so running it deletes and recreates that database.
2. Run `sql/create_hospital_db.sql`.
3. Run `sql/cleaning.sql`, then `sql/analysis.sql`.

The cleaning script uses MySQL 8 features, including common table expressions, window functions,
and `REGEXP_REPLACE`.
