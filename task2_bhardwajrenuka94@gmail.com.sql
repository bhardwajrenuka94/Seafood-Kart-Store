--DIGITAL ANALYSIS--

--1) How many users are there?

SELECT COUNT(DISTINCT user_id) AS total_users from users

--2) How many cookies does each user have on average?

WITH cookies as 
(SELECT user_id,COUNT(DISTINCT cookie_id) AS total_cookies
FROM users
GROUP BY user_id
)
SELECT ROUND(CAST(SUM(total_cookies)/COUNT(user_id) AS float),2)
AS avg_cookies
FROM cookies 

--3) What is the unique number of visits by all users per month?

SELECT DATEPART(MONTH,event_time) AS Month_Number,
DATENAME(MONTH,event_time) AS Months, COUNT(DISTINCT visit_id) AS visits
FROM events
GROUP BY DATEPART(Month,event_time), DATENAME(Month,event_time)
ORDER BY 1,2

--4) What is the number of events for each event type?

SELECT DISTINCT e.event_type,event_name,COUNT(*) AS COUNTS
FROM events e join event_identifier ei
on e.event_type=ei.event_type
GROUP BY e.event_type,event_name
ORDER BY 1

--5) What is the percentage of visits which have a purchase event?

SELECT ROUND(COUNT(DISTINCT visit_id)*100.0/(SELECT COUNT(DISTINCT visit_id) FROM events e),2)
AS purchase_prcnt
FROM events e JOIN event_identifier ei
on e.event_type=ei.event_type
WHERE event_name='Purchase'

--6) What is the percentage of visits which view the checkout page but do not have a purchase event?

WITH ABC AS(
SELECT DISTINCT visit_id,
SUM(CASE WHEN event_name!='Purchase' and page_id=12 THEN 1 else 0 end) AS checkouts,
SUM(CASE WHEN event_name='Purchase' THEN 1 else 0 end) AS Purchases
FROM
events e JOIN event_identifier ei
ON e.event_type=ei.event_type
GROUP BY visit_id
)
SELECT SUM(checkouts) AS total_checkout, SUM(Purchases) AS total_purchases,
100 - ROUND(SUM(Purchases)*100.0/SUM(checkouts),2) AS prcnt
FROM ABC

--7) What are the top 3 pages by number of views?

SELECT TOP 3 page_name, COUNT(visit_id) AS visits
FROM events e JOIN
page_heirarchy p ON 
e.page_id=p.page_id
GROUP BY page_name
ORDER BY 2 DESC

--8) What is the number of views and cart adds for each product category?

SELECT product_category,
SUM(CASE WHEN event_name='Page View' THEN 1 ELSE 0 end) AS views,
SUM(CASE WHEN event_name='Add to Cart' THEN 1 ELSE 0 end) AS cart_adds
FROM events e JOIN event_identifier ei
on e.event_type=ei.event_type JOIN page_heirarchy p
ON p.page_id=e.page_id
WHERE product_category is not null
GROUP BY product_category

--9) What are the top 3 products by purchases?

SELECT TOP 3 
b.product_id,
COUNT(a.visit_id) AS purchase_count
FROM events AS a
INNER JOIN page_heirarchy as b
ON a.page_id = b.page_id
WHERE a.event_type=3
GROUP BY product_id


--PRODUCT FUNNEL ANALYSIS--

--Creating the new table product_category_level_summary-

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
--creating purchase_id because for purchased products the product_id is null
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



--SOLVE QUESTIONS(10-14) USING TABLE PRODUCT_LEVEL_SUNNARY AND PRODUCT_CATEGORY_LEVEL_SUMMARY

--Q-10)
--Using table product_level_summary--

--Product viewed--

SELECT TOP 1 page_name AS most_viewed
FROM product_level_summary
ORDER BY page_views DESC

--Product added to cart--

SELECT TOP 1 page_name AS most_cart_adds
FROM product_level_summary
ORDER BY cart_adds DESC


--Most Product added to cart but not purchased--

SELECT TOP 1 page_name AS most_cart_adds_not_purchased
FROM product_level_summary
ORDER BY cart_adds DESC


--Product purchased--

SELECT TOP 1 page_name AS most_purchased
FROM product_level_summary
ORDER BY cart_add_purchase DESC

--Using table product_category_level_summary--

--Product viewed--

SELECT TOP 1 product_category AS most_viewed
FROM product_category_level_summary
ORDER BY page_views DESC

--product added to cart--

SELECT TOP 1 product_category AS most_cart_adds
FROM product_category_level_summary
ORDER BY cart_adds DESC

--Product added to cart but not purchased--

SELECT TOP 1 product_category AS most_cart_adds_not_purchased
FROM product_category_level_summary
ORDER BY cart_adds DESC

