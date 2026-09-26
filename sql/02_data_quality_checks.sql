-- ============================================================
-- 02 - DATA QUALITY CHECKS
-- ============================================================

-- customers: is customer_id unique?
SELECT
	customer_id,
	COUNT(*) AS id_count
FROM customers
GROUP BY customer_id
ORDER BY id_count DESC
LIMIT 10;
-- No duplicates. Note: one PERSON (customer_unique_id) can hold several
-- customer_id values - one per order. customer_unique_id is therefore the
-- correct column for counting people; customer_id is only a join key.

-- orders: is order_id unique?
SELECT
	order_id,
	COUNT(*) AS id_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
-- No duplicates.

-- category_translation: is product_category_name unique?
SELECT
	product_category_name,
	COUNT(*) AS id_count
FROM category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;
-- No duplicates.

-- order_items: is (order_id, order_item_id) unique?
SELECT
	order_id,
	order_item_id,
	COUNT(*) AS id_count
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;
-- No duplicates on the composite key.
-- order_item_id is a LINE NUMBER within an order (1, 2, 3...), not a
-- product identifier. Repeated order_id values are expected.

-- payments: is (order_id, payment_sequential) unique?
SELECT
	order_id,
	payment_sequential,
	COUNT(*) AS id_count
FROM payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;
-- No duplicates.

-- products: is product_id unique?
SELECT
	product_id,
	COUNT(*) AS id_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;
-- No duplicates.

-- sellers: is seller_id unique?
SELECT
	seller_id,
	COUNT(*) AS id_count
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;
-- No duplicates.

-- reviews: duplicate review_id values DO exist in the source data.
SELECT
	COUNT(*) AS total_rows,
	COUNT(DISTINCT review_id) AS distinct_review_ids,
	COUNT(DISTINCT order_id) AS distinct_order_ids
FROM reviews;
-- Because of this, any query averaging review_score must be checked for
-- an order carrying more than one review row.
