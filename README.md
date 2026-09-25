# Whose Fault Is the Late Delivery?
## Olist Brazilian E-Commerce Analysis
**Tools:** PostgreSQL · PostGIS · Power BI | **By:** Temidayo Olubayo

<!-- IMAGE 1: dashboard cover page -->

93% of orders arrive on or before the promised date. But being one day late drops the average review score from 4.29 to 2.99, and of the 114 worst deliveries in the dataset, 111 were never the seller's fault.

## Business Context

Olist is a marketplace, not a retailer. Small Brazilian merchants list through Olist, pack their own orders, and hand them to a carrier. Olist owns the platform and the review score. It does not own the truck.

So when a delivery goes wrong, the customer blames the platform and the seller carries the rating. The question is not how late deliveries are, but which part of the journey loses the time. A seller sitting on a parcel is fixable with dispatch targets. A carrier taking 99 days to cross the country is not.

This analysis splits the journey into stages, measures each one, and then checks the answer by comparing the same sellers against themselves.

## Table of Contents

1. [Dataset](#dataset)
2. [Data Preparation](#data-preparation)
3. [Dashboard](#dashboard)
4. [Key Findings](#key-findings)
5. [Delivery Health Summary](#delivery-health-summary)
6. [Recommendations](#recommendations)
7. [Limitations](#limitations)
8. [Tools Used](#tools-used)

## Dataset

Nine CSV files covering September 2016 to August 2018, loaded into PostgreSQL.

| Table | One row is | Contents |
|---|---|---|
| orders | an order | Status and four timestamps |
| order_items | **an item inside an order** | Product, seller, price, freight |
| payments | **a payment on an order** | Type, installments, value |
| reviews | a review | Score 1-5 |
| customers | **an order, not a person** | Location, zip prefix |
| sellers | a seller | Location, zip prefix |
| products | a product | Category, weight, dimensions |
| geolocation | one of several coordinates per zip | Latitude, longitude |
| category_translation | a category | PT to EN names |

The three in bold need care. `order_items` and `payments` repeat the same order across several rows, so every query touching them counts orders with `COUNT(DISTINCT order_id)`. `customers` gets a new row per order, so `customer_unique_id` counts people and `customer_id` is only a join key.

## Data Preparation

- **Reviews import** — duplicate `review_id` values in the source file; comment columns dropped.
- **Category rollup** — 70+ Portuguese category names cleaned, translated and grouped into 13.
- **Missing categories** — 1,424 orders with no category, excluded from category analysis.
- **Order-level view** — `order_analysis` created to give one row per order. Also the Power BI fact table.

**Conventions:** revenue is `SUM(price)`, freight tracked separately. `canceled`, `unavailable` and `created` excluded throughout. Grouped averages need 20+ orders. Delivery time runs from purchase, not approval.

## Dashboard

Four pages, built on `order_analysis` in Import mode.

- **Model** — one flat table, a generated date table, four DAX banding columns for lateness, delivery status, distance and price.
- **Overview** — revenue, orders, customers, growth.
- **Delivery** — stage breakdown, transit against distance, seller-city comparison.
- **Reviews** — score by lateness, full score distribution, category and price comparisons.
- **Freight** — freight by state, freight against distance with weight held flat.
- **File** — `/powerbi`, connects to a local PostgreSQL instance.

<!-- IMAGE 2: Overview page -->

<!-- IMAGE 3: Delivery page -->

<!-- IMAGE 4: Reviews page -->

<!-- IMAGE 5: Freight page -->

## Key Findings

### Growth is strong, but only if you compare the same months:

| Metric | Value |
|---|---|
| Revenue | R$13,494,400.74 |
| Freight | R$2,241,126.29 (16.6% of revenue) |
| Orders | 98,202 |
| Customers | 94,986 |
| Orders per customer | 1.03 |

January–August 2017 against January–August 2018: **R$3.08M to R$7.34M, up 138.3%.**

Compare full-year 2017 against a 2018 that stops in August and you get 20.18% instead. That figure is not conservative, it is wrong by a factor of seven.

The dataset stops in August. `MAX(order_purchase_timestamp)` says 17 October, but every order placed from September onward is canceled except one — that is where the export was taken, not where the business slowed down.

### 97% of customers never come back:

| Orders per customer | Customers |
|---|---|
| 1 | 92,099 |
| 2 | 2,651 |
| 3 | 188 |
| 4+ | 48 |

Almost every customer buys once and never returns. None of the revenue above is repeat business — every order has to be won from someone new.

### Growth is fastest in the smallest categories:

| Category | Orders Jan–Aug 2017 | Orders Jan–Aug 2018 | Growth |
|---|---|---|---|
| Construction & Tools | 106 | 1,680 | +1,484.91% |
| Food & Drinks | 111 | 680 | +512.61% |
| Gifts | 801 | 3,485 | +335.08% |
| Auto & Industry | 711 | 2,645 | +272.01% |
| Books & Media | 278 | 999 | +259.35% |
| Baby & Kids | 583 | 1,763 | +202.40% |
| Beauty & Health | 2,527 | 6,868 | +171.78% |
| Electronics & Computers | 3,086 | 8,268 | +167.92% |
| Home & Furniture | 6,719 | 13,817 | +105.64% |
| Garden & Pets | 1,328 | 2,676 | +101.51% |
| Sports & Leisure | 3,095 | 5,810 | +87.72% |
| Art & Hobbies | 1,626 | 3,004 | +84.75% |
| Fashion & Clothing | 1,125 | 1,439 | +27.91% |
| Other | 132 | 95 | -28.03% |

The ranking is roughly the reverse of the size ranking. Home & Furniture is the biggest category at R$3.35M and grew at half the rate of the small ones. That is a different problem from a small base growing fast, and worth separating.

Construction & Tools grew off a base of 106 orders, so 1,484% is a smaller event than it sounds — it added 1,574 orders.

### Every city delivers on time, and 6,534 orders were still late:

On average, every city in the dataset receives its orders before the estimated date.

That is true, but an average can hide a lot. If half a city's orders arrive ten days early and the other half arrive five days late, the city still averages out as early — and the customers in the second half still got a late parcel.

The table below counts how many individual orders arrived after their estimated delivery date:

| Days late | Orders | % of delivered orders |
|---|---|---|
| 1-5 days | 2,770 | 2.87% |
| 6-20 days | 2,969 | 3.08% |
| 21-50 days | 681 | 0.71% |
| 51-100 days | 75 | 0.08% |
| 100+ days | 39 | 0.04% |
| **Total late** | **6,534** | **6.77%** |

93% of orders arrive on or before their estimated date. The other 6,534 arrive late, and they only show up when orders are checked one at a time rather than averaged by city.

### Three quarters of the journey is the carrier:

Each delivery broken into its three stages, in days:

| Stage | Average days | Median days | Longest |
|---|---|---|---|
| Purchase → approval | 0.51 | 0 | 60 |
| Approval → carrier | 2.71 | 2 | 126 |
| Carrier → customer | **9.28** | 7 | 205 |
| Total | 12.50 | 10 | 210 |

### Transit scales with distance. Dispatch does not:

Straight-line distance between seller and customer, calculated with PostGIS `ST_DistanceSphere`.

| Distance | Orders | Median dispatch days | Median transit days |
|---|---|---|---|
| Under 250km | 27,069 | 2 | 3 |
| 250-500km | 27,393 | 2 | 7 |
| 500-750km | 14,879 | 2 | 8 |
| 750-1000km | 10,699 | 2 | 9 |
| 1000-1500km | 6,539 | 2 | 12 |
| 1500-2000km | 3,145 | 2 | 14 |
| Over 2000km | 5,564 | 2 | 15 |

Transit goes from 3 days to 15. Dispatch stays at 2 in every band.

### The same sellers get slower the further they ship:

It's possible that far-away customers simply get worse sellers, and that's what makes their deliveries slow. To rule that out, the table below takes the five seller cities with the most orders and compares each one against itself — the same sellers shipping to nearby customers and to distant ones.

If distance is the cause, each city should get slower as the distance grows. If the sellers are the cause, it shouldn't.

| Seller city | <250km | 250-500 | 500-1000 | 1000-2000 | >2000km |
|---|---|---|---|---|---|
| belo horizonte | 4 | 8 | 8 | 13 | 22 |
| curitiba | 5 | 7 | 10 | 13 | 18 |
| ibitinga | 7 | 8 | 14 | 17 | 21 |
| santo andre | 4 | 9 | 10 | 15 | 17 |
| sao paulo | 4 | 9 | 10 | 15 | 16 |

<!-- IMAGE 6: seller-city comparison from the Delivery page -->

The numbers are average transit days. Every one of the five cities gets slower the further it ships — roughly four times slower from the nearest customers to the farthest. Same sellers each time, so the slowdown comes from distance, not from the sellers.

Two other things stand out:

- **Ibitinga is slower at every distance.** It takes 7 days to reach nearby customers, where the other cities take 4 or 5. Ibitinga is known for furniture, and bulky items may take longer to move, but this data can't confirm that.
- **Most of São Paulo's orders go to nearby customers.** 9,671 of its orders travel under 250km, and only 1,724 go further than 2,000km. Because so many orders are short trips, the overall delivery average looks better than the long-distance deliveries actually are.

### Every delivery disaster is a transit failure:

The worst cases tell the same story. 114 orders arrived more than 50 days late. Here is where their time went:

| | Days |
|---|---|
| Median time with the seller (dispatch) | 2 |
| Median time with the carrier (transit) | 99 |
| Longest time with the carrier | 205 |

The sellers handed these parcels over faster than average. The carrier then held them for over three months. 111 of the 114 were delayed in transit, not at the seller.

Three separate checks now point the same way. Dispatch does not change with distance. Transit does, even when the seller stays the same. And the worst delays are all carrier delays. **This is a carrier problem, and pushing sellers harder will not fix it.**

### Customers punish the broken promise, not the wait:

| Lateness | Reviewed orders | Avg score | 1★ | 2★ | 3★ | 4★ | 5★ |
|---|---|---|---|---|---|---|---|
| On time | 89,443 | 4.29 | 6.6% | 2.7% | 8.1% | 20.4% | 62.3% |
| 1-5 days | 2,722 | 2.99 | 33.6% | 7.5% | 13.6% | 17.0% | 28.3% |
| 6-15 days | 2,479 | 1.74 | 68.5% | 9.7% | 8.9% | 5.0% | 7.9% |
| 16-30 days | 851 | 1.60 | 71.8% | 10.6% | 8.8% | 3.8% | 5.1% |
| 31-45 days | 185 | 1.68 | 74.1% | 4.9% | 8.6% | 3.8% | 8.6% |
| 45+ days | 144 | 2.54 | 49.3% | 4.2% | 9.7% | 16.7% | 20.1% |

On time scores 4.29. One to five days late scores 2.99 — a 1.3 point drop for being less than a week late. After that the score barely moves: 6-15 days and 31-45 days are almost the same, 1.74 against 1.68.

So how long the delay lasts barely matters. What matters is whether the delivery date was met.

That points somewhere unexpected: **giving customers a longer, more realistic delivery date would raise scores more than delivering faster would.** A date that is met beats an optimistic one that is missed by two days.

### The worst deliveries are rated by two opposed camps:

<!-- IMAGE 7: score distribution from the Reviews page -->

The 45+ band scores 2.54, higher than the bands above it, which sit near 1.6. The average hides what is happening — 49.3% give one star and 36.8% give four or five. Two groups, not one.

Three possible explanations, none of them provable with this data:

- The angriest customers asked for a refund and moved on. They are not filling in a survey two months later.
- Orders that never arrived have no delivery date, so they are not in this band at all. It only holds parcels that eventually turned up.
- After waiting that long, customers assume the parcel is lost. When it finally arrives, it feels like good news.

One more thing in that table: **6.6% of on-time orders still score one star**, close to 6,000 of them. Delivery explains most of the bad reviews here. It does not explain all of them.

### Boleto approvals are the customer's delay, not Olist's:

| Payment type | Orders | Slow (>5 days) | Rate |
|---|---|---|---|
| debit_card | 1,515 | 9 | 0.594% |
| boleto | 19,523 | 97 | 0.497% |
| voucher | 3,745 | 4 | 0.107% |
| credit_card | 75,615 | 40 | 0.053% |

Boleto is about 9x more likely than credit card to take over 5 days to approve, and holds 97 of the 149 slow orders even though it is a minority payment method.

Boleto bancário is a printed bank slip. The customer checks out, gets a barcode, then pays it at a bank, ATM or app whenever they choose. The merchant sees nothing until the payment clears. So the purchase timestamp records when the slip was printed, and the approval timestamp records when the money arrived. The gap between them is the customer's own delay, not Olist's.

It also explains the `created` status: slips that were printed and never paid.

Once payment clears, boleto orders are delivered slightly faster than credit card ones. The whole difference sits in the approval stage. Payment type changes how long the customer waited, not how well Olist performed.

### Freight rises with weight and with distance:

| Percentile | Freight |
|---|---|
| p50 | R$16.26 |
| p75 | R$21.15 |
| p90 | R$34.04 |
| p95 | R$45.12 |
| p99 | R$84.52 |
| max | R$409.68 |

Freight is cheap for most items and then climbs sharply at the top end. p90 to p95 adds R$11, p95 to p99 adds R$39, and p99 to the maximum adds R$325.

Heavier items cost more to ship, as expected. Items above the 95th percentile of freight average 10,264g against 1,664g for the rest — 6.2x the weight and 4.1x the freight.

But weight is not the only thing driving it. Across distance bands, average weight stays between 1,977g and 2,189g while freight climbs from R$13.16 to R$35.92. That is a 173% rise on parcels of roughly the same weight.

The same pattern shows up by state:

| State | Orders | Avg freight | % high freight |
|---|---|---|---|
| AC (Acre) | 81 | R$40.07 | 30.43% |
| RR (Roraima) | 45 | R$43.32 | 29.41% |
| PB (Paraíba) | 531 | R$42.75 | 27.17% |
| MG (Minas Gerais) | 11,496 | R$20.62 | 4.10% |
| SP (São Paulo) | 41,125 | R$15.15 | 2.21% |

Acre has 13.8x São Paulo's rate of high-freight orders. The expensive states are in the remote north, the cheap ones in the industrial southeast — the same geography behind the delivery finding, measured in money instead of days.

### Nothing except delivery moves the review score:

**Category** — 4.35 at the top, 4.03 at the bottom. A 0.32 spread across thirteen very different product types.

**Payment type** — 4.19 to 4.08. A 0.11 spread.

**Price** — the only clear pattern, and it is small:

| Order value | Orders | Avg score |
|---|---|---|
| Under R$50 | 29,070 | 4.18 |
| R$50-100 | 27,988 | 4.13 |
| R$100-200 | 25,555 | 4.10 |
| R$200-500 | 11,294 | 4.00 |
| R$500+ | 3,560 | 3.96 |

Every band drops with no exceptions, so it is a real effect — customers expect more when they spend more. But the whole range is 0.22 points, against delivery's 2.69.

13,306 of 96,083 reviews are 1 or 2 stars, about one in seven. That share runs from 10.17% to 15.67% across categories — a narrow band covering books, furniture, electronics and perfume. Product type barely matters, which is what points back at delivery.

## Delivery Health Summary

| Area | | Position |
|---|---|---|
| On-time rate | 🟢 | 93% arrive on or before the promised date |
| Seller dispatch | 🟢 | 2 days at every distance |
| Approval speed | 🟢 | Median 0 days; the boleto lag is customer-side |
| Delivery dates | 🟡 | Usually met, but missing one costs 1.3 review points |
| Carrier transit | 🔴 | 9 of every 12.5 days, and grows with distance |
| Long-haul routes | 🔴 | Median transit past 2,000km is 15 days, against 3 nearby |
| Repeat purchase | 🔴 | 97% of customers order exactly once |

Olist and its sellers are performing. The delivery failures, the worst review scores and the highest freight costs all trace back to the same carrier network crossing the same distances.

## Recommendations

**1. Give longer delivery estimates on long-haul routes.** Median transit past 2,000km is 15 days against 3 days under 250km. Adding a few buffer days to estimates on the longest routes means fewer orders arrive late, without changing a single delivery day.

**2. Stop measuring sellers on delivery time.** Dispatch is 2 days at every distance, and 111 of the 114 worst deliveries were dispatched faster than average. A scorecard built on total delivery time grades merchants on carrier performance. Measure dispatch and nothing after it.

**3. Make the carrier leg the intervention point.** Nine of every 12.5 days sit between carrier collection and the customer's door. Regional carriers on long routes, a northern distribution point, or renegotiated terms — any improvement has to come from here.

**4. Investigate the 6,000 on-time one-star reviews.** Delivery does not explain those. Product condition, accuracy and packaging are the likely causes, and the review text would answer it.

**5. Build a repeat-purchase motion.** 97% of customers order once. Moving that by a few points changes the platform's economics more than any operational fix above.

**6. Price freight on distance, not only weight.** Freight rises 173% across distance bands on parcels averaging 2kg either way. If pricing is weight-led, long-haul orders are underpriced, and the northern states are where the gap is widest.

## Limitations

- Straight-line distance, not road distance. Brazil's road network is denser in the southeast, so the far bands understate real travel.
- The distance analysis covers 536 of 4,037 cities. Using the minimum of 20 order for each city, the long tail is dropped.
- Distance and order value are not fully separated. Average item price rises from R$105 to R$157 across the freight distance bands.
- Carrier-to-customer is one undivided gap covering depot handling, road time and failed delivery attempts.
- 680 orders have negative dispatch times and 20 have negative transit times. 0.7% of orders, excluded from timing averages.
- Three orders have no line items, 1,424 have no category.
- Only 2017 is a complete year, so seasonality comes from one year of a business growing 138% annually.
- No review text, so the 45+ score split and the on-time one-star reviews both stay open.

## Tools Used

SQL is in `/sql`, numbered in execution order. `order_analysis` has to run before the queries built on it.

| Tool | Purpose |
|---|---|
| PostgreSQL | Table creation, cleaning, transformation, analysis |
| PostGIS | `ST_DistanceSphere` for seller-to-customer distance |
| SQL | CTEs, window functions, `DISTINCT ON`, conditional aggregation, views |
| Power BI | Dashboard, data model, date table |
| DAX | Banding columns, measures, `CALCULATE` |
| DBeaver | Query development |
| Power Query | Reviews CSV fix, type handling on load |

**Temidayo Olubayo**  
Data Analytics | SQL | PostgreSQL | Power BI
