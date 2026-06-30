-- ==========================================================
-- 				SWIGGY BUSINESS ANALYSIS PROJECT
-- ==========================================================

--========================================
--			DATA QUALITY CHECKS
--========================================

--NULL CHECK

SELECT 
	COUNT(*) FILTER (WHERE state IS NULL) AS state_nulls,
	COUNT(*) FILTER (WHERE city IS NULL) AS city_nulls,
	COUNT(*) FILTER (WHERE order_date IS NULL) AS date_nulls,
	COUNT(*) FILTER (WHERE restaurant_name IS NULL) AS restaurant_nulls,
	COUNT(*) FILTER (WHERE location IS NULL) AS location_nulls,
	COUNT(*) FILTER (WHERE category IS NULL) AS category_nulls,
	COUNT(*) FILTER (WHERE dish_name IS NULL) AS dish_nulls,
	COUNT(*) FILTER (WHERE price IS NULL) AS price_nulls,
	COUNT(*) FILTER (WHERE rating IS NULL) AS rating_nulls,
	COUNT(*) FILTER (WHERE rating_count IS NULL) AS rating_count_nulls
FROM Swiggy_Data;

--BLANK CHECK

SELECT 
	COUNT(*) FILTER (WHERE TRIM(state)='') AS state_blank,
	COUNT(*) FILTER (WHERE TRIM(city)='') AS city_blank,
	COUNT(*) FILTER (WHERE TRIM(restaurant_name)='') AS restaurant_blank,
	COUNT(*) FILTER (WHERE TRIM(location)='') AS location_blank,
	COUNT(*) FILTER (WHERE TRIM(category)='') AS category_blank,
	COUNT(*) FILTER (WHERE TRIM(dish_name)='') AS dish_blank
FROM Swiggy_Data;

--DUPLICATE DETECTION

SELECT 
	state,city,order_date,restaurant_name,location,category,dish_name,
	price,rating,rating_count,COUNT(*)
FROM Swiggy_Data
GROUP BY 
	state,city,order_date,restaurant_name,location,category,dish_name,
	price,rating,rating_count
HAVING COUNT(*)>1;

--DUPLICATE REMOVAL

WITH duplicates AS (
SELECT
	row_id,
	ROW_NUMBER() OVER(
		PARTITION BY 
			state,
			city,
			order_date,
			restaurant_name,
			location,
			category,
			dish_name,
			price,
			rating,
			rating_count
		ORDER BY row_id
		) AS rn
FROM Swiggy_Data
)
DELETE  FROM Swiggy_Data
WHERE row_id IN (
SELECT row_id
FROM duplicates
WHERE rn>1
);

--CARDINALITY ANALYSIS

SELECT
	COUNT(DISTINCT state) AS state_count,
	COUNT(DISTINCT city) AS city_count,
	COUNT(DISTINCT restaurant_name) AS restaurant_count,
	COUNT(DISTINCT category) AS category_count,
	COUNT(DISTINCT dish_name) AS dish_count
FROM Swiggy_Data;

SELECT DISTINCT category
FROM swiggy_data
LIMIT 50;

--========================================
--			STAR SCHEMA CREATION
--========================================

CREATE TABLE Swiggy_Data (
	State VARCHAR(100),
	City VARCHAR(100),
	Order_Date DATE,
	Restaurant_Name VARCHAR(150),
	Location VARCHAR(100),
	Category VARCHAR(100),
	Dish_Name VARCHAR(200),
	Price DECIMAL(10,2),
	Rating DECIMAL(2,1),
	Rating_Count INT
);
ALTER TABLE Swiggy_Data
ADD COLUMN row_id SERIAL;
--------------------------------------

-- DIM_LOCATION

CREATE TABLE dim_location (
	location_id SERIAL PRIMARY KEY,
	state VARCHAR(100),
	city VARCHAR(100),
	location VARCHAR(100)
);
INSERT INTO dim_location (state,city,location)
SELECT DISTINCT
	state,
	city,
	location
