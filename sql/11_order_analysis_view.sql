-- ============================================================
-- 11 - ORDER-LEVEL BASE TABLE (VIEW)
--
-- One row per order, every attribute attached. This is what file 12
-- runs on, and what the Power BI model connects to.
--
-- The design point: each CTE collapses to one row per order BEFORE
-- joining. Without that, order_items and payments multiply against each
-- other and a three-item order with two payments produces six rows.
-- ============================================================

DROP VIEW IF EXISTS order_analysis;

CREATE VIEW order_analysis AS
WITH geo AS (
	SELECT
		geolocation_zip_code_prefix,
		AVG(geolocation_lat) AS lat,
		AVG(geolocation_lng) AS lng
	FROM geolocation
	GROUP BY geolocation_zip_code_prefix
),

items AS (
	SELECT
		oi.order_id,
		SUM(oi.price) AS order_value,
		SUM(oi.freight_value) AS freight,
		COUNT(*) AS item_count,
		COUNT(DISTINCT oi.seller_id) AS seller_count,
		SUM(p.product_weight_g) AS total_weight_g
	FROM order_items oi
	LEFT JOIN products p
		ON oi.product_id = p.product_id
	GROUP BY oi.order_id
),

top_category AS (
	-- Multi-item orders span categories; the highest-priced item wins.
	SELECT DISTINCT ON (oi.order_id)
		oi.order_id,
		p.category_name
	FROM order_items oi
	JOIN products p
		ON oi.product_id = p.product_id
	ORDER BY oi.order_id, oi.price DESC
),

top_seller AS (
	-- Same rule as top_category, so seller_city and distance_km always
	-- describe the same shipment.
	SELECT DISTINCT ON (oi.order_id)
		oi.order_id,
		s.seller_city,
		s.seller_state,
		s.seller_zip_code_prefix
	FROM order_items oi
	JOIN sellers s
		ON oi.seller_id = s.seller_id
	ORDER BY oi.order_id, oi.price DESC
),

pay AS (
	-- Split payments: the largest payment determines the recorded type.
	SELECT DISTINCT ON (order_id)
		order_id,
		payment_type,
		payment_installments
	FROM payments
	ORDER BY order_id, payment_value DESC
),

rev AS (
	-- reviews contains duplicate rows; keep the most recent per order.
	SELECT DISTINCT ON (order_id)
		order_id,
		review_score
	FROM reviews
	ORDER BY order_id, review_creation_date DESC
)

SELECT
	o.order_id,
	c.customer_unique_id,
	c.customer_city,
	c.customer_state,
	ts.seller_city,
	ts.seller_state,
	o.order_purchase_timestamp,
	o.order_status,
	o.order_approved_at::date - o.order_purchase_timestamp::date AS approval_days,
	o.order_delivered_carrier_date::date - o.order_approved_at::date AS dispatch_days,
	o.order_delivered_customer_date::date - o.order_delivered_carrier_date::date AS transit_days,
	o.order_delivered_customer_date::date - o.order_purchase_timestamp::date AS delivery_days,
	o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date AS days_late,
	ROUND((ST_DistanceSphere(
		ST_MakePoint(sg.lng, sg.lat),
		ST_MakePoint(cg.lng, cg.lat)
	) / 1000)::numeric, 2) AS distance_km,
	rev.review_score,
	pay.payment_type,
	pay.payment_installments,
	i.order_value,
	i.freight,
	i.item_count,
	i.seller_count,
	i.total_weight_g,
	tc.category_name
FROM orders o
JOIN customers c
	ON o.customer_id = c.customer_id
LEFT JOIN items i
	ON o.order_id = i.order_id
LEFT JOIN top_category tc
	ON o.order_id = tc.order_id
LEFT JOIN top_seller ts
	ON o.order_id = ts.order_id
LEFT JOIN pay
	ON o.order_id = pay.order_id
LEFT JOIN rev
	ON o.order_id = rev.order_id
LEFT JOIN geo sg
	ON ts.seller_zip_code_prefix = sg.geolocation_zip_code_prefix
LEFT JOIN geo cg
	ON c.customer_zip_code_prefix = cg.geolocation_zip_code_prefix
WHERE o.order_status NOT IN ('canceled', 'unavailable', 'created');


-- MANDATORY CHECK - these two numbers must match, and must be 98,202.
SELECT
	COUNT(*) AS rows,
	COUNT(DISTINCT order_id) AS distinct_orders
FROM order_analysis;
