# 🍔 Swiggy Business Analysis using SQL (PostgreSQL)

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-025E8C?style=for-the-badge)
![Data Analysis](https://img.shields.io/badge/Data-Analysis-blue?style=for-the-badge)
![Business Intelligence](https://img.shields.io/badge/Business-Intelligence-green?style=for-the-badge)

---

# 📌 Project Overview

This project performs end-to-end business analysis on Swiggy's restaurant and menu dataset using PostgreSQL.

The objective of this project is to extract meaningful business insights related to:

- Restaurant performance
- Customer ratings
- Menu pricing strategies
- Category analysis
- Time-based trends
- Value-for-money categories
- Restaurant and location insights

The project follows a **Star Schema Data Warehouse approach** and solves real-world business problems using advanced SQL techniques.

---

# 🛠️ Tech Stack

- PostgreSQL
- SQL
- pgAdmin 4
- Git & GitHub

---

# 🏗️ Database Design

The project follows a **Star Schema** approach.

## ⭐ Star Schema (ERD)

![Star Schema](schema/star_schema.png)

## Raw Data Layer
- `swiggy_data`

## Fact Table
- `fact_table`

## Dimension Tables
- `dim_restaurant`
- `dim_location`
- `dim_category`
- `dim_dish`
- `dim_date`

---

# 📊 Data Quality Checks Performed

- NULL Value Analysis
- Blank Value Analysis
- Duplicate Detection
- Data Validation
- Data Transformation
- Star Schema Modeling

---

# 🎯 SQL Concepts Covered

- Joins
- Join Cardinality
- Aggregate Functions
- GROUP BY & HAVING
- Common Table Expressions (CTEs)
- Subqueries
- CASE WHEN
- Window Functions
- ROW_NUMBER()
- RANK()
- DENSE_RANK()
- LAG()
- LEAD()
- Time Intelligence Analysis
- Business KPI Analysis

---

# 💼 Key Business Insights Solved
**Q. Dense Rank Categories Based on Average Menu Price**
  - Concepts: DENSE_RANK(), Window Functions

```sql
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
```
 **Q. Compare Average Menu Prices State-wise and City-wise**
  - CTEs, Multi-level Aggregation
```sql
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
```
---

# 🚀 Key Skills Demonstrated

- SQL
- PostgreSQL
- Data Analysis
- Business Intelligence
- Data Modeling
- Data Cleaning
- Problem Solving
- Analytical Thinking

---

# 👨‍💻 Author

**Shubham**

B.Tech CSE | Aspiring Data Analyst

GitHub: [Shubham Singh](https://github.com/shubhamss02)

LinkedIn: [Shubham Singh](https://www.linkedin.com/in/shubham-singh-535274279/)

---

⭐ If you found this project useful, feel free to star the repository.
