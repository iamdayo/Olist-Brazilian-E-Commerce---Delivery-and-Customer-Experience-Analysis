-- ============================================================
-- 05 - OVERVIEW
-- Revenue | Orders | Customers | Avg delivery days | YoY | Seasonality
-- ============================================================

-- ---------- TOTAL REVENUE ----------
SELECT
	SUM(oi.price) AS total_revenue_brl
FROM order_items oi
JOIN orders o
	ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created');
-- Total revenue is approximately R$13.5M across the whole period.
-- (For orientation only: at a flat R$3.50/USD - roughly the 2016-2018
--  average - that is about US$3.9M. Not used in any calculation.)


-- ---------- REVENUE AND ORDERS BY YEAR ----------
SELECT
	EXTRACT(YEAR FROM o.order_purchase_timestamp) AS years,
	SUM(oi.price) AS total_revenue,
	COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_items oi
	ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
GROUP BY years
ORDER BY years;
-- 2018 is the strongest year at ~R$7.3M.
-- CAUTION: 2016 starts partway through the year and 2018 stops in August,
-- so raw year totals are not directly comparable. See the like-for-like
-- Jan-Aug comparison in file 07.


-- ---------- REVENUE AND ORDERS BY CALENDAR MONTH (SEASONALITY) 2017 ----------
-- This shows the revenue and orders for 2017 only, since its the only full year, so it shows seasonality, NOT month-over-month movement.
SELECT
	EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
	SUM(oi.price) AS total_revenue,
	COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_items oi
	ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
	AND EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
GROUP BY month
ORDER BY month;
-- November is the standout at 7,421 orders, up 63% on October - Black Friday.
-- December falls back below it, so Black Friday beats Christmas here.
-- Worth noting the curve is mostly growth, not season: the business grew
-- 5.8x across 2017, so a single year's calendar mostly traces the trend.


-- ---------- REVENUE BY MONTH, SPLIT BY YEAR ----------
SELECT
	EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
	SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2016 THEN oi.price END) AS revenue_2016,
	SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017 THEN oi.price END) AS revenue_2017,
	SUM(CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018 THEN oi.price END) AS revenue_2018,
	SUM(oi.price) AS total_revenue,
	COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_items oi
	ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
GROUP BY month
ORDER BY month;
-- this actually shows the month revenue was recorded (sept 2016)


-- ---------- TOTAL ORDERS ----------
-- No order_items join here, so order_id is already unique per row.
SELECT COUNT(*) AS total_orders
FROM orders
WHERE order_status NOT IN ('unavailable', 'canceled', 'created');
-- 98,202 orders.


-- ---------- ORDERS BY YEAR ----------
SELECT
	EXTRACT(YEAR FROM order_purchase_timestamp) AS years,
	COUNT(*) AS total_orders
FROM orders
WHERE order_status NOT IN ('unavailable', 'canceled', 'created')
GROUP BY years
ORDER BY years;
-- even though total orders for the full year havent been accounted for, 2018 holds the highest number of orders of 53.5k orders


-- ---------- ORDERS BY CALENDAR MONTH, SPLIT BY YEAR ----------
SELECT
	EXTRACT(MONTH FROM order_purchase_timestamp) AS months,
	COUNT(CASE WHEN EXTRACT(YEAR FROM order_purchase_timestamp) = 2016 THEN order_id END) AS orders_2016,
	COUNT(CASE WHEN EXTRACT(YEAR FROM order_purchase_timestamp) = 2017 THEN order_id END) AS orders_2017,
	COUNT(CASE WHEN EXTRACT(YEAR FROM order_purchase_timestamp) = 2018 THEN order_id END) AS orders_2018,
	COUNT(*) AS total_orders
FROM orders
WHERE order_status NOT IN ('unavailable', 'canceled', 'created')
GROUP BY months
ORDER BY months;


