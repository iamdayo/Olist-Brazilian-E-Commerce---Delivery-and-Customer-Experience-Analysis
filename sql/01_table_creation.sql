/* ============================================================
   OLIST BRAZILIAN E-COMMERCE ANALYSIS
   01 - TABLE CREATION
   PostgreSQL

   CONVENTIONS USED THROUGHOUT THIS PROJECT
   ---------------------------------------
   - Currency: all monetary values are Brazilian Real (R$).
   - Revenue  = SUM(order_items.price). Freight is tracked separately.
   - Status filter: every analytical query excludes
     ('canceled', 'unavailable', 'created') - these don.t produced revenue.
   - Counting orders: COUNT(DISTINCT o.order_id) is used whenever
     order_items or payments is in the join, because those tables have
     one row per item / per payment and would otherwise inflate counts.
   - Low-volume guard: HAVING COUNT(DISTINCT o.order_id) >= 20 on every
     grouped average, so single-order cities cannot distort results.
   - Delivery time is measured from order_purchase_timestamp (what the
     customer actually experiences), not from approval.

   FILE ORDER
   ----------
   Files run in sequence. File 11 creates the order_analysis view, which
   file 12 depends on, so 11 must run before 12.
   ============================================================ */


-- TABLE CREATION
-- 1. customers
CREATE TABLE customers (
	customer_id VARCHAR(50) PRIMARY KEY,
	customer_unique_id VARCHAR(50),
	customer_zip_code_prefix VARCHAR(10),
	customer_city VARCHAR(100),
	customer_state VARCHAR(5)
);

-- 2. geolocation
-- No primary key: the source data has multiple lat/lng rows per zip prefix.
CREATE TABLE geolocation (
	geolocation_zip_code_prefix VARCHAR(10),
	geolocation_lat DECIMAL(18, 8),
	geolocation_lng DECIMAL(18, 8),
	geolocation_city VARCHAR(100),
	geolocation_state VARCHAR(5)
);

-- 3. order_items
-- One row per ITEM, not per order. Composite PK.
CREATE TABLE order_items (
	order_id VARCHAR(50),
	order_item_id INT,
	product_id VARCHAR(50),
	seller_id VARCHAR(50),
	shipping_limit_date TIMESTAMP,
	price DECIMAL(10, 2),
	freight_value DECIMAL(10, 2),
	PRIMARY KEY (order_id, order_item_id)
);

-- 4. payments
-- One row per PAYMENT, not per order (installments / split payments).
CREATE TABLE payments (
	order_id VARCHAR(50),
	payment_sequential INT,
	payment_type VARCHAR(20),
	payment_installments INT,
	payment_value DECIMAL(10, 2),
	PRIMARY KEY (order_id, payment_sequential)
);

-- 5. reviews
CREATE TABLE reviews (
	review_id TEXT,
	order_id TEXT,
	review_score INT,
	review_creation_date TIMESTAMP,
	review_answer_timestamp TIMESTAMP
);

-- 6. orders
CREATE TABLE orders (
	order_id VARCHAR(50) PRIMARY KEY,
	customer_id VARCHAR(50),
	order_status VARCHAR(20),
	order_purchase_timestamp TIMESTAMP,
	order_approved_at TIMESTAMP,
	order_delivered_carrier_date TIMESTAMP,
	order_delivered_customer_date TIMESTAMP,
	order_estimated_delivery_date TIMESTAMP
);

-- 7. products
CREATE TABLE products (
	product_id VARCHAR(50) PRIMARY KEY,
	product_category_name VARCHAR(100),
	product_name_lenght INT,
	product_description_lenght INT,
	product_photos_qty INT,
	product_weight_g INT,
	product_length_cm INT,
	product_height_cm INT,
	product_width_cm INT
);

-- 8. sellers
CREATE TABLE sellers (
	seller_id VARCHAR(50) PRIMARY KEY,
	seller_zip_code_prefix VARCHAR(10),
	seller_city VARCHAR(100),
	seller_state VARCHAR(5)
);

-- 9. category_translation
CREATE TABLE category_translation (
	product_category_name VARCHAR(100) PRIMARY KEY,
	product_category_name_english VARCHAR(100)
);
