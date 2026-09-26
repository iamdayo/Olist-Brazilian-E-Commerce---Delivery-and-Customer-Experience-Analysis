-- ============================================================
-- 12 - REVIEWS VS EVERYTHING ELSE, AND FREIGHT
--
-- The first three queries run off the order_analysis view, so file 11
-- has to run before this one.
-- ============================================================

-- ---------- REVIEWS VS PAYMENT TYPE ----------
SELECT
	payment_type,
	COUNT(*) AS orders,
	ROUND(AVG(review_score), 2) AS avg_review_score
FROM order_analysis
WHERE review_score IS NOT NULL
GROUP BY payment_type
HAVING COUNT(*) >= 20
ORDER BY avg_review_score DESC;
-- barely any movement. every payment type falls between 4.08 and 4.19,
-- a 0.11 spread. payment type does not affect how people rate an order.


-- ---------- REVIEWS VS CATEGORY ----------
SELECT
	category_name,
	COUNT(*) AS orders,
	ROUND(AVG(review_score), 2) AS avg_review_score
FROM order_analysis
WHERE review_score IS NOT NULL
  AND category_name IS NOT NULL
GROUP BY category_name
HAVING COUNT(*) >= 20
ORDER BY avg_review_score DESC;
-- same story for category. everything stays above 4.0 and tops out at 4.35,
-- a 0.32 spread across thirteen very different product types.


-- ---------- REVIEWS VS PRICE ----------
SELECT
	CASE
		WHEN order_value < 50 THEN 'Under R$50'
		WHEN order_value < 100 THEN 'R$50-100'
		WHEN order_value < 200 THEN 'R$100-200'
		WHEN order_value < 500 THEN 'R$200-500'
		ELSE 'R$500+'
	END AS price_band,
	COUNT(*) AS orders,
	ROUND(AVG(review_score), 2) AS avg_review_score
FROM order_analysis
WHERE review_score IS NOT NULL
  AND order_value IS NOT NULL
GROUP BY price_band
HAVING COUNT(*) >= 20;
-- 3.96 to 4.18. this one at least has a clean direction - every band drops
-- as price rises, no exceptions, so people expect more when they spend more.
-- but the whole range is 0.22 points against delivery's 2.69. delivery is
-- the only thing that really moves the score.


-- ---------- UNUSUALLY HIGH FREIGHT: SET THE THRESHOLD ----------
SELECT
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY freight_value) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY freight_value) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY freight_value) AS p90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY freight_value) AS p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY freight_value) AS p99,
    MAX(freight_value) AS max_freight
FROM order_items;
-- shipping is cheap for almost everything. the middle item costs R$16.26,
-- 9 in 10 cost under R$34.04. then it runs away - the last 1% goes from
-- R$84.52 up to R$409.68.
-- p95 (R$45.12) is used as the "high freight" line below because it keeps a
-- workable sample of 5,630 items. the real break is at p99.


-- ---------- HIGH FREIGHT VS PRODUCT WEIGHT ----------
SELECT
	CASE
		WHEN oi.freight_value > ( SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY freight_value) FROM order_items
		) THEN 'High Freight'
		ELSE 'Normal Freight'
	END AS freight_band,
	COUNT(*) AS items,
	ROUND(AVG(p.product_weight_g)) AS avg_weight_g,
	ROUND(AVG(oi.freight_value), 2) AS avg_freight,
	ROUND(AVG(oi.price), 2) AS avg_price
FROM
	order_items oi JOIN products p
	ON oi.product_id = p.product_id
GROUP BY freight_band;
-- we used the 95th percentile as the threshold, and it was seen that high freight items are 5630 in count, and the weight of those high freight on avg is about 10.2kg which is x6 of normal freight (1.6kg)
-- and this significantly shows in the freight price, where the 10kg items have an avg freight of 71R$ and 1.6kg items are 17R$, customers should definitely expect an average of 70R$ if theyre going to order items of at least 10kg


-- ---------- HIGH FREIGHT VS LOCATION ----------
WITH freight_threshold AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY freight_value) AS p95
    FROM order_items
)

SELECT
    c.customer_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight,
    ROUND(
        COUNT(CASE WHEN oi.freight_value > ft.p95 THEN 1 END) * 100.0 / COUNT(*)
    , 2) AS pct_high_freight
FROM
	order_items oi JOIN orders o
    ON oi.order_id = o.order_id JOIN customers c
    ON o.customer_id = c.customer_id CROSS JOIN freight_threshold ft
WHERE o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY c.customer_state
HAVING COUNT(DISTINCT oi.order_id) >= 20
ORDER BY pct_high_freight DESC;
-- location matters a lot. Acre has 30.43% high-freight orders against Sao
-- Paulo's 2.21%, which is 13.8x, and R$40.07 average freight against R$15.15.
-- the expensive states are the remote north, the cheap ones the industrial
-- southeast. same geography as the delivery finding.


-- ---------- FREIGHT VS DISTANCE, WITH WEIGHT HELD FLAT ----------
WITH geo AS (
	SELECT
		geolocation_zip_code_prefix,
		AVG(geolocation_lat) AS lat,
		AVG(geolocation_lng) AS lng
	FROM geolocation
	GROUP BY geolocation_zip_code_prefix
),

