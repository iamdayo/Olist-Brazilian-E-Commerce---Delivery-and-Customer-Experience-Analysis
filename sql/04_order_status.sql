-- ============================================================
-- 04 - INVESTIGATING ORDER STATUS
-- ============================================================

SELECT
	order_status,
	COUNT(*) AS orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;
/*
   delivered   96,478   included - the bulk of the business
   shipped      1,107   included - payment confirmed, in transit
   canceled       625   EXCLUDED - no revenue realised
   unavailable    609   EXCLUDED - never fulfilled
   invoiced       314   included - payment processed
   processing     301   included - payment captured, not yet fulfilled
   created          5   EXCLUDED - slip generated, never paid
   approved         2   included

   The three excluded statuses never produced revenue, so including them
   would overstate both order counts and revenue.
*/

-- Why do so many orders have a NULL delivery date?
SELECT
	order_status,
	COUNT(*) AS orders
FROM orders
WHERE order_delivered_customer_date IS NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_status <> 'delivered'
GROUP BY order_status;
-- Most are still in transit ('shipped'); a few were canceled after, that is 1100+
-- reaching the carrier. Others never reached the carrier at all and cancelled orders.


-- ---------- WHERE DOES THE DATA ACTUALLY STOP? ----------
-- MAX(order_purchase_timestamp) says 17 October 2018, which is misleading.
SELECT
	EXTRACT(MONTH FROM order_purchase_timestamp) AS months,
	order_status,
	COUNT(*) AS orders
FROM orders
WHERE EXTRACT(YEAR FROM order_purchase_timestamp) = 2018
  AND EXTRACT(MONTH FROM order_purchase_timestamp) IN (9, 10)
GROUP BY months, order_status
ORDER BY months, orders DESC;
/*
   September: 15 canceled, 1 shipped
   October:   4 canceled

   Every order placed from September onward is canceled except one. That
   is the extraction boundary - the snapshot was taken in early September
   2018 and those orders never resolved. The data does not thin out after
   August, it stops.

   This is why every like-for-like year comparison below is restricted to
   January-August.
*/
