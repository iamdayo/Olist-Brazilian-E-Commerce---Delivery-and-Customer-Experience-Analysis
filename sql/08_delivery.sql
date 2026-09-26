-- ============================================================
-- 08 - DELIVERY
-- ============================================================

-- ---------- HOW DO CUSTOMERS EXPERIENCE DELIVERY BY CITY? ----------
-- For CUSTOMERS the right delivery time is the full journey: purchase -> doorstep.
SELECT
	c.customer_city,
	COUNT(DISTINCT c.customer_unique_id) AS total_customers,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(AVG(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)) AS avg_delivery_days
FROM
	customers c JOIN orders o
	ON c.customer_id = o.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY c.customer_city
HAVING COUNT(DISTINCT o.order_id) >= 20
ORDER BY avg_delivery_days DESC
LIMIT 20;
-- i raised the Threshold to 20 for consistency with every other grouped
-- average in this script. City rankings should be re-read from this run.


-- ---------- SPLITTING THE JOURNEY INTO ITS STAGES ----------
SELECT
	c.customer_city,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(AVG(o.order_approved_at::date - o.order_purchase_timestamp::date)) AS approval_days,
	ROUND(AVG(o.order_delivered_carrier_date::date - o.order_approved_at::date)) AS dispatch_days,
	ROUND(AVG(o.order_delivered_customer_date::date - o.order_delivered_carrier_date::date)) AS transit_days,
	ROUND(AVG(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)) AS total_delivery_days
FROM customers c
JOIN orders o
	ON c.customer_id = o.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_approved_at IS NOT NULL
  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY c.customer_city
HAVING COUNT(DISTINCT o.order_id) >= 20
ORDER BY transit_days DESC;
-- ~12 days total, of which only ~3 is seller dispatch. The remaining
-- ~9 days sit in the carrier leg.


-- ---------- IS DELIVERY AFFECTED BY DISTANCE? (CITY LEVEL) ----------
-- Requires PostGIS. geolocation has multiple rows per zip prefix, so the
-- coordinates are averaged per prefix first.
WITH geo AS (
	SELECT
		geolocation_zip_code_prefix,
		AVG(geolocation_lat) AS lat,
		AVG(geolocation_lng) AS lng
	FROM geolocation
	GROUP BY geolocation_zip_code_prefix
),

delivery_analysis AS (
	SELECT
		c.customer_city,
		COUNT(DISTINCT o.order_id) AS total_orders,
		ROUND(AVG(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)) AS total_delivery_days,
		ROUND(AVG(o.order_delivered_carrier_date::date - o.order_approved_at::date)) AS dispatch_days,
		ROUND(AVG(o.order_delivered_customer_date::date - o.order_delivered_carrier_date::date)) AS transit_days,
		ROUND(AVG(
			ST_DistanceSphere(
				ST_MakePoint(seller_geo.lng, seller_geo.lat),
				ST_MakePoint(customer_geo.lng, customer_geo.lat)
			) / 1000
		)::numeric, 2) AS avg_distance_km
	FROM
		orders o JOIN order_items oi
		ON o.order_id = oi.order_id JOIN customers c
		ON o.customer_id = c.customer_id JOIN sellers s
		ON oi.seller_id = s.seller_id JOIN geo customer_geo
		ON c.customer_zip_code_prefix = customer_geo.geolocation_zip_code_prefix JOIN geo seller_geo
		ON s.seller_zip_code_prefix = seller_geo.geolocation_zip_code_prefix
	WHERE o.order_delivered_customer_date IS NOT NULL
		AND o.order_delivered_carrier_date IS NOT NULL
		AND o.order_approved_at IS NOT NULL
		AND c.customer_city IS NOT NULL
		AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
	GROUP BY c.customer_city
	HAVING COUNT(DISTINCT o.order_id) >= 20
)

SELECT *
FROM delivery_analysis
ORDER BY avg_distance_km DESC;
/*
   Dispatch stays flat at ~3 days regardless of distance, so the distance
   effect lives entirely in the carrier leg.

   SCOPE NOTE: this restricts the analysis from 4,037 cities to 536
   high-volume ones. That is a deliberate trade-off, meaningful averages
   in exchange for excluding the long tail, and is stated openly rather
   than left for a reader to discover.

   This version groups by city first, which means each city counts once
   regardless of how many orders it has. The per-order version below is
   the cleaner one and is what the README reports.
*/


-- ---------- THE SAME QUESTION PER ORDER ----------
-- Runs off the order_analysis view (file 11), so run that first.
-- Every order counted individually rather than averaged by city.
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
	COUNT(*) AS orders,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dispatch_days) AS median_dispatch_days,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY transit_days) AS median_transit_days