item_distance AS (
	SELECT
		oi.order_id,
		oi.order_item_id,
		oi.freight_value,
		oi.price,
		p.product_weight_g,
		ST_DistanceSphere(
			ST_MakePoint(seller_geo.lng, seller_geo.lat),
			ST_MakePoint(customer_geo.lng, customer_geo.lat)
		) / 1000 AS distance_km
	FROM order_items oi
	JOIN orders o
		ON oi.order_id = o.order_id
	JOIN customers c
		ON o.customer_id = c.customer_id
	JOIN sellers s
		ON oi.seller_id = s.seller_id
	JOIN products p
		ON oi.product_id = p.product_id
	JOIN geo customer_geo
		ON c.customer_zip_code_prefix = customer_geo.geolocation_zip_code_prefix
	JOIN geo seller_geo
		ON s.seller_zip_code_prefix = seller_geo.geolocation_zip_code_prefix
	WHERE o.order_status NOT IN ('canceled', 'unavailable', 'created')
)

SELECT
	CASE
		WHEN distance_km < 250 THEN '1. Under 250km'
		WHEN distance_km < 500 THEN '2. 250-500km'
		WHEN distance_km < 750 THEN '3. 500-750km'
		WHEN distance_km < 1000 THEN '4. 750-1000km'
		WHEN distance_km < 1500 THEN '5. 1000-1500km'
		WHEN distance_km < 2000 THEN '6. 1500-2000km'
		ELSE '7. Over 2000km'
	END AS distance_band,
	COUNT(*) AS total_items,
	ROUND(AVG(freight_value), 2) AS avg_freight,
	ROUND(AVG(product_weight_g)) AS avg_weight_g,
	ROUND(AVG(price), 2) AS avg_price
FROM item_distance
GROUP BY distance_band
HAVING COUNT(*) >= 20
ORDER BY distance_band;
/*
   Weight is flat at roughly 2kg across every distance band while average
   freight rises from R$13.16 to R$35.92, a 173% increase with the weight
   variable effectively held constant.

   So weight is not the only driver. Heavy parcels cost more at any distance,
   and distant parcels cost more at any weight. This is the same distance
   story as the delivery finding, expressed in money instead of time.

   CAVEAT: avg_price also climbs across the bands, R$105 to R$157. So
   distance and item value are not fully separated here. weight is
   controlled for, value is not.

   Also straight-line distance, not road distance. Brazil's road network is
   far denser in the southeast, so the far bands understate real travel.
*/


-- ---------- HOLDING THE SELLER CONSTANT ----------
-- The objection to everything above is that distant customers might just
-- have worse sellers. So: the five highest-volume seller cities, each one
-- broken down by distance. Same sellers, same warehouses, only distance
-- changes.
WITH geo AS (
	SELECT
		geolocation_zip_code_prefix,
		AVG(geolocation_lat) AS lat,
		AVG(geolocation_lng) AS lng
	FROM geolocation
	GROUP BY geolocation_zip_code_prefix
),

order_distance AS (
	SELECT
		s.seller_city,
		o.order_id,
		o.order_delivered_customer_date::date - o.order_delivered_carrier_date::date AS transit_days,
		ST_DistanceSphere(
			ST_MakePoint(seller_geo.lng, seller_geo.lat),
			ST_MakePoint(customer_geo.lng, customer_geo.lat)
		) / 1000 AS distance_km
	FROM orders o
	JOIN order_items oi
		ON o.order_id = oi.order_id
	JOIN customers c
		ON o.customer_id = c.customer_id
	JOIN sellers s
		ON oi.seller_id = s.seller_id
	JOIN geo customer_geo
		ON c.customer_zip_code_prefix = customer_geo.geolocation_zip_code_prefix
	JOIN geo seller_geo
		ON s.seller_zip_code_prefix = seller_geo.geolocation_zip_code_prefix
	WHERE o.order_delivered_customer_date IS NOT NULL
	  AND o.order_delivered_carrier_date IS NOT NULL
	  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
),

top_seller_cities AS (
	SELECT seller_city
	FROM order_distance
	GROUP BY seller_city
	ORDER BY COUNT(DISTINCT order_id) DESC
	LIMIT 5
)

SELECT
	od.seller_city,
	CASE
		WHEN od.distance_km < 250 THEN '1. Under 250km'
		WHEN od.distance_km < 500 THEN '2. 250-500km'
		WHEN od.distance_km < 1000 THEN '3. 500-1000km'
		WHEN od.distance_km < 2000 THEN '4. 1000-2000km'
		ELSE '5. Over 2000km'
	END AS distance_band,
	COUNT(DISTINCT od.order_id) AS orders,
	ROUND(AVG(od.transit_days)) AS avg_transit_days
FROM order_distance od
JOIN top_seller_cities t
	ON od.seller_city = t.seller_city
GROUP BY od.seller_city, distance_band
HAVING COUNT(DISTINCT od.order_id) >= 20
ORDER BY od.seller_city, distance_band;
/*
   belo horizonte   4   8   8   13   22
   curitiba         5   7  10   13   18
   ibitinga         7   8  14   17   21
   santo andre      4   9  10   15   17
   sao paulo        4   9  10   15   16

   Five cities, five climbs, no exceptions. Each one roughly quadruples its
   transit time from nearest band to farthest. Same sellers throughout, so
   the slowdown is distance, not the sellers.

   Two things the platform average hides:

   - ibitinga is slower at every distance, 7 days under 250km where the
     others manage 4 or 5. it is a furniture town shipping bulky goods,
     which is a plausible reason but not one this data can prove.

   - sao paulo's volume is short-haul: 9,671 orders under 250km against
     1,724 over 2,000km. its average looks good because most of its orders
     are short trips. the slow long-distance ones are there, just too few
     to move the average.
*/