FROM Swiggy_Data;

-- DIM_RESTAURANT

CREATE TABLE dim_restaurant (
	restaurant_id SERIAL PRIMARY KEY,
	restaurant_name VARCHAR(150),
	location_id INT REFERENCES dim_location(location_id)
);
INSERT INTO dim_restaurant (restaurant_name,location_id)
SELECT DISTINCT
	s.restaurant_name,
	l.location_id
FROM Swiggy_Data s
JOIN dim_location l on
s.state=l.state AND
s.city=l.city AND
s.location=l.location;

-- DIM_DISH

CREATE TABLE dim_dish (
	dish_id SERIAL PRIMARY KEY,
	dish_name VARCHAR(200)
);
INSERT INTO dim_dish (dish_name)
SELECT DISTINCT
	dish_name
FROM Swiggy_Data;

--DIM_CATEGORY

CREATE TABLE dim_category(
	category_id SERIAL PRIMARY KEY,
	category VARCHAR(200)
);
INSERT INTO dim_category(category)
SELECT DISTINCT
	category
FROM Swiggy_Data;

-- DIM_DATE

CREATE TABLE dim_date (
	date_id SERIAL PRIMARY KEY,
	order_date DATE,
	year INT,
	month INT,
	quarter INT,
	day INT
);
INSERT INTO dim_date (order_date,year,month,quarter,day)
SELECT DISTINCT
	order_date,
	EXTRACT(YEAR FROM order_date),
	EXTRACT(MONTH FROM order_date),
	EXTRACT(QUARTER FROM order_date),
	EXTRACT(DAY FROM order_date)
FROM Swiggy_Data;

-- FACT_TABLE

CREATE TABLE fact_table (
	fact_id SERIAL PRIMARY KEY,
	location_id INT REFERENCES dim_location(location_id),
	restaurant_id INT REFERENCES dim_restaurant(restaurant_id),
	dish_id INT REFERENCES dim_dish(dish_id),
	category_id INT REFERENCES dim_category(category_id),
	date_id INT REFERENCES dim_date(date_id),
	price DECIMAL(10,2),
	rating DECIMAL(2,1),
	rating_count INT
);
INSERT INTO fact_table(location_id,restaurant_id,dish_id,category_id,date_id,price,rating,rating_count)
SELECT 
	dl.location_id,
	dr.restaurant_id,
	di.dish_id,
	dc.category_id,
	dd.date_id,
	s.price,
	s.rating,
	s.rating_count
FROM Swiggy_Data s

JOIN dim_location dl ON 
s.state=dl.state AND
s.city=dl.city AND
s.location=dl.location

JOIN dim_restaurant dr ON 
s.restaurant_name=dr.restaurant_name AND
dr.location_id=dl.location_id

JOIN dim_dish di ON
s.dish_name=di.dish_name

JOIN dim_category dc ON
s.category=dc.category

JOIN dim_date dd ON
s.order_date=dd.order_date;

--========================================
--			 INDEX CREATION
--========================================

CREATE INDEX idx_fact_location
ON fact_table(location_id);

CREATE INDEX idx_fact_restaurant
ON fact_table(restaurant_id);

CREATE INDEX idx_fact_dish
ON fact_table(dish_id);

CREATE INDEX idx_fact_category
ON fact_table(category_id);

CREATE INDEX idx_fact_date
ON fact_table(date_id);

/* NOTE:
	Index are created on all foreign keys of the fact table
	to optimize joins and improve query performance.
*/

--========================================
--			BUSINESS ANALYSIS
--========================================

/*Q1.Find the Top 10 restaurant outlets by average rating. Exclude 
     restaurants whose cumulative rating count is less than 50.*/

SELECT 
	dr.restaurant_name,
	AVG(ft.rating) AS Avg_rating