FROM order_analysis
WHERE distance_km IS NOT NULL
  AND dispatch_days >= 0
  AND transit_days >= 0
GROUP BY distance_band
ORDER BY distance_band;
/*
   Under 250km    3 days transit
   250-500km      7
   500-750km      8
   750-1000km     9
   1000-1500km   12
   1500-2000km   14
   Over 2000km   15

   Transit goes 3 -> 15 days, a 5x increase. Dispatch is 2 days in every
   single band. Whatever is causing the slowdown, it is not the sellers.
*/


-- ---------- DO ESTIMATED DELIVERY DATES MATCH ACTUAL DELIVERY? CITY LEVEL ----------
SELECT
	c.customer_city,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(AVG(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)) AS actual_days,
	ROUND(AVG(o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date)) AS estimated_days
FROM orders o
JOIN customers c
	ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND c.customer_city IS NOT NULL
  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY c.customer_city
HAVING COUNT(DISTINCT o.order_id) >= 20
ORDER BY actual_days DESC;
-- At city level EVERY city delivers ahead of estimate on average.
-- That is true, but averaging inside a city hides the late orders. See below.


-- ---------- THE SAME QUESTION AT ORDER LEVEL ----------
-- Averaging within a city cancels early deliveries against late ones.
--A city where half the orders arrive 10 days early and half arrive 5 days late averages out to "on time" while thousands of customers were letdown.
-- Lateness has to be judged per ORDER.
WITH late_check AS (
    SELECT
        order_id,
        order_delivered_customer_date::date - order_estimated_delivery_date::date AS days_late
    FROM orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_status NOT IN ('canceled', 'unavailable', 'created')
)

SELECT
    COUNT(CASE WHEN days_late > 0 THEN 1 END) AS late_orders,
    COUNT(CASE WHEN days_late > 5 THEN 1 END) AS late_over_5_days,
    COUNT(CASE WHEN days_late > 20 THEN 1 END) AS late_over_20_days,
    COUNT(CASE WHEN days_late > 50 THEN 1 END) AS late_over_50_days,
    COUNT(CASE WHEN days_late > 100 THEN 1 END) AS late_over_100_days,
    COUNT(*) AS total_delivered_orders,
    ROUND(COUNT(CASE WHEN days_late > 0 THEN 1 END) * 100.0 / COUNT(*), 2) AS pct_late
FROM late_check;
/*
   late at all      6,534   6.77% of delivered orders
   > 5 days late    3,764   3.90%
   > 20 days late     795   0.82%
   > 50 days late     114   0.12%
   > 100 days late     39   0.04%

   So ~93% arrive on or before the promised date. Note these thresholds
   are cumulative - the 3,764 are inside the 6,534.
*/


-- ---------- WHERE DOES THE DELAY HAPPEN ON EXTREME-LATE ORDERS? ----------
SELECT
	order_id,
	order_delivered_customer_date::date - order_estimated_delivery_date::date AS days_late,
	order_delivered_carrier_date::date - order_approved_at::date AS dispatch_days,
	order_delivered_customer_date::date - order_delivered_carrier_date::date AS transit_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_approved_at IS NOT NULL
  AND order_status NOT IN ('canceled', 'unavailable', 'created')
  AND order_delivered_customer_date::date - order_estimated_delivery_date::date > 50
ORDER BY days_late DESC;
/*
   FINDING: of the 114 orders more than 50 days late, 111 are TRANSIT
   failures, not seller failures.
     median dispatch:   2 days  (faster than the 3-day overall average)
     median transit:   99 days
   The worst case was dispatched in 3 days then spent 205 days in transit.

   So the sellers on these orders did their job faster than average, and the
   parcel then disappeared into the carrier network for three months.

   Three separate checks now say the same thing: dispatch is flat everywhere,
   transit scales with distance, and every delivery disaster is a transit
   failure. Olist's delivery problem is a CARRIER problem, and
   seller-facing interventions will not move the number.
*/


-- ---------- DATA QUALITY: IMPOSSIBLE DATE SEQUENCES ----------
SELECT
	COUNT(CASE WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 END) AS delivered_before_dispatch,
	COUNT(CASE WHEN order_delivered_carrier_date < order_approved_at THEN 1 END) AS dispatched_before_approval,
	COUNT(CASE WHEN order_approved_at < order_purchase_timestamp THEN 1 END) AS approved_before_purchase
FROM orders
WHERE order_delivered_customer_date IS NOT NULL;
-- A small number of rows have delivery recorded before dispatch. These are
-- reported rather than silently dropped, and are excluded from timing
-- averages where they would distort the result.
