# Stolen Vehicles Analysis: New Zealand (Oct 2021 – Apr 2022)

> One-sentence summary of the project and its main takeaway.
>

---

## 1. Audience and Business Question

**Audience:** `[Regional police officers deciding where to focus vehicle theft prevention]`

**Decision this analysis supports:** `[Where to focus vehicle theft prevention effort first]`

**Business question:** `[Which vehicle types and regions are most at risk, and what should be prioritised?]`

**Key questions answered:**
1. What types of vehicles are stolen most often?
2. Which regions have the most thefts, and which have the highest rates per population?
3. How do thefts change over time (by month and day of week)?
4. Which makes, model years, and colours are over-represented?
5. `[Add or remove questions as the analysis develops]`

---

## 2. Key Findings and Recommendations



| # | Finding (with evidence) | So what? | Recommendation |
|---|---|---|---|
| 1 | `[e.g. Trailers make up X% of thefts]` | `[Why it matters]` | `[Specific action, who, where]` |
| 2 | `[Finding]` | `[Why it matters]` | `[Action]` |
| 3 | `[Finding]` | `[Why it matters]` | `[Action]` |

**How we will know it worked:** `[Metric to track, e.g. monthly trailer thefts in top regions vs baseline]`

---

## 3. Data

**Source:** `[Where the data came from, e.g. course dataset / police open data]`

**Database:** SQLite (`stolen_vehicles.db`)

| Table | Description | Rows | Key |
|---|---|---|---|
| `stolen_vehicles` | One row per reported stolen vehicle | 4,553 | `vehicle_id` |
| `locations` | NZ regions with population and density | 16 | `location_id` |
| `make_details` | Vehicle makes and type (Standard / Luxury) | 138 | `make_id` |

**Relationships**
- `stolen_vehicles.location_id` → `locations.location_id`
- `stolen_vehicles.make_id` → `make_details.make_id`

**Date range:** `[Earliest theft date]` to `[Latest theft date]` (about 6 months)

**Data dictionary**

| Column | Table | Meaning |
|---|---|---|
| `vehicle_id` | stolen_vehicles | Unique ID for each theft record |
| `vehicle_type` | stolen_vehicles | Category (Trailer, Roadbike, Saloon, ...) |
| `make_id` | stolen_vehicles | Links to `make_details` |
| `model_year` | stolen_vehicles | Year the vehicle was manufactured |
| `vehicle_desc` | stolen_vehicles | Free-text model description |
| `color` | stolen_vehicles | Vehicle colour |
| `date_stolen` | stolen_vehicles | Date of theft |
| `location_id` | stolen_vehicles | Links to `locations` |
| `region` | locations | NZ region name |
| `population` | locations | Region population |
| `density` | locations | Population density |
| `make_name` | make_details | Manufacturer name |
| `make_type` | make_details | Standard or Luxury |

---

## 4. Data Cleaning


| Issue found | How it was detected | Decision | Rows affected |
|---|---|---|---|
| `location_id` stored as text in `stolen_vehicles` | `typeof(location_id)` | Converted to INTEGER | `[n]` |
| Missing vehicle type, make, and description | `WHERE vehicle_type IS NULL` | `[Keep as "Unknown" / exclude from X analyses]` | `[n]` |
| Possible duplicate records (e.g. IDs 1262 and 1263) | Grouping on all columns except ID | `[Keep / remove, and why]` | `[n]` |
| Inconsistent categories (e.g. `Trailer` vs `Trailer - Heavy`) | `SELECT DISTINCT vehicle_type` | `[Keep separate / group, and why]` | `[n]` |
| Implausible model years (e.g. 1940 trailer) | `MIN(model_year)`, outlier check | `[Keep / flag]` | `[n]` |
| `[Add more]` | | | |

---

## 5. Analysis

SQL scripts are stored in `/sql`:

| File | Purpose |
|---|---|
| `01_create_database.sql` | Builds the tables and loads the data |
| `02_data_quality_checks.sql` | Counts, NULLs, duplicates, ranges |
| `03_cleaning.sql` | Cleaning steps documented above |
| `04_analysis.sql` | Queries answering the key questions |

**Approach**
- Compare regions using **rates per 100,000 people**, not raw counts.
- Segment by vehicle type, make, and time period.
- Check unusual results for data errors before reporting them.

**Results by question** 

### Q1. What is stolen most often?
`[Query summary, result table or chart, one-line takeaway]`

### Q2. Where do thefts happen?
`[Query summary, result table or chart, one-line takeaway]`

### Q3. When do thefts happen?
`[Query summary, result table or chart, one-line takeaway]`

### Q4. Which makes and ages are over-represented?
`[Query summary, result table or chart, one-line takeaway]`

---

## 6. Limitations

- Covers only about 6 months, so seasonality and long-term trends cannot be assessed.
- Contains **reported** thefts only; unreported thefts are missing.
- No data on recoveries, vehicle value, or time of day.
- Some records have missing type, make, or description.
- `[Add others as you discover them]`

---

## 7. How to Reproduce

1. Install SQLite (or use a SQLite extension in your editor).
2. Create the database:
   ```bash
   sqlite3 stolen_vehicles.db < sql/01_create_database.sql
   ```
3. Run the remaining scripts in order (`02`, `03`, `04`).
4. Verify the load:
   ```sql
   SELECT COUNT(*) FROM stolen_vehicles;  -- expect 4553
   SELECT COUNT(*) FROM locations;        -- expect 16
   SELECT COUNT(*) FROM make_details;     -- expect 138
   ```

---

## 8. Next Steps

- `[Extra data that would sharpen the answer, e.g. recovery rates, vehicle values]`
- `[Further questions raised by the analysis]`

---

## 9. Project Structure

```
.
├── README.md
├── data/
├── sql/
│   ├── 01_create_database.sql
│   ├── 02_data_quality_checks.sql
│   ├── 03_cleaning.sql
│   └── 04_analysis.sql
└── visuals/
```

## Author

`[Your name]` · `[Contact or portfolio link]`