--Product purchased--

SELECT TOP 1 product_category AS most_purchased
FROM product_category_level_summary
ORDER BY cart_add_purchase DESC

--Q-11) Using product_level_summary and product_category_level_summary tables,
--find which product was most likely abandoned?

SELECT TOP 1 page_name AS most_purchased
FROM product_level_summary
ORDER BY cart_add_not_purchase DESC

SELECT TOP 1 product_category AS most_purchased
FROM product_category_level_summary
ORDER BY cart_add_not_purchase DESC


--Q-12) Using product_level_summary and product_category_level_summary tables,
--find which product had the highest view to purchase pecentage?


SELECT page_name AS product, round(cart_add_purchase*100.0/page_views, 2)
AS view_purchase_prcnt
FROM product_level_summary
ORDER BY 2 DESC

SELECT product_category AS product, round(cart_add_purchase*100.0/page_views, 2)
AS view_purchase_prcnt
FROM product_category_level_summary
ORDER BY 2 DESC



--Q-13) Using product_level_summary and product_category_level_summary tables,
--find what is the average conversion rate from view to cart add?


SELECT ROUND(AVG(cart_adds*100.0/page_views), 2) AS avg_rate_viewtocart
FROM product_level_summary

SELECT ROUND(AVG(cart_adds*100.0/page_views), 2) AS avg_rate_viewtocart
FROM product_category_level_summary


--Q-14) Using product_level_summary and product_category_level_summary tables,
--find what is the average conversion rate from view to cart add to purchase?


SELECT ROUND(AVG(cart_add_purchase*100.0/cart_adds), 2) AS avg_rate_carttopurchase
FROM product_level_summary

SELECT ROUND(AVG(cart_add_purchase*100.0/cart_adds), 2) AS avg_rate_carttopurchase
FROM product_category_level_summary


--CAMPAIGN_ANALYSIS--

--SOLVE QUESTIONS(15-18) USING TABLE PRODUCT_LEVEL_SUNNARY AND PRODUCT_CATEGORY_LEVEL_SUMMARY

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



--Q-15--

SELECT
a.Campaign,
a.user_id,
SUM(CASE WHEN a.impressions > 0 THEN 1 ELSE 0 end) AS impressions_count,
SUM(CASE WHEN a.impressions <= 0 THEN 1 ELSE 0 end) AS no_impressions_count
FROM
visit_summary AS a
GROUP BY 
a.Campaign, a.user_id

--Q-16--
SELECT DISTINCT *FROM(
SELECT(
(SELECT COUNT(*) FROM visit_summary AS a
WHERE A.impressions = 1 AND A.purchase = 1 AND A.click = 1)*100/
(SELECT COUNT(*) FROM visit_summary AS B
WHERE B.impressions = 1 AND B.purchase = 1) )
AS purchase_percentage_ON_clicking_impressions
FROM visit_summary AS D) AS E


--Q-17--

SELECT (t.impressions_and_click*100/t.total_purchase) AS rate_of_impressions_and_click,
(t.impressions_but_notclick*100/t.total_purchase) AS rate_of_notimpressions_but_click,
(t.notimpressions_but_click*100/t.total_purchase) AS rate_of_impressions_but_notclick,

FROM (
SELECT
(SELECT COUNT(*) FROM visit_summary WHERE impressions = 1 AND click =1 AND purchase = 1) AS impressions_and_click,
(SELECT COUNT(*) FROM visit_summary WHERE impressions = 0 AND click =1 AND purchase = 1) AS notimpressions_but_click,
(SELECT COUNT(*) FROM visit_summary WHERE impressions = 1 AND click =0 AND purchase = 1) AS impressions_but_notclick,
(SELECT COUNT(*) FROM visit_summary WHERE purchase = 1) AS total_purchase
) as t


--Q-18--

SELECT
(t.count_25_off*100/ t.total_campaigns) AS percentage_25_off,
(t.count_bogof*100/ t.total_campaigns) AS percentage_bofof,
(t.count_half_off*100/ t.total_campaigns) AS percentage_half_off
FROM (
SELECT
SUM(CASE WHEN a.Campaign ='Half off - Treat Your Shellf(ish)' THEN 1 ELSE 0 END) AS count_half_off,
SUM(CASE WHEN a.Campaign ='25% off - Living The Lux Life' THEN 1 ELSE 0 END) AS count_25_off,
SUM(CASE WHEN a.Campaign ='BOGOF - Fishing For Compliments' THEN 1 ELSE 0 END) AS count_bogof,
COUNT(*) AS total_campaigns
FROM visit_summary AS a
WHERE a.Campaign is not null
) AS t