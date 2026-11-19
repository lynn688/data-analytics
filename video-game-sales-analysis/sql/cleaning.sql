-- Active: 1793036160435@@127.0.0.1@3306

-- PROFILE THE RAW DATA 

--see the contents of the raw data and its various columns
select *from vgchartz_raw limit 1000;
select count(*) from vgchartz_raw;
--see the total number of records with null values for diffrent columns 
--45094 records have no total sales,  57338 records have no critic score,  7051 records have no release date,  8842 records have no publisher,  4435 records have no developer
select sum(total_sales is null) as no_total_sales,
        sum(critic_score is null) as no_critics_score,
        sum(release_date is null) as no_release_date,
        sum(publisher is 'Unknown') as no_publisher,
        sum(developer is 'Unknown') as no_developer
from vgchartz_raw;

--see the diffrent genres and consoles
select genre, count(*) as genre_count from vgchartz_raw group by genre order by genre_count desc;
select console, count(*) as console_count from vgchartz_raw group by console order by console_count desc;


--CLEANING THE DATA

--create a new table so the original data remains untouched  with only the columns that are needed for the analysis
--1.drop columns that are not needed for the analysis
--2.trim stray spaces 
--3.replace the placeholder unkown with  null in publisher and developer columns 
--4. extract release year from release date column and create a new column for release year
--5.create flags
--6.make clean title column by

create table chartz_cleaned as
select r.rowid as raw_id,trim(r.title) as title,
case when lower(r.title) like '%sales)%' and instr(r.title, '(') > 1
then trim(substr(r.title, 1, instr(r.title, '(') - 1))
else trim(r.title)
end as clean_title,
trim(r.console) as console,trim(r.genre) as genre,nullif(trim(r.publisher), 'Unknown') as publisher,
nullif(trim(r.developer), 'Unknown') as developer,
r.critic_score,r.total_sales,r.na_sales,r.jp_sales,r.pal_sales,r.other_sales,r.release_date,
cast(substr(r.release_date, 1, 4) as integer) as release_year,
case when lower(r.title) like '%sales)%' then 1 else 0 end as partial_record,
case when r.total_sales is not null then 1 else 0 end as has_total_sales,
case when r.release_date >'2024-06-10' then 1 else 0 end as future_release
from vgchartz_raw r;

select * from chartz_cleaned limit 1000;


-- we create another tabke where we have gottent rid of duplicates 
--which in our case will be the same title and console combination, we will keep the record with the most total sales,
-- if there are multiple records with the same total sales we will keep the one with the highest critic score
-- if there are still multiple records we will keep the one with a publisher,
-- if there are still multiple records we will keep the one with a release date, if there are still multiple records we will keep the one with the lowest raw_id

CREATE TABLE vgchartz_clean AS
SELECT
    raw_id, title, clean_title, console, genre, publisher, developer,
    critic_score, total_sales, na_sales, jp_sales, pal_sales, other_sales,
    release_date, release_year,
    partial_record, future_release, has_total_sales
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY title, console
               ORDER BY (total_sales IS NOT NULL) DESC,
                        total_sales DESC,
                        (critic_score IS NOT NULL) DESC,
                        (publisher IS NOT NULL) DESC,
                        (release_date IS NOT NULL) DESC,
                        raw_id
           ) AS rn
    FROM chartz_cleaned
)
WHERE rn = 1;

drop table chartz_cleaned;

select * from vgchartz_clean limit 1000;


-- Expected: how many unique title + console pairs exist in the raw data
SELECT COUNT(*) AS expected_rows
FROM (SELECT DISTINCT TRIM(title), TRIM(console) FROM vgchartz_raw);

-- Actual: what the cleaning produced
SELECT COUNT(*) AS actual_rows FROM vgchartz_clean;


-- we create a view from our cleaned data so that we can easily access it for analysis
-- for the analysis we will use only rowas that have total sales values,no partial records,and were released before the data was collected on 2024-06-10
CREATE VIEW sales_analysis AS
SELECT *
FROM vgchartz_clean
WHERE has_total_sales = 1
  AND partial_record = 0
  AND future_release = 0;


-- we check whether the number of rows match after getting rid of the duplicates
-- Expected: how many unique title + console pairs exist in the raw data
SELECT COUNT(*) AS expected_rows
FROM (SELECT DISTINCT TRIM(title), TRIM(console) FROM vgchartz_raw);

-- Actual: what the cleaning produced
SELECT COUNT(*) AS actual_rows FROM vgchartz_clean;