FROM dim_restaurant dr
JOIN fact_table ft 
ON dr.restaurant_id=ft.restaurant_id 
WHERE ft.rating_count > 50
GROUP BY dr.restaurant_name
ORDER BY Avg_rating DESC
LIMIT 10;

--Q2.Find all menu items priced above ₹300.

SELECT 
	dd.dish_name
FROM dim_dish dd
JOIN fact_table ft
ON dd.dish_id=ft.dish_id
WHERE ft.price > 300;

--Q3.Find all restaurant outlets in Bengaluru with an average rating greater than 4.5.

SELECT 
	dr.restaurant_id,
	dr.restaurant_name,
	dl.city,
	AVG(ft.rating) AS avg_rating
FROM dim_restaurant dr
JOIN dim_location dl
ON dr.location_id=dl.location_id
JOIN fact_table ft
ON dr.restaurant_id=ft.restaurant_id
WHERE dl.city='Bengaluru'
GROUP BY dr.restaurant_id,dr.restaurant_name,dl.city
HAVING AVG(ft.rating)>4.5;

--Q4.Find all restaurants that have Biryani items on their menu.

SELECT DISTINCT 
	dr.restaurant_name,
	dd.dish_name
FROM dim_restaurant dr
JOIN fact_table ft
ON dr.restaurant_id=ft.restaurant_id
JOIN dim_dish dd
ON ft.dish_id=dd.dish_id
WHERE dd.dish_name ILIKE '%Biryani%';

--Q5.Find the Top 10 categories by average menu price.

WITH avg_menu_price AS (
	SELECT 
		dish_id,
		AVG(price) AS avg_price
	FROM fact_table ft
	GROUP BY dish_id
)
SELECT 
	dc.category,
	AVG(amp.avg_price) AS category_avg
FROM avg_menu_price amp
JOIN dim_dish dd
ON amp.dish_id=dd.dish_id
JOIN fact_table ft
ON dd.dish_id=ft.dish_id
JOIN dim_category dc
ON dc.category_id=ft.category_id
GROUP BY dc.category
ORDER BY category_avg DESC
LIMIT 10;

--========================================
--			AGGREGATIONS & KPIs
--========================================

--Q6.Find the average menu item price for each category.

SELECT 
	dc.category,
	AVG(ft.price) AS avg_price
FROM fact_table ft
JOIN dim_category dc
ON ft.category_id=dc.category_id
GROUP BY dc.category;

--Q7.Find the total number of menu items available in each city.

SELECT
	dl.city,
	COUNT(DISTINCT(ft.dish_id)) AS Total_Number_Of_Menu_Items
FROM fact_table ft
JOIN dim_location dl
ON ft.location_id=dl.location_id
GROUP BY dl.city;

--Q8.Find the Top 10 restaurant outlets with the highest average rating.

SELECT
	dr.restaurant_id,
	dr.restaurant_name,
	AVG(ft.rating) AS avg_rating
FROM fact_table ft
JOIN dim_restaurant dr
ON ft.restaurant_id=dr.restaurant_id
GROUP BY dr.restaurant_id,dr.restaurant_name
ORDER BY avg_rating DESC
LIMIT 10;

--Q9.Find categories having an average rating above 4.5.

SELECT
	dc.category,
	AVG(ft.rating) AS avg_rating
FROM fact_table ft
JOIN dim_category dc
ON ft.category_id=dc.category_id
GROUP BY dc.category
HAVING AVG(ft.rating)>4.5;

--Q10.Compare average menu prices state-wise and city-wise.

WITH state_avg AS (
	SELECT
		dl.state,
		AVG(ft.price) AS state_avg_price
	FROM fact_table ft
	JOIN dim_location dl
	ON ft.location_id=dl.location_id
	GROUP BY dl.state
),
city_avg AS (
	SELECT 
		dl.state,
		dl.city,
		AVG(ft.price) as city_avg_price
	FROM fact_table ft
	JOIN dim_location dl
	ON ft.location_id=dl.location_id
	GROUP BY dl.state,dl.city
)
SELECT
	ca.state,
	ca.city,
	ca.city_avg_price,
	sa.state_avg_price
