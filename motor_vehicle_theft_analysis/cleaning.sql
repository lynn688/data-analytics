-- Active: 1795463465638@@127.0.0.1@3306

select * from stolen_vehicles limit 10;
--location id is stored as text
select * from locations limit 10;

select * from make_details limit 10;

-- count everything in the tables 
SELECT 'vehicles' AS table_name, COUNT(*) AS total_rows FROM stolen_vehicles
UNION ALL SELECT 'locations', COUNT(*) FROM locations
UNION ALL SELECT 'make_details', COUNT(*) FROM make_details;
