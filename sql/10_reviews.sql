-- ============================================================
-- 10 - REVIEWS VS DELIVERY
-- ============================================================

-- ---------- AVERAGE REVIEW SCORE BY LATENESS BAND ----------
SELECT
	CASE
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 0 THEN 'On Time'
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 5 THEN '1-5 days late'
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 15 THEN '6-15 days late'
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 30 THEN '16-30 days late'
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 45 THEN '31-45 days late'
		ELSE '45+ days late'
	END AS lateness_band,
	COUNT(DISTINCT o.order_id) AS orders,
	ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM
	orders o JOIN reviews r
	ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY lateness_band
ORDER BY avg_review_score DESC;
/*
     On Time          4.29
     1-5 days late    2.99
     6-15 days late   1.74
     16-30 days late  1.60
     31-45 days late  1.68
     45+ days late    2.54   <- breaks the pattern

   KEY FINDING: the damage happens fast. On time scores 4.29; just 1-5 days
   late drops to 2.99. That 1.3-point fall for under a week's delay is
   steeper than any later band - between 6-15 and 31-45 days the score
   barely moves (1.74 -> 1.68). Customers punish MISSING THE PROMISE, not
   the length of the miss.

   Which points somewhere unexpected: a longer, more realistic delivery
   date would raise scores more than delivering faster would.

	The 45+ days late delivery getting a higher reivew than deliveries that come in 6 to 45days is investigated below
*/


-- ---------- SCORE DISTRIBUTION, NOT JUST THE MEAN ----------
-- A mean of 2.54 could be everyone mildly annoyed, or two opposed camps.
-- Only the distribution distinguishes them.
SELECT
	CASE
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 0 THEN 'On Time'
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 5 THEN '1-5 days late'
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 15 THEN '6-15 days late'
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 30 THEN '16-30 days late'
		WHEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date <= 45 THEN '31-45 days late'
		ELSE '45+ days late'
	END AS lateness_band,
	COUNT(DISTINCT CASE WHEN r.review_score = 1 THEN o.order_id END) AS score_1,
	COUNT(DISTINCT CASE WHEN r.review_score = 2 THEN o.order_id END) AS score_2,
	COUNT(DISTINCT CASE WHEN r.review_score = 3 THEN o.order_id END) AS score_3,
	COUNT(DISTINCT CASE WHEN r.review_score = 4 THEN o.order_id END) AS score_4,
	COUNT(DISTINCT CASE WHEN r.review_score = 5 THEN o.order_id END) AS score_5
FROM
	orders o JOIN reviews r
	ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY lateness_band;
/*
	To understand why the avg review score for the 45+ band was 2.54/5.0, we
	looked at the distribution. Of the 144 reviews in that band, 49.3% gave
	1 star and 36.8% gave 4 or 5. Two opposite reactions to the same delivery,
	not one group of mildly annoyed customers.

   Three possible  explanations, none provable with this data:
   1. customers furious enough to dispute and refund
      have moved on and are not filling in a survey two months later
      The angriest voices self-removed from the sample.
   2. orders that were 45+ days late and NEVER arrived are excluded entirely. The band
      only contains successful order that later came in.
   3. expectations reset to zero once a parcel is assumed lost, so arrival becomes a positive surprise to customers

   Aside from this, it was worth noting that almost 6000 orders which came on time scored the orders as 1/5, why? is it defected packages, wrong orders, this is to be invesitigated
   Delivery explains most of the bad reviews here, but not all of them.
*/