FROM city_avg ca
JOIN state_avg sa
ON ca.state=sa.state;

/* Note:
	In the current dataset, each state maps to only one city.
	Therefore, state_avg_price and city_avg_price happen to be identical.
	The query is written in a generalized way and would show meaningful
	comparisons if multiple cities existed within a state.
*/

--========================================
--			TIME INTELLIGENCE
--========================================

--Q11.Analyze the number of menu listings by month.

SELECT
	dd.month,
	COUNT(DISTINCT ft.dish_id) AS Unique_Menu_Items
FROM fact_table ft
JOIN dim_date dd
ON ft.date_id=dd.date_id
GROUP BY dd.month;

--Q12.Analyze the average menu item price month-wise.

SELECT
	dd.month,
	AVG(ft.price) AS Avg_Price
FROM fact_table ft
JOIN dim_date dd
ON ft.date_id=dd.date_id
GROUP BY dd.month;

--Q13.Find the quarter with the highest number of menu listings.

SELECT
	dd.quarter,
	COUNT(DISTINCT ft.dish_id) AS dish_count
FROM fact_table ft
JOIN dim_date dd
ON ft.date_id=dd.date_id
GROUP BY dd.quarter
ORDER BY dd.quarter DESC
LIMIT 1;

--Q14.Compare quarter-wise average ratings.

SELECT
	dd.quarter,
	ROUND(AVG(ft.rating),3) AS avg_rating
FROM fact_table ft
JOIN dim_date dd
ON ft.date_id=dd.date_id
GROUP BY dd.quarter;

--Q15.Find the month with the highest average menu price.

SELECT
	dd.month,
	AVG(ft.price) AS avg_price
FROM fact_table ft
JOIN dim_date dd
ON ft.date_id=dd.date_id
GROUP BY dd.month
ORDER BY dd.month DESC
LIMIT 1;

--========================================
--	  RESTAURANT & LOCATION INSIGHTS
--========================================

--Q16.Find the Top 5 restaurant outlets based on total rating count.

SELECT 
	dr.restaurant_id,
	dr.restaurant_name,
	SUM(ft.rating_count) AS Total_Rating_Count
FROM fact_table ft
JOIN dim_restaurant dr
ON ft.restaurant_id=dr.restaurant_id
GROUP BY dr.restaurant_id,dr.restaurant_name
ORDER BY Total_Rating_Count DESC
LIMIT 5;

--Q17.Compare city-wise average restaurant ratings.

WITH restaurant_avg AS (
	SELECT 
		location_id,
		restaurant_id,
		AVG(rating) as avg_restaurant_rating
	FROM fact_table
	GROUP BY location_id,restaurant_id
)
SELECT
	dl.city,
	AVG(ra.avg_restaurant_rating) AS city_wise_avg_rating
FROM restaurant_avg ra
JOIN dim_location dl
ON ra.location_id=dl.location_id
GROUP BY dl.city;

--Q18.Find restaurant outlets whose average rating is higher than their city's average.

WITH city_avg AS (
	SELECT 
		dl.city,
		AVG(ft.rating) AS City_Avg_Rating
	FROM fact_table ft
	JOIN dim_location dl
	ON ft.location_id=dl.location_id
	GROUP BY dl.city
)
SELECT 
	dr.restaurant_id,
	dr.restaurant_name,
	dl.city,
	AVG(ft.rating) AS Restaurant_Avg_Rating,
	ca.City_Avg_Rating
FROM fact_table ft
JOIN dim_location dl
ON ft.location_id=dl.location_id
JOIN city_avg ca 
ON dl.city=ca.city
JOIN dim_restaurant dr
ON dl.location_id=dr.location_id
GROUP BY dr.restaurant_id, dr.restaurant_name, dl.city, ca.City_Avg_Rating
HAVING AVG(ft.rating) > ca.city_avg_rating;

