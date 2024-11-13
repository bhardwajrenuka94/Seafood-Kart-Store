--CREATE DATABASE SEAFOODKART--

--Q-1)----Create database 'seafoodkart'

CREATE DATABASE seafoodkart

--MAKE DB ACTIVE
USE seafoodkart


--Q-2) --IMPORT csv FILES FROM excel

SELECT *FROM campaign_identifier
SELECT *FROM event_identifier
SELECT *FROM events
SELECT *FROM page_heirarchy
SELECT *FROM users

--Q-3)--Update all the tables with appropriate datatypes 
ALTER TABLE users
ALTER COLUMN start_date
date;

ALTER TABLE events
ALTER COLUMN event_time
datetime;

ALTER TABLE campaign_identifier
ALTER COLUMN start_date 
date;

ALTER TABLE campaign_identifier
ALTER COLUMN end_date
date;

--Q-4)--What is the count of records in each table
SELECT COUNT(*) FROM campaign_identifier

SELECT COUNT(*) FROM event_identifier

SELECT COUNT(*) FROM events

SELECT COUNT(*) FROM page_heirarchy

SELECT COUNT(*) FROM users

--Q-5) Create combined table of all the five tables by joining these tables. The final table should be 'Final_Raw_Data' on the data base
-- events as a, event identifier as b, page heirarchy as c, users as d, campaign identifier as e--

SELECT *INTO FINAL_RAW_DATA FROM(
SELECT *FROM
(SELECT a.*,b.event_name,c.page_name,c.product_category,c.product_id,d.start_date,d.user_id,e.campaign_id,e.campaign_name,e.end_date
FROM events AS a
LEFT JOIN event_identifier as b
ON a.event_type = b.event_type
LEFT JOIN page_heirarchy as c
ON a.page_id = c.page_id
LEFT JOIN users as d
ON a.cookie_id = d.cookie_id
LEFT JOIN [campaign_identifier] AS e
ON e.products = c.product_id
) AS F) AS G

SELECT * FROM FINAL_RAW_DATA

--PRODUCT FUNNEL ANALYSIS--

--Q-6)--Create a new table (Product_level_summary) which has the following details:

--Creating the new table product_level_summary----


DROP TABLE if exists product_level_summary
CREATE TABLE product_level_summary
(
page_name VARCHAR(50),
page_views INT,
cart_adds INT,
cart_add_not_purchase INT,
cart_add_purchase INT
);
WITH tab1 AS(
 SELECT e.visit_id,page_name, 
 SUM( CASE WHEN event_name='Page View' THEN 1 ELSE 0 end)as view_count,
 SUM( CASE WHEN event_name='Add to Cart' THEN 1 ELSE 0 end)as cart_adds
 FROM events e join  page_heirarchy p
 ON e.page_id=p.page_id 
 JOIN event_identifier ei   
 ON e.event_type=ei.event_type
 WHERE product_id is not null
 GROUP BY e.visit_id,page_name
),
--creating purchaseid because for purchased products the product_id is null
 tab2 AS(
SELECT DISTINCT(visit_id) AS Purchase_id
FROM events e join event_identifier ei   
 ON e.event_type=ei.event_type WHERE event_name = 'Purchase'),
tab3 AS(
SELECT *, 
(CASE WHEN purchase_id is not null THEN 1 ELSE 0 end) AS purchase
FROM tab1 LEFT JOIN tab2
ON visit_id = purchase_id),
tab4 AS(
SELECT page_name, sum(view_count) AS Page_Views, SUM(cart_adds) AS Cart_Adds, 
SUM(CASE WHEN cart_adds = 1 and purchase = 0 THEN 1 ELSE 0
 end) as Cart_Add_Not_Purchase,
SUM(CASE WHEN cart_adds= 1 and purchase = 1 THEN 1 ELSE 0
 end) AS Cart_Add_Purchase
FROM tab3
GROUP BY page_name)

INSERT INTO product_level_summary
(page_name ,page_views ,cart_adds ,cart_add_not_purchase ,cart_add_purchase )
SELECT page_name, page_views, cart_adds, cart_add_not_purchase, cart_add_purchase
FROM tab4
SELECT * FROM product_level_summary


--Q-7)----Create a new table (Product_category_level_summary) which has the following details:

