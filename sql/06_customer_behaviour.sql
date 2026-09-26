-- ============================================================
-- 06 - CUSTOMER BEHAVIOUR
-- ============================================================

-- ---------- WHICH CATEGORY DO CUSTOMERS BUY THE MOST? ----------
WITH category_revenue AS (
	SELECT
		p.category_name,
		COUNT(DISTINCT o.order_id) AS total_orders,
		SUM(oi.price) AS total_revenue,
		COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2016 THEN o.order_id END) AS orders_2016,
		COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017 THEN o.order_id END) AS orders_2017,
		COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018 THEN o.order_id END) AS orders_2018
	FROM products p
	JOIN order_items oi
		ON p.product_id = oi.product_id
	JOIN orders o
		ON oi.order_id = o.order_id
	WHERE p.category_name IS NOT NULL
	  AND o.order_status NOT IN ('unavailable', 'canceled', 'created')
	GROUP BY p.category_name
	HAVING COUNT(DISTINCT o.order_id) >= 20
)

SELECT
	category_name,
	total_orders,
	total_revenue,
	orders_2016,
	orders_2017,
	orders_2018,
	ROUND(total_revenue / total_orders, 2) AS average_order_value
FROM category_revenue
ORDER BY average_order_value DESC;
/*
   - Home & Furniture leads on both revenue and order count; the second
     category brings in roughly half its revenue.
   - Gifts has the highest average order value at ~R$214.
   - Food & Drinks has the fewest orders and is worth investigating.
   NOTE: an order containing items from several categories is counted once
   in each of those categories, so the category order counts sum to more
   than the 98,202 total. This is expected for a category breakdown.
*/


-- ---------- WHICH CATEGORY DO CUSTOMERS REVIEW THE HIGHEST? ----------
SELECT
	p.category_name,
	ROUND(AVG(r.review_score), 2) AS average_review_score,
	COUNT(DISTINCT r.order_id) AS total_reviews
FROM
	reviews r JOIN orders o
	ON r.order_id = o.order_id JOIN order_items oi
	ON r.order_id = oi.order_id JOIN products p
	ON oi.product_id = p.product_id
WHERE p.category_name IS NOT NULL
	AND o.order_status NOT IN ('unavailable', 'canceled', 'created')
GROUP BY p.category_name
HAVING COUNT(DISTINCT r.order_id) >= 20
ORDER BY average_review_score DESC;
-- Home & Furniture carries the most reviews AND the lowest average score.
-- volume is not the reason though - Electronics & Computers has 14,158 reviews
-- at 4.04 while Sports & Leisure has 12,575 at 4.19. the two lowest scoring
-- categories are the two bulkiest, which points back at delivery rather than
-- at the products themselves.


-- ---------- WHAT SHARE OF REVIEWS ARE LOW (1-2 STARS)? ----------
-- Overall first.
WITH reviews_analysis AS (
	SELECT
		COUNT(DISTINCT r.order_id) AS total_reviews,
		COUNT(DISTINCT CASE WHEN r.review_score <= 2 THEN r.order_id END) AS low_reviews
	FROM
		reviews r JOIN orders o
		ON r.order_id = o.order_id JOIN order_items oi
		ON r.order_id = oi.order_id JOIN products p
		ON oi.product_id = p.product_id
	WHERE p.category_name IS NOT NULL
	  AND o.order_status NOT IN ('unavailable', 'canceled', 'created')
)

SELECT
	total_reviews,
	low_reviews,
	ROUND(low_reviews * 100.0 / total_reviews, 2) AS pct_low_reviews
FROM reviews_analysis;
-- Around ~14% of reviews are 1-2 stars, i.e. roughly 1 in 7.


-- Then per category.
WITH reviews_analysis AS (
	SELECT
		p.category_name,
		COUNT(DISTINCT r.order_id) AS total_reviews,
		COUNT(DISTINCT CASE WHEN r.review_score <= 2 THEN r.order_id END) AS low_reviews
	FROM
		reviews r JOIN orders o
		ON r.order_id = o.order_id JOIN order_items oi
		ON r.order_id = oi.order_id JOIN products p
		ON oi.product_id = p.product_id
	WHERE p.category_name IS NOT NULL
	  AND o.order_status NOT IN ('unavailable', 'canceled', 'created')
	GROUP BY p.category_name
	HAVING COUNT(DISTINCT r.order_id) >= 20
)

SELECT
	category_name,
	total_reviews,
	low_reviews,
	ROUND(low_reviews * 100.0 / total_reviews, 2) AS pct_low_reviews
FROM reviews_analysis
ORDER BY pct_low_reviews DESC;
-- Low-review share sits in a fairly tight 10-16% band across categories.
-- The consistency across very different product types suggests the driver is something common to all orders rather than product quality
--  which points at the delivery experience


-- ---------- CATEGORIES BOUGHT EARLY THEN ABANDONED ----------
SELECT
	EXTRACT(YEAR FROM order_purchase_timestamp) AS years,
	COUNT(*) AS orders,
	MIN(order_purchase_timestamp) AS first_order,
	MAX(order_purchase_timestamp) AS last_order
FROM orders
GROUP BY years
ORDER BY years;
/*
   NOT ANSWERED - the data does not support it.
   2016 covers only part of the year, 2018 stops in August, and only 2017
   is complete. Defining a "beginning" period and an "abandoned" period
   from this would produce an artefact of the collection window rather than
   a real behavioural trend. The like-for-like Jan-Aug 2017 vs 2018 growth
   comparison in file 07 answers the underlying question more honestly.
*/


-- ---------- CUSTOMERS WHO STOPPED BUYING ----------
SELECT
	orders_per_customer,
	COUNT(*) AS customers
FROM
	(SELECT
		c.customer_unique_id,
		COUNT(DISTINCT o.order_id) AS orders_per_customer
	FROM
		customers c JOIN orders o
		ON c.customer_id = o.customer_id
	WHERE o.order_status NOT IN ('unavailable', 'canceled', 'created')
	GROUP BY c.customer_unique_id
) t
GROUP BY orders_per_customer
ORDER BY orders_per_customer;
/*
   With the data we have, it shows that Olist's repeat-purchase
   rate is very low, the overwhelming majority of customers appear exactly
   once. "Stopped buying" would therefore describe almost every customer in
   the dataset and would say nothing about churn, only about the platform's
   one-and-done purchase pattern.

   92,099 of 94,986 customers ordered exactly once - 97%. that is the
   finding, not a data limitation.
*/
