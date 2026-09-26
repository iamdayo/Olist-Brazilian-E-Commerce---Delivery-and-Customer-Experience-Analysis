-- ============================================================
-- 07 - LOCATION AND PRODUCT
-- ============================================================

-- ---------- WHERE ARE THE SELLERS? ----------
SELECT
	seller_city,
	COUNT(DISTINCT seller_id) AS total_sellers
FROM sellers
GROUP BY seller_city
ORDER BY total_sellers DESC
LIMIT 10;
-- Sao Paulo dominates and the next city is not close
-- sellers are listing on the platform and do not have  a physical store branch


-- ---------- WHERE ARE THE CUSTOMERS? ----------
SELECT
	customer_city,
	COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers
GROUP BY customer_city
ORDER BY total_customers DESC
LIMIT 10;
-- Sao Paulo again, unsurprising


-- ---------- DO CITIES WITH MORE SELLERS DISPATCH FASTER? ----------
-- For SELLERS the right metric is DISPATCH time (approved -> carrier).
-- Sellers do not control what happens after the carrier collects, so measuring them on full delivery time would be unfair.
WITH seller_dispatch AS (
	SELECT
		s.seller_city,
		COUNT(DISTINCT s.seller_id) AS total_sellers,
		COUNT(DISTINCT o.order_id) AS total_orders,
		ROUND(AVG(o.order_delivered_carrier_date::date - o.order_approved_at::date)) AS avg_dispatch_days
	FROM
		sellers s JOIN order_items oi
		ON s.seller_id = oi.seller_id JOIN orders o
		ON oi.order_id = o.order_id
	WHERE o.order_delivered_carrier_date IS NOT NULL
	  AND o.order_approved_at IS NOT NULL
	  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
	GROUP BY s.seller_city
	HAVING COUNT(DISTINCT o.order_id) >= 20
)

SELECT
	seller_city,
	total_sellers,
	total_orders,
	avg_dispatch_days,
	CASE
		WHEN avg_dispatch_days > 5 THEN 'Long Dispatch'
		ELSE 'Short Dispatch'
	END AS dispatch_flag
FROM seller_dispatch
ORDER BY avg_dispatch_days  DESC
LIMIT 20;

-- the seller cities which have the most orders and most sellers actually have short dispatch days, compare to the orders who have low sellers and low oders
/*
   Overall average dispatch time is ~3 days.
   The 5-day threshold is a deliberate choice: it is roughly 67% above the
   average, and a seller taking 5+ days to even hand the parcel over is
   underperforming by any reasonable standard.
*/


-- ---------- OVERALL AVERAGE DISPATCH TIME ----------
SELECT
	ROUND(AVG(order_delivered_carrier_date::date - order_approved_at::date), 2) AS avg_dispatch_days
FROM orders
WHERE order_delivered_carrier_date IS NOT NULL
  AND order_approved_at IS NOT NULL
  AND order_status NOT IN ('canceled', 'unavailable', 'created');
-- ~3 days from approval to carrier collection.


-- ---------- CATEGORY SALES ----------
SELECT
	p.category_name,
	SUM(oi.price) AS revenue,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM products p
JOIN order_items oi
	ON p.product_id = oi.product_id
JOIN orders o
	ON oi.order_id = o.order_id
WHERE p.category_name IS NOT NULL
  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY p.category_name
HAVING COUNT(DISTINCT o.order_id) >= 20
ORDER BY revenue DESC;


-- ---------- TOP INDIVIDUAL PRODUCTS ----------
-- The queries above are at CATEGORY level. This one answers the question
-- at actual PRODUCT level.
SELECT
	oi.product_id,
	p.category_name,
	COUNT(DISTINCT o.order_id) AS total_orders,
	SUM(oi.price) AS revenue
FROM order_items oi
JOIN orders o
	ON oi.order_id = o.order_id
JOIN products p
	ON oi.product_id = p.product_id
WHERE o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY oi.product_id, p.category_name
ORDER BY revenue DESC
LIMIT 20;


-- ---------- CATEGORY GROWTH, LIKE FOR LIKE ----------
-- 2018 data stops in August (see file 04), so both years are restricted to Jan-Aug.
-- 2016 is excluded entirely: it covers only a few months at the end of the year and produces meaningless growth percentages off a tiny base.
WITH category_yoy AS (
	SELECT
		p.category_name,
		COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017 THEN o.order_id END) AS orders_2017,
		COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018 THEN o.order_id END) AS orders_2018
	FROM orders o
	JOIN order_items oi
		ON o.order_id = oi.order_id
	JOIN products p
		ON oi.product_id = p.product_id
	WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
	  AND p.category_name IS NOT NULL
	  AND EXTRACT(MONTH FROM o.order_purchase_timestamp) BETWEEN 1 AND 8
	GROUP BY p.category_name
)

SELECT
	category_name,
	orders_2017,
	orders_2018,
	ROUND((orders_2018 - orders_2017) * 100.0 / NULLIF(orders_2017, 0), 2) AS growth_pct
FROM category_yoy
WHERE orders_2017 >= 20
ORDER BY growth_pct DESC;
/*
   Only "Other" declined. Every other category grew, most by more than 100%.

   The growth ranking is almost the reverse of the size ranking. Construction
   & Tools grew nearly 15x off a base of 106 orders, while Home & Furniture -
   the biggest category at R$3.35M - roughly doubled off a base of 6,719.
   A big base growing slowly is a different business problem from a small
   base growing fast.

   Be careful with the 1,484% though. It clears the 20-order guard but only
   just, and in absolute terms it added 1,574 orders. Small bases make big
   percentages.

   The orders_2017 >= 20 filter keeps out categories with a negligible 2017
   base, where the percentage would be meaningless.
*/