--Q19.Find restaurant brands operating in more than 5 cities.

SELECT
	dr.restaurant_name,
	COUNT(DISTINCT dl.city) no_of_cities
FROM dim_restaurant dr
JOIN dim_location dl
ON dr.location_id=dl.location_id
GROUP BY dr.restaurant_name
HAVING COUNT(DISTINCT dl.city)>5
ORDER BY no_of_cities DESC;

--Q20.Find the Top 5 states having the highest number of restaurant outlets.

SELECT
	dl.state,
	COUNT(DISTINCT dr.restaurant_id) no_of_outlets
FROM dim_location dl
JOIN dim_restaurant dr
ON dl.location_id=dr.location_id
GROUP BY dl.state
ORDER BY no_of_outlets DESC
LIMIT 5;

--========================================
--	  		WINDOW FUNCTIONS
--========================================

--Q21.Find the Top 3 restaurant outlets in each city based on average rating.

WITH restaurant_avg as (
	SELECT 
		dl.city,
		dr.restaurant_id,
		dr.restaurant_name,
		AVG(ft.rating) AS Avg_rating
	FROM fact_table ft
	JOIN dim_location dl
	ON ft.location_id=dl.location_id
	JOIN dim_restaurant dr
	ON dl.location_id=dr.location_id
	GROUP BY dl.city,dr.restaurant_id,dr.restaurant_name
),
rankes as (
	SELECT *,
		ROW_NUMBER() OVER(
			PARTITION BY city
			ORDER BY Avg_rating DESC
			) AS rn
	FROM restaurant_avg
)
SELECT * FROM rankes
WHERE rn<=3;

--Q22.Rank restaurant outlets within each state according to average rating.

WITH restaurant_avg AS (
	SELECT 
		dl.state,
		dr.restaurant_id,
		dr.restaurant_name,
		ROUND(AVG(ft.rating),3) AS avg_rating
	FROM fact_table ft
	JOIN dim_location dl
	ON ft.location_id=dl.location_id
	JOIN dim_restaurant dr
	ON ft.restaurant_id=dr.restaurant_id
	GROUP BY dl.state, dr.restaurant_id, dr.restaurant_name
)
SELECT *,
	ROW_NUMBER() OVER(
		PARTITION BY state
		ORDER BY avg_rating DESC
		) AS ranks
FROM restaurant_avg;


--Q23.Dense rank categories based on average menu price.

WITH category_avg AS (
	SELECT
		dc.category,
		ROUND(AVG(ft.price),2) AS Avg_price
	FROM fact_table ft
	JOIN dim_category dc
	ON ft.category_id=dc.category_id
	GROUP BY dc.category
)
SELECT *,
	DENSE_RANK() OVER(ORDER BY Avg_price DESC) AS category_rank
FROM category_avg;

--Q24.Compare each category's average price with the previous category using LAG().

WITH category_avg AS (
	SELECT
		dc.category,
		ROUND(AVG(ft.price),2) AS avg_price
	FROM fact_table ft
	JOIN dim_category dc
	ON ft.category_id=dc.category_id
	GROUP BY dc.category
)
SELECT *,
	LAG(avg_price) OVER(ORDER BY avg_price) AS lag_avg_price,
	avg_price - LAG(avg_price) OVER(ORDER BY avg_price) AS difference
FROM category_avg;

--Q25.Compare each category's average price with the next category using LEAD().

WITH category_avg AS (
	SELECT
		dc.category,
		ROUND(AVG(ft.price),2) AS avg_price
	FROM fact_table ft
	JOIN dim_category dc
	ON ft.category_id=dc.category_id
	GROUP BY dc.category
)
SELECT *,
	LEAD(avg_price) OVER(ORDER BY avg_price) AS lag_avg_price,
	avg_price - LEAD(avg_price) OVER(ORDER BY avg_price) AS difference
FROM category_avg;

