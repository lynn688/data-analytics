select *from sales_analysis;

--GENRES AND CONSOLES
--which genre has the highest total sales and what is the total sales for each genre
 select genre,sum
 (total_sales) as total_sales
 from sales_analysis
 group by genre 
 order by total_sales desc;
 --sports(1,171.4Million), action(1,118.39Million), shooter(990.1Million), Misc(555.19Million), Racing(552.46Million),
 -- role-playing(420.06Million), platform(346.11Million),fighting(337.16Million),adventure(324.36Million), simulation(298.55Million), 
 -- action-adventure(148.49Million), puzzle(125.46Million),strategy(118.13Million), music(51.75Million),MMO(9.31Million),party(6.07Million), 
 --visual novel(5.78Million),sandbox(1.89Million),education(0.88Million),Board game(0.33Million)


--which genre has the highest average sales per game and what is the average sales per game for each genre  
select genre,count(*) as total_games,round(avg(total_sales),2) as avg_sales_per_game
 from sales_analysis
  group by genre
  having count(*)>30
   order by avg_sales_per_game desc;
   --shooter(0.67Million)  average sales per game

--which console has the highest total sales 
   select console,sum(total_sales) as total_sales
  from sales_analysis
    group by console
    order by sum(total_sales) desc;
    --ps2 has a total of 1007.99Million sales


--TRENDS OVER TIME
--how do the sales trend over the years, what is the total sales for each year
select release_year,sum(total_sales) as total_sales
from sales_analysis
where release_year is not null
group by release_year
order by release_year;
--the sales grow from the mid 1990s and peak around 2008
--NB:the collapse after 2018 is due to missing data not a market crash

--REGIONS
--total sales recorded for each region
-- we filter out rows where there are null values present and use the ones where all four regions have values 
-- in doing this we end up working with a total of 2,216 games 

SELECT COUNT(*)           AS games_in_sample,
       SUM(na_sales)      AS NorthAmerica,
       SUM(jp_sales)      AS Japan,
       SUM(pal_sales)     AS EuropeAfrica,
       SUM(other_sales)   AS Others
FROM sales_analysis
WHERE na_sales    IS NOT NULL
  AND jp_sales    IS NOT NULL
  AND pal_sales   IS NOT NULL
  AND other_sales IS NOT NULL;

  --NorthAmerica(1178.95Million),Japan(235.31Million),Europe and Africa(909.68Million),Others(311.68Million)

-- for each genre what share of its sales come from each region
 SELECT
    genre,
    COUNT(*) AS games,
    ROUND(100.0 * SUM(na_sales)    / SUM(na_sales + jp_sales + pal_sales + other_sales), 1) AS na_pct,
    ROUND(100.0 * SUM(jp_sales)    / SUM(na_sales + jp_sales + pal_sales + other_sales), 1) AS jp_pct,
    ROUND(100.0 * SUM(pal_sales)   / SUM(na_sales + jp_sales + pal_sales + other_sales), 1) AS pal_pct,
    ROUND(100.0 * SUM(other_sales) / SUM(na_sales + jp_sales + pal_sales + other_sales), 1) AS other_pct
FROM sales_analysis
WHERE na_sales IS NOT NULL
  AND jp_sales IS NOT NULL
  AND pal_sales IS NOT NULL
  AND other_sales IS NOT NULL
GROUP BY genre
HAVING COUNT(*) >= 30
ORDER BY games DESC;

--PUBLISHERS
--top 10 publishers by sales 
select publisher,count(*)as games,round(sum(total_sales),2) as total_sales,round(avg(total_sales),2) as avg_sales
from sales_analysis
where publisher is not null
group by publisher
order by total_sales desc
limit 10;
--activision(719.7),electronic arts(639.33),ea sports(482.53),ubisoft(460.55),thq(319.44),sony computer entertainment(304.97),rockstar games(236.78)

--how concenrated is the publisher market ?

with top10 as (
    SELECT publisher,sum(total_sales) as s
    from sales_analysis
    where publisher is not NULL
    group by publisher
    order by s DESC
    limit 10)

select round(sum(s),2) as top10_sales,
round((select sum(total_sales)
from sales_analysis
where publisher is not null),2
) as all_total_sales,
round(100*sum(s)/(select sum(total_sales)
from sales_analysis
where publisher is not null),2) as top10_share_pct

from top10

--the ten biggest publishers account for 56.74% of all the recored sales 
-- the publishers are liosted in the previous question above 

-- do higher critic scores mean higher sales 

select count(*) as games,round(avg(total_sales),2) as avg_sales_game,round(sum(total_sales),2) as total_sales,
case when critic_score < 6 then '1:under 6'
     when critic_score between 6 and 6.9 then '2:6-6.9'
     when critic_score between 7 and 7.9 then '3:7-7.9'
     when critic_score between 8 and 8.9 then '4:8-8.9'
     else '5:above 9' end as critic_band 

from sales_analysis
where critic_score is not null
group by critic_band
order by critic_band;

--what are the 10 best selling games and platform combinations

select clean_title,console,genre,publisher,release_year,total_sales
from sales_analysis
order by total_sales desc
limit 10;

--top 10 games across all platforms
select clean_title,count(*) as platforms,round(sum(total_sales),2) as total_sale
from sales_analysis
group by clean_title
order by total_sale desc 
limit 10;


-- top game in each genre by average sales per platform
with game_avg as (
select genre,title,avg(total_sales) as avg_sales,count(*) as platforms
from sales_analysis
group by genre,title),
ranked as (
    select *,Row_number() over(partition by genre order by avg_sales desc,title) as rn
    from game_avg
)
select genre,title,platforms,avg_sales from ranked where rn=1 order by avg_sales desc;