--Creating the new table product_category_level_summary--

DROP TABLE if exists product_category_level_summary
CREATE TABLE product_category_level_summary
(product_category VARCHAR(50),
page_views INT,
cart_adds INT ,
cart_add_not_purchase INT,
cart_add_purchase INT )
;
WITH tab1 AS(
 SELECT e.visit_id,product_category, page_name, 
 SUM( CASE WHEN event_name='Page View' THEN 1 ELSE 0 end) AS view_count,
 SUM( CASE WHEN event_name='Add to Cart' THEN 1 ELSE 0 end) AS cart_adds
 --SUM( CASE WHEN event_name='Purchase' THEN 1 ELSE 0 end) AS purchases
 FROM events e join  page_heirarchy p
 ON e.page_id=p.page_id 
 JOIN event_identifier ei   
 ON e.event_type=ei.event_type
 WHERE product_id is not null
 GROUP BY e.visit_id,product_category,page_name
),
--creating purcchaseid because for purchased products the product_id is null
 tab2 AS(
SELECT DISTINCT(visit_id) AS Purchase_id
FROM events e JOIN event_identifier ei   
 ON e.event_type=ei.event_type WHERE event_name = 'Purchase'),
tab3 AS(
SELECT *, 
(CASE WHEN purchase_id is not null THEN 1 ELSE 0 end) AS purchase
FROM tab1 LEFT JOIN tab2
ON visit_id = purchase_id),
tab4 AS(
SELECT product_category, SUM(view_count) AS Page_Views, SUM(cart_adds) AS Cart_Adds, 
SUM(CASE WHEN cart_adds = 1 and purchase = 0 THEN 1 ELSE 0 end) AS Cart_Add_Not_Purchase,
SUM(CASE WHEN cart_adds= 1 and purchase = 1 THEN 1 ELSE 0 end) AS Cart_Add_Purchase
FROM tab3
GROUP BY  product_category)

INSERT INTO product_category_level_summary
(product_category,page_views ,cart_adds ,cart_add_not_purchase ,cart_add_purchase )
SELECT product_category, page_views, cart_adds, cart_add_not_purchase, cart_add_purchase
FROM tab4
SELECT * FROM product_category_level_summary


--Q-8)----Create a new table 'Visit_summary that has 1 Single row for every unique visit_id record and has the following 10 columns:

--Creating new table 'visit_summary'----

create table visit_summary
(
user_id int,
visit_id varchar(20),
visit_start_time datetime2(3),
page_views int,
cart_adds int,
purchase int,
impressions int, 
click int, 
Campaign varchar(200),
cart_products varchar(200)
);
with cte as(
select distinct visit_id, user_id,min(event_time) as visit_start_time,count(e.page_id) as page_views, sum(case when event_name='Add to Cart' then 1 else 0 end) as cart_adds,
sum(case when event_name='Purchase' then 1 else 0 end) as purchase,
sum(case when event_name='Ad Impression' then 1 else 0 end) as impressions,
sum(case when event_name='Ad Click' then 1 else 0 end) as click,
case
when min(event_time) > '2020-01-01 00:00:00' and min(event_time) < '2020-01-14 00:00:00'
  then 'BOGOF - Fishing For Compliments'
when min(event_time) > '2020-01-15 00:00:00' and min(event_time) < '2020-01-28 00:00:00'
  then '25% Off - Living The Lux Life'
when min(event_time) > '2020-02-01 00:00:00' and min(event_time) < '2020-03-31 00:00:00'
  then 'Half Off - Treat Your Shellf(ish)' 
else NULL
end as Campaign,
string_agg(case when product_id IS NOT NULL AND event_name='Add to Cart'
   then page_name ELSE NULL END, ', ') AS cart_products
from events e join event_identifier ei
on e.event_type=ei.event_type  join users u
on u.cookie_id=e.cookie_id 
join page_heirarchy ph on e.page_id = ph.page_id
group by visit_id, user_id
)
insert into visit_summary
(user_id, visit_id, visit_start_time, page_views, cart_adds, purchase, impressions, click, Campaign, cart_products)
select user_id,visit_id, visit_start_time, page_views, cart_adds, purchase, impressions, click, Campaign, cart_products
from cte;
select * from visit_summary




