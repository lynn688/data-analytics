-- Active: 1795463465638@@127.0.0.1@3306


select name,sql
from sqlite_master
where type='table';
--location id is stored as text
select * from locations limit 10;


-- check size and shape of data in the tables 

select name,sql
from sqlite_master
where type='table';
--primary key is make_id in make_details table,vehicle_id in stolen_vehicles table and location_id in locations table
-- the make id is also in stolen vehicles table which can be used to join the two tables together to get the make name for each stolen vehicle
-- the location id is also in stolen vehicles table which can be used to join the two tables together to get the location name for each stolen vehicle
-- but the location id is stored as text in the locations table and as integer in the stolen vehicles table which will cause issues when joining the two tables together. So we need to convert the location id in the locations table to integer before joining the two tables together.
SELECT COUNT(*) FROM stolen_vehicles;   -- 4524
SELECT COUNT(*) FROM locations;         -- 16
SELECT COUNT(*) FROM make_details;      -- 138


--check the contents of the table ,the frequency of vehicle type,make id etc
select * from stolen_vehicles limit 10;
-- the location id is text which we will change to integer
select location_id,count(*) as frequency from stolen_vehicles
group by 1
order by 2 desc; 
--make id 619 has the most records,vehicle type is station wagon has 944 records,model year 2005 has 346 records,
--color silver has 1269 records ,date stolen 2022-04-04 had 83 records ,location id 102 has 1628 records

SELECT MIN(date_stolen), MAX(date_stolen) FROM stolen_vehicles; -- data is for a period of 6 months
--earliest recorded date is 2021-10-07 and latest 2022-04-06
select * from make_details ;
--some make names are the same but written abit diffrent eg land rover and landrover,toyota and toyota lexus,lexus
--i also noticed some of the make names are actually vehicle types instead of actual make names eg trailer,tractor etc
select * from make_details where make_name in (select vehicle_type from stolen_vehicles);

select * from locations limit 10;
-- the location table has 16 records 

-- check for missing or null values in the tables
--lets get the count of the null values in each column of the stolen_vehicles table
select sum(vehicle_type is null) as null_vehicle_type,
sum(make_id is null) as null_make_id,
sum(model_year is null) as null_model_year,
sum(vehicle_desc is null) as null_vehicle_desc,
sum(color is null) as null_color,
sum(date_stolen is null) as null_date_stolen,
sum(location_id is null) as null_location_id
from stolen_vehicles;
--vehicle_type has 15 null values,make_id has 15 null values,model_year has 15 null values,
--vehicle_desc has 15 null values,color has 15 null values,date_stolen has 0 null values,location_id has 0 null values


-- lets retrieve the records with null values in any of the columns of the stolen_vehicles table
select * from stolen_vehicles where 
vehicle_type is null or make_id is null or model_year is null 
or vehicle_desc is null or color is null or date_stolen is null 
or location_id is null;
--several rows have null values ,we will replace the null values with 'unknown' for the text data type columns so they can be grouped on their own for analysis
-- and the int data type columns will remain as null

--FIND DUPLICATES
-- either of these queries can be used to find duplicates in the stolen_vehicles table
select vehicle_type,make_id,model_year,vehicle_desc,color,date_stolen,location_id,count(*)
from stolen_vehicles
group by 1,2,3,4,5,6,7
having count(*) > 1;

with duplicates as (
select *,count(*) over (partition by vehicle_type,make_id,model_year,vehicle_desc,color,date_stolen,location_id) as copies, 
row_number() over(partition by vehicle_type,make_id,model_year,vehicle_desc,color,date_stolen,location_id) as rn
from stolen_vehicles
)
select * from duplicates where copies > 1;

--there are 14 rows that are duplicated in the stolen vehicles table

-- finding typos 
select vehicle_desc,count(*)
from stolen_vehicles
group by 1
order by 2 desc;
select color,count(*)
from stolen_vehicles
group by 1
order by 2 desc;

-- finding odd and impossible values 
select * from stolen_vehicles
where model_year < 1950;
--check if there are any records with model year greater than the year of the date stolen
select * from stolen_vehicles
where model_year > cast (strftime('%Y', date_stolen)as integer);

 --MAKE DETAILS
select * from make_details ;
select * from make_details where make_name in (select vehicle_desc from stolen_vehicles);
-- there are 5 make names that are actually vehicle types instead of actual make names
-- some others like factory built,home built are also not make names 
-- i also found a make name that is actually a vehicle desc in stolen vehicles table

-- we normalize make names that are the same but probaly spelled diff 
select lower(replace(replace(make_name, ' ', ''), '-', '')) as normalised,
       count(*) as n
from make_details
group by 1
having count(*) > 1;
-- we get landrover 

-- were checking values in the make name column that seem to represent  the same make  but are written diffrently
select * from make_details
where make_name like '%Lexus%' or make_name like '%Fuso%'
   or make_name like '%Nissan%' or make_name like '%Rover%'
order by make_name;

--land rover ,rover and landrover,fuso and mitsubishi fuso,lexus and toyota lexus,nissan and nissan diesel
-- we determine that nissan diesel and nissan are two diffrent makes ,and also rover is totally diffrent from landrover so we leave those alone 
-- we check the count of vehicles for the reszt of the makes before we decide on merging
select m.make_id, m.make_name, count(s.vehicle_id) as thefts
from make_details m
left join stolen_vehicles s on s.make_id = m.make_id
where m.make_id in (568, 569, 570, 620, 543, 581)
group by 1, 2;


-- we create a view where we merged the make names ,replaced the make names 
--that had vehicle types,vehicle desc and other descriptions instead of make names  with not manufacturer

create view make_details_cleaned as
select
    make_id,
    make_name as original_make_name,
    case make_id
        when 569 then 'Land Rover'
        when 620 then 'Lexus'
        when 581 then 'Fuso'
        else make_name
    end as make_name,
    make_type,
    case
        when make_id in (519, 538, 549, 582, 585, 621, 623, 624)
            then 'Not a manufacturer'
        else 'Manufacturer'
    end as make_category
from make_details;

select * from make_details_cleaned;

select count(*) from stolen_vehicles where vehicle_id between 4510 and 4538;


-- we create a view where we have removed the duplicates,replaced the nulls with unknown where necessary,
--changed the data type for location id to int to be able to join with location table during analysis
create view vehicles_cleaned as
with ranked as (
    select *,
           row_number() over (
               partition by vehicle_type, make_id, model_year, vehicle_desc,
                            color, date_stolen, location_id
               order by vehicle_id
           ) as rn
    from stolen_vehicles
)
select
    vehicle_id,
    coalesce(vehicle_type, 'Unknown') as vehicle_type,
    make_id,
    model_year,
    coalesce(vehicle_desc, 'Unknown') as vehicle_desc,
    coalesce(color, 'Unknown')        as color,
    date_stolen,
    cast(location_id as integer)      as location_id
from ranked
where rn = 1;
select * from vehicles_cleaned ;

--MAKE DETAILS

