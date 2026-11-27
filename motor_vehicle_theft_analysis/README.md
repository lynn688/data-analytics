# Stolen Vehicles Analysis: New Zealand (Oct 2021 to Apr 2022)

Work in progress. The data is loaded and cleaned, and the analysis is next.

---

## Audience and business question

**Audience:** Regional police officers deciding where to focus vehicle theft prevention.

**Decision:** Where to put prevention effort first.

**Business question:** Which vehicle types and regions are most at risk, and what should be prioritised?

Questions I want to answer along the way:

1. What types of vehicles are stolen most often?
2. Which regions have the most thefts, and which have the highest rate per population?
3. How do thefts change over time (by month and by day of week)?
4. Which makes, model years and colours show up more than others?

---

## Status

- [x] Load the data into SQLite
- [x] Check size, shape, nulls and duplicates
- [x] Clean `stolen_vehicles` (view)
- [x] Clean `make_details` (view)
- [] Look through `vehicle_desc` and `color` for typos
- [ ] Decide what to do with odd model years
- [ ] Analysis
- [ ] Findings and recommendations

---

## Findings and recommendations

Not done yet. I'll fill this in once the analysis is finished.

| # | Finding | Why it matters | Recommendation |
|---|---|---|---|
| 1 | TBD | | |

---

## Data

The data came as a MySQL script that creates and fills three tables. I'm using SQLite, so I removed the `DROP DATABASE`, `CREATE DATABASE` and `USE` lines at the top. Nothing else in the script was changed.

| Table | What it holds | Rows | Key |
|---|---|---|---|
| `stolen_vehicles` | One row per reported stolen vehicle | 4,524 | `vehicle_id` |
| `locations` | NZ regions with population and density | 16 | `location_id` |
| `make_details` | Vehicle makes and a Standard / Luxury label | 138 | `make_id` |

`stolen_vehicles` joins to `locations` on `location_id` and to `make_details` on `make_id`. Each region and each make can appear on many theft rows (one-to-many).

**Date range:** 2021-10-07 to 2022-04-06, so about six months.

### First look (raw table, before removing duplicates)

- Most common make: `make_id` 619 (Toyota)
- Most common vehicle type: Stationwagon, 944 records
- Most common model year: 2005, 346 records
- Most common colour: Silver, 1,269 records
- Busiest single day: 2022-04-04, 83 records
- Region with the most thefts: `location_id` 102 (Auckland), 1,628 records

These are plain counts and say nothing about rates yet. Auckland is also the biggest region by population, so I'll compare per 100,000 people before drawing any conclusion.

---

## Data cleaning

I didn't change the original tables. The cleaning lives in two views, and the analysis should use these instead of the raw tables:

- `vehicles_cleaned`
- `make_details_cleaned`

| Issue | How I found it | What I did | Rows |
|---|---|---|---|
| `location_id` stored as text in `stolen_vehicles` | Table definition in `sqlite_master` | Cast to integer in `vehicles_cleaned` so it joins to `locations` | All |
| Missing values in type, make, year, description and colour | `sum(column is null)` per column | Text columns set to `'Unknown'`. `make_id`, `model_year` and dates left as NULL so averages, date functions and joins still work | 15 |
| Duplicate records | `group by` and `row_number()` over every column except `vehicle_id` | Kept the lowest `vehicle_id` in each group | 14 |
| Same make spelled differently | Normalised names (lowercase, no spaces) plus a manual look | Merged by name in the view: Landrover to Land Rover, Toyota Lexus to Lexus, Mitsubishio Fuso to Fuso. IDs unchanged | 3 makes |
| Makes that are not real makes | Names that match a vehicle type, plus a manual look | Flagged as `Not a manufacturer`: Caravan, Factory Built, Homebuilt, Mobile Machine, Moped, Tractor, Trailer, Trike | 8 makes |
| Typos in `vehicle_desc` and `color` | Counts per value | Reviewed, still deciding | TBD |
| Odd model years (there is at least one 1940 trailer) | `model_year < 1950`, and model year later than the year stolen | Reviewed, no changes yet | TBD |

A few decisions I want to remember:

- Nissan and Nissan Diesel stay separate, and so do Rover and Land Rover. They are different makes.
- The duplicate rule treats NULLs as equal. Rows with only a date and a location filled in can collapse into one even if they were two different thefts. This is a small effect.
- Two identical records on the same day in the same region could be two real thefts. I'm treating them as duplicates anyway since there is nothing else to tell them apart.
- When I need make names, I use a `left join` to `make_details_cleaned` so rows with no `make_id` don't drop out.

---

## Analysis

Plan:

- Compare regions per 100,000 people, not raw counts
- Join from `locations` with a `left join` so regions with no thefts still appear
- Split by vehicle type, make and time period
- Leave out the `Not a manufacturer` makes when ranking makes, and say how many rows that leaves out
- Treat weekday patterns as reliable enough to look at, but not yearly seasonality (see limitations)

### Q1. What is stolen most often?
TODO

### Q2. Where do thefts happen?
TODO

### Q3. When do thefts happen?
TODO

### Q4. Which makes and model years show up most?
TODO

---

## Limitations

- Only about six months of data, so there is no full yearly cycle and I can't say anything about seasonality. The window also misses winter completely.
- October and April are partial months, so monthly totals for those two are lower than they should be.
- These are reported thefts only.
- No information on recoveries, vehicle value or time of day.
- 15 records have almost nothing filled in apart from the date and location.

---

## Files

| File | What it does |
|---|---|
| `create_stolen_vehicles_db.sql` | Creates the tables and loads the data |
| `data_cleaning.sql` | Exploration queries and the two cleaned views |

## Running it

1. Open or create a SQLite database (I use a SQLite extension in VS Code).
2. Run `create_stolen_vehicles_db.sql` once. Running it a second time will fail with a unique constraint error unless the tables are dropped first.
3. Run `data_cleaning.sql`.
4. Check the load:
   ```sql
   select count(*) from stolen_vehicles;
   select count(*) from locations;       -- 16
   select count(*) from make_details;    -- 138
   ```