--========================================
--	  	ADVANCED BUSINESS INSIGHTS
--========================================

--Q26.Segment menu items into Budget, Mid-Range, and Premium.

SELECT
    dd.dish_name,
	ft.price,
	CASE 
	WHEN ft.price < 200 THEN 'Budget'
	WHEN ft.price BETWEEN 200 AND 500 THEN 'Mid-Range'
	ELSE 'Premium' 
	END AS price_segment
FROM fact_table ft
JOIN dim_dish dd
ON ft.dish_id=dd.dish_id;

--Q27.Find the highest-rated menu item in every category.

WITH menu_rating AS (
	SELECT 
		dc.category,
		dd.dish_id,
		dd.dish_name,
		ROUND(AVG(ft.rating),2) AS highest_rated
	FROM fact_table ft
	JOIN dim_dish dd
	ON ft.dish_id=dd.dish_id
	JOIN dim_category dc
	ON ft.category_id=dc.category_id
	GROUP BY dc.category,dd.dish_id,dd.dish_name
),
ranks AS (
	SELECT *,
	ROW_NUMBER() OVER(
	PARTITION BY category
	ORDER BY highest_rated DESC) AS rn
	FROM menu_rating
)
SELECT * FROM ranks
WHERE rn=1;

--Q28.Find the Top 5 most expensive menu items in each category.
WITH expensive_items AS (
	SELECT
		dc.category,
		dd.dish_id,
		dd.dish_name,
		MAX(ft.price) AS max_price
	FROM fact_table ft
	JOIN dim_category dc
	ON ft.category_id=dc.category_id
	JOIN dim_dish dd
	ON ft.dish_id=dd.dish_id
	GROUP BY dc.category,dd.dish_id,dd.dish_name
),
ranking AS (
	SELECT *,
		ROW_NUMBER() OVER(
			PARTITION BY category 
			ORDER BY max_price DESC) AS ranks
	FROM expensive_items
)
SELECT * FROM ranking
WHERE ranks<=5;

--Q29.Find categories whose average price is above the overall average price.

WITH category_avg AS (
	SELECT
		dc.category,
		ROUND(AVG(ft.price),2) AS category_avg_price
	FROM fact_table ft
	JOIN dim_category dc
	ON ft.category_id=dc.category_id
	GROUP BY dc.category
),
overall_avg AS (
	SELECT
		ROUND(AVG(price),2) AS overall_avg_price
	FROM fact_table
)
SELECT * 
FROM category_avg
CROSS JOIN overall_avg
WHERE category_avg_price > overall_avg_price;

/* NOTE:
	CROSS JOIN is used because overall_avg contains only one row.
	This allows the overall metric to be compared against every category. 
*/

--Q30.Identify categories that provide the best value for money (high rating with below-average price).

WITH category_avg AS (
	SELECT
		dc.category,
		ROUND(AVG(ft.rating),2) AS avg_rating,
		ROUND(AVG(ft.price),2) AS avg_price
	FROM fact_table ft
	JOIN dim_category dc
	ON ft.category_id=dc.category_id
	GROUP BY dc.category
),
overall_avg AS (
	SELECT
		ROUND(AVG(rating),2) AS overall_avg_rating,
		ROUND(AVG(price),2) AS overall_avg_price
	FROM fact_table
)
SELECT *
FROM category_avg
CROSS JOIN overall_avg
WHERE avg_price < overall_avg_price
AND avg_rating > overall_avg_rating
ORDER BY avg_rating DESC , avg_price ASC;

/* NOTE:
	CROSS JOIN is used because overall_avg contains only one row.
	This allows the overall metric to be compared against every category. 
*/

-- ==========================================================
-- 						END OF PROJECT
-- ==========================================================
-- Total Questions Solved : 30
-- Concepts Covered :
-- Aggregations, CTEs, Window Functions, Ranking,
-- Time Intelligence, Dimensional Modeling, Business Analytics
-- ==========================================================
