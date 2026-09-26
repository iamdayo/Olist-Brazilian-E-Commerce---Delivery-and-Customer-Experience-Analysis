-- ============================================================
-- 09 - APPROVAL TIME AND PAYMENT
-- ============================================================

-- ---------- HOW LONG DOES APPROVAL TAKE? ----------
SELECT
	COUNT(*) AS total_orders,
	ROUND(AVG(order_approved_at::date - order_purchase_timestamp::date), 2) AS avg_approval_days,
	COUNT(CASE WHEN order_approved_at::date - order_purchase_timestamp::date > 5 THEN 1 END) AS over_5_days,
	MAX(order_approved_at::date - order_purchase_timestamp::date) AS max_approval_days
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_status NOT IN ('unavailable', 'canceled', 'created');
-- 144 delivered orders take more than 5 days to approve.
-- approval is effectively instant for everything else - median is 0 days.


-- ---------- DOES SLOW APPROVAL PREDICT SLOW DELIVERY? ----------
SELECT
	order_id,
	order_approved_at::date - order_purchase_timestamp::date AS approval_days,
	order_delivered_customer_date::date - order_approved_at::date AS days_after_approval,
	order_delivered_customer_date::date - order_purchase_timestamp::date AS delivery_days
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_status NOT IN ('canceled', 'unavailable', 'created')
  AND order_approved_at::date - order_purchase_timestamp::date > 5
ORDER BY approval_days DESC;
/*
   No. Once payment clears, these orders behave like any other - median
   9 days to delivery, matching the ~9-day post-approval figure overall.
   A slow approval does not mean a slow delivery.
*/


-- ---------- IS SLOW APPROVAL A PAYMENT-METHOD EFFECT? ----------
SELECT
	p.payment_type,
	COUNT(DISTINCT o.order_id) AS total_orders,
	COUNT(DISTINCT CASE
		WHEN o.order_approved_at::date - o.order_purchase_timestamp::date > 5
		THEN o.order_id
	END) AS slow_orders,
	ROUND(COUNT(DISTINCT
			CASE
				WHEN o.order_approved_at::date - o.order_purchase_timestamp::date > 5
				THEN o.order_id
			END) * 100.0 / COUNT(DISTINCT o.order_id) , 3) AS pct_slow,
	MAX(order_approved_at::date - order_purchase_timestamp::date) AS max_approval_days
FROM
	orders o JOIN payments p
	ON o.order_id = p.order_id
WHERE o.order_approved_at IS NOT NULL
  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY p.payment_type
ORDER BY pct_slow DESC;
/*
   boleto accounts for 97 of the 149 slow-approval orders, which is 65%,
   even though its a minority payment method. credit card is ~75% of all
   orders but only 40 of the slow ones, so the skew runs opposite to volume.

   as a rate: boleto goes over 5 days on 0.497% of its orders vs credit
   card's 0.053%, so roughly 9x more likely to stall.

   boleto is a printed bank slip, the customer checks out, gets a barcode,
   then pays it at a bank or atm or app whenever they want. the merchant
   only sees it once it clears. so order_purchase_timestamp is when the
   customer generated the slip and order_approved_at is when the money
   actually arrived, the gap is the customer's own delay and not olist
   processing anything. this is also what the 'created' status is, slips
   generated and never paid.

   so payment type affects how long the customer waited end to end, but
   not olist's actual performance. anyone measuring purchase to doorstep
   by payment type would find boleto looks worse and theyd be right about
   the experience but wrong about the cause.

   NOTE on the counts: this query joins payments, so an order split across
   two payment types lands in both groups. the distinct total is 149 orders,
   and the 144 figure above uses a delivered-only filter. the RATE is the
   number to lead with - it holds either way.
*/


-- ---------- DOES PAYMENT TYPE AFFECT DELIVERY? ----------
SELECT
	p.payment_type,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(AVG(o.order_delivered_customer_date::date - o.order_approved_at::date), 2) AS avg_days_after_approval,
	ROUND(AVG(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date), 2) AS avg_days_from_purchase
FROM orders o
JOIN payments p
	ON o.order_id = p.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_approved_at IS NOT NULL
  AND o.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY p.payment_type
HAVING COUNT(DISTINCT o.order_id) >= 20
ORDER BY avg_days_after_approval DESC;
-- comparing the approval time and the total delivery time accross all the payment types, one of the most significant change is in boleto, where the avg delivery days is 2days
-- extra from the avg approval days, this isnt shocking because boleto is a payment type that involves the customer going to the bank to complete/process their payment, and some customers could delay which still
-- recorded as part of their delivery time
-- measured AFTER approval, boleto is actually marginally faster than credit card.
-- the whole difference sits in the approval stage.
