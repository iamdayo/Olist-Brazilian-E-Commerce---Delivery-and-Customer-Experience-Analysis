-- ============================================================
-- 03 - CLEANING AND STANDARDIZATION
-- ============================================================

-- The English category names contain near-duplicates and typos.
-- Standardise the obvious ones first.

UPDATE category_translation
SET product_category_name_english = 'telephone'
WHERE product_category_name_english = 'telephony';

UPDATE category_translation
SET product_category_name_english = 'home_comfort'
WHERE product_category_name_english IN ('home_confort', 'home_comfort_2');

UPDATE category_translation
SET product_category_name_english = 'home_comfort_2'
WHERE product_category_name = 'casa_conforto_2';

-- 70+ granular categories is too fine for dashboard reporting, and several
-- are redundant (home_appliances / home_appliances_2, five variants of
-- construction_tools, etc). Roll them up into 13 broader groups in a NEW
-- column rather than overwriting the source values.

ALTER TABLE category_translation
ADD COLUMN category_group TEXT;

UPDATE category_translation
SET category_group =
	CASE
		WHEN product_category_name_english IN (
			'electronics', 'computers', 'computers_accessories',
			'tablets_printing_image', 'telephony', 'fixed_telephony',
			'audio', 'dvds_blu_ray', 'cds_dvds_musicals'
		) THEN 'Electronics & Computers'

		WHEN product_category_name_english IN (
			'furniture_living_room', 'furniture_bedroom', 'furniture_decor',
			'furniture_mattress_and_upholstery', 'home_appliances', 'home_appliances_2',
			'home_comfort', 'home_comfort_2', 'housewares', 'kitchen_dining_laundry_garden_furniture',
			'small_appliances', 'small_appliances_home_oven_and_coffee',
			'bed_bath_table', 'la_cuisine', 'air_conditioning', 'office_furniture'
		) THEN 'Home & Furniture'

		WHEN product_category_name_english IN (
			'fashion_underwear_beach', 'fashion_sport', 'fashion_shoes',
			'fashion_male_clothing', 'fashion_childrens_clothes',
			'fashion_bags_accessories', 'fashio_female_clothing', 'luggage_accessories'
		) THEN 'Fashion & Clothing'

		WHEN product_category_name_english IN (
			'books_technical', 'books_imported', 'books_general_interest',
			'music', 'musical_instruments', 'cine_photo'
		) THEN 'Books & Media'

		WHEN product_category_name_english IN (
			'sports_leisure', 'toys', 'consoles_games'
		) THEN 'Sports & Leisure'

		WHEN product_category_name_english IN (
			'health_beauty', 'perfumery', 'diapers_and_hygiene'
		) THEN 'Beauty & Health'

		WHEN product_category_name_english IN (
			'food', 'food_drink', 'drinks'
		) THEN 'Food & Drinks'

		WHEN product_category_name_english IN (
			'baby', 'party_supplies', 'christmas_supplies'
		) THEN 'Baby & Kids'

		WHEN product_category_name_english IN (
			'construction_tools_construction', 'construction_tools_lights',
			'construction_tools_safety', 'construction_tools_garden',
			'costruction_tools_tools', 'costruction_tools_garden',
			'home_construction', 'signaling_and_security', 'security_and_services'
		) THEN 'Construction & Tools'

		WHEN product_category_name_english IN (
			'garden_tools', 'pet_shop', 'agro_industry_and_commerce'
		) THEN 'Garden & Pets'

		WHEN product_category_name_english IN (
			'auto', 'industry_commerce_and_business'
		) THEN 'Auto & Industry'

		WHEN product_category_name_english IN (
			'art', 'arts_and_craftmanship', 'stationery', 'cool_stuff', 'flowers'
		) THEN 'Art & Hobbies'

		ELSE 'Other'
	END;

-- Two categories were renamed above, so re-map them.
UPDATE category_translation
SET category_group =
	CASE
		WHEN product_category_name_english = 'telephone' THEN 'Electronics & Computers'
		WHEN product_category_name_english = 'watches_gifts' THEN 'Gifts'
		ELSE category_group
	END;

-- Verify the groups.
SELECT
	category_group,
	COUNT(*) AS categories_in_group
FROM category_translation
GROUP BY category_group
ORDER BY category_group;


-- Push the group onto products so downstream queries need only one join.
ALTER TABLE products
ADD COLUMN category_name TEXT;

UPDATE products p
SET category_name = ct.category_group
FROM category_translation ct
WHERE ct.product_category_name = p.product_category_name;

-- Which Portuguese category names in products have no translation row?
SELECT
	p.product_category_name,
	COUNT(*) AS product_count
FROM products p
LEFT JOIN category_translation ct
	ON p.product_category_name = ct.product_category_name
WHERE ct.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;

-- How many products have a BLANK category name in the source?
SELECT COUNT(*) AS blank_category_products
FROM products
WHERE product_category_name = '' OR product_category_name IS NULL;
-- These products cannot be grouped and are excluded from category analysis
-- via "WHERE category_name IS NOT NULL".