-- ---------- REVENUE, FREIGHT AND AVERAGE ORDER VALUE BY MONTH ----------
WITH revenue_and_order_data AS (
	SELECT
		EXTRACT(MONTH FROM o.order_purchase_timestamp) AS months,
		COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2016 THEN o.order_id END) AS orders_2016,
		COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017 THEN o.order_id END) AS orders_2017,
		COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018 THEN o.order_id END) AS orders_2018,
		COUNT(DISTINCT o.order_id) AS total_orders,
		SUM(oi.freight_value) AS freight_value,
		SUM(oi.price) AS total_revenue
	FROM orders o
	JOIN order_items oi
		ON o.order_id = oi.order_id
	WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
	GROUP BY months
)

SELECT
	months,
	orders_2016,
	orders_2017,
	orders_2018,
	total_orders,
	total_revenue,
	freight_value,
	total_revenue + freight_value AS total_order_value,
	ROUND(total_revenue / total_orders, 2) AS average_order_value
FROM revenue_and_order_data
ORDER BY months;
-- average_order_value = revenue per ORDER (freight excluded).
-- total_order_value = what customers actually paid,  freight included.


-- ---------- TOTAL CUSTOMERS ----------
SELECT
	COUNT(DISTINCT c.customer_unique_id) AS total_customers
FROM customers c
JOIN orders o
	ON c.customer_id = o.customer_id
WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created');
-- ~95K distinct people placed at least one order that was not canceled.


-- ---------- AVERAGE DELIVERY DAYS ----------
-- Measured from PURCHASE to doorstep, which is what the customer
-- experiences. Same definition used in the Delivery file.
SELECT
	ROUND(AVG(order_delivered_customer_date::date - order_purchase_timestamp::date)) AS avg_delivery_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_status NOT IN ('unavailable', 'canceled', 'created');
-- ~12 days end to end


-- ---------- YEAR-OVER-YEAR REVENUE GROWTH ----------
WITH revenue AS (
	SELECT
		EXTRACT(YEAR FROM o.order_purchase_timestamp) AS years,
		SUM(oi.price) AS yearly_revenue
	FROM order_items oi
	JOIN orders o
		ON oi.order_id = o.order_id
	WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
	GROUP BY years)

SELECT
	years,
	yearly_revenue,
	ROUND(
		(yearly_revenue - LAG(yearly_revenue) OVER (ORDER BY years)) * 100.0
		/ LAG(yearly_revenue) OVER (ORDER BY years)
	, 2) AS yoy_growth_pct
FROM revenue
ORDER BY years;
-- due to the incomplete/ business starting towards the end of 2016, the numbers have a ~ x135 jump in 2017.
-- the 2018 figure here (20%) is misleading in the other direction, it compares 12 months of 2017
-- against 8 months of 2018. the like-for-like version is below.


-- ---------- LIKE-FOR-LIKE REVENUE GROWTH, JAN-AUG ----------
-- Both years cut to the same eight months so the comparison is fair.
SELECT
	EXTRACT(YEAR FROM o.order_purchase_timestamp) AS years,
	SUM(oi.price) AS revenue_jan_to_aug,
	COUNT(DISTINCT o.order_id) AS orders_jan_to_aug
FROM orders o
JOIN order_items oi
	ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
  AND EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
  AND EXTRACT(YEAR FROM o.order_purchase_timestamp) IN (2017, 2018)
GROUP BY years
ORDER BY years;
-- R$3,080,850 in 2017 against R$7,341,037 in 2018, which is 138.3% growth.
-- the raw year-on-year number above says 20%, so it understates the business
-- by nearly 7x. worth being careful with.


-- ---------- MONTH-OVER-MONTH REVENUE GROWTH (TRUE SEQUENTIAL) ----------
-- DATE_TRUNC keeps each calendar month of each year separate, so this is
-- genuine month-over-month rather than seasonality.
WITH monthly_revenue AS (
	SELECT
		DATE_TRUNC('month', o.order_purchase_timestamp) AS month_start,
		SUM(oi.price) AS monthly_revenue
	FROM order_items oi
	JOIN orders o
		ON oi.order_id = o.order_id
	WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
	GROUP BY month_start
)

SELECT
	month_start,
	monthly_revenue,
	ROUND((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month_start)) * 100.0/ NULLIF(LAG(monthly_revenue) OVER (ORDER BY month_start), 0), 2) AS mom_growth_pct
FROM monthly_revenue
ORDER BY month_start;
