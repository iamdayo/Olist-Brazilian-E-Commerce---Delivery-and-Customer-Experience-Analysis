# Olist-Brazilian-E-Commerce---Delivery-and-Customer-Experience-Analysis
# Whose Fault Is the Late Delivery?
## Olist Brazilian E-Commerce Analysis
**Tools:** PostgreSQL · PostGIS · Power BI | **By:** Temidayo Olubayo

<!-- IMAGE 1: dashboard cover page -->

93% of orders arrive on or before the promised date. But being one day late drops the average review score from 4.29 to 2.99, and of the 114 worst deliveries in the dataset, 111 were never the seller's fault.

## Business Context

Olist is a marketplace, not a retailer. Small Brazilian merchants list their products through Olist, and hand them to a carrier. Olist owns the platform and the review score. It does not own the truck.

So when a delivery goes wrong, the customer blames the platform and the seller carries the rating. The question is not how late deliveries are, but which part of the journey loses the time. A seller sitting on a parcel is fixable with dispatch targets. A carrier taking 99 days to cross the country is not.

This analysis splits the journey into stages, measures each one, and then tests the answer by holding the seller constant.

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

| Table | Grain | Contents |
|---|---|---|
| orders | One row per order | Status and four timestamps |
| order_items | One row per **item** | Product, seller, price, freight |
| payments | One row per **payment** | Type, installments, value |
| reviews | One row per review | Score 1-5 |
| customers | One row per **order** | Location, zip prefix |
| sellers | One row per seller | Location, zip prefix |
| products | One row per product | Category, weight, dimensions |
| geolocation | Multiple rows per zip | Latitude, longitude |
| category_translation | One row per category | PT to EN names |

Two grain traps run through the whole project. `order_items` and `payments` hold multiple rows per order, so anything joining them needs `COUNT(DISTINCT order_id)`. And `customers` has one row per order, not per person — `customer_unique_id` counts people, `customer_id` is only a join key.

## Data Preparation

**The reviews file would not import.** Duplicate `review_id` values broke the primary key, unquoted commas inside review comments misaligned the columns, and byte `0x8f` is invalid in both WIN1252 and UTF8. Fixed by dropping the two comment columns in Power Query and re-exporting. Nothing in this analysis uses the text, but it does mean the review-text questions below stay open.

**Categories were rolled up.** 70+ Portuguese names, several redundant (`home_appliances` and `home_appliances_2`, five variants of `construction_tools`) and some misspelled at source. Grouped into 13 in a new column so the originals stay intact. 1,424 orders have no category at all.

**The data ends in August 2018, not October.** `MAX(order_purchase_timestamp)` says 17 October, which is misleading — every order placed from September onward is canceled except one shipped order. That is the extraction boundary, not a slow month. Every year-on-year comparison here is restricted to January–August.

**An order-level view.** The later questions needed the same joins repeatedly, so the analysis builds `order_analysis`, one row per order. Each CTE collapses to one row per order *before* joining, otherwise `order_items` and `payments` multiply against each other. Highest-priced item decides the category and the seller; largest payment decides the type; most recent review wins. Verified at 98,202 rows and 98,202 distinct order IDs. This is also the Power BI fact table.

**Conventions:** revenue is `SUM(price)` with freight tracked separately; `canceled`, `unavailable` and `created` are excluded everywhere; `HAVING COUNT(DISTINCT order_id) >= 20` on every grouped average; delivery time runs from purchase, not approval.

## Dashboard

Built on the `order_analysis` view in Import mode, so `COUNTROWS` means orders with no `DISTINCTCOUNT` anywhere. Four DAX banding columns (lateness, delivery status, distance, price), each with a sort column, plus a generated date table.

**Overview** — revenue, orders, customers, growth. Scale before the argument starts.

<!-- IMAGE 2: Overview page -->

**Delivery** — where the 12.5 days go, and the seller-city matrix that holds the seller constant.

<!-- IMAGE 3: Delivery page -->

**Reviews** — what lateness costs, and the score distribution underneath the averages.

<!-- IMAGE 4: Reviews page -->

**Freight** — whether shipping is priced on the right variable.

<!-- IMAGE 5: Freight page -->

The `.pbix` is in `/powerbi` and points at a local PostgreSQL instance.

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

### 97% of customers never come back:

| Orders per customer | Customers |
|---|---|
| 1 | 92,099 |
| 2 | 2,651 |
| 3 | 188 |
| 4+ | 48 |

This started as a failed query — the original question was which customers had stopped buying, and the answer was nearly all of them. But a 97% single-purchase rate is the finding, not a limitation. Every order on this platform is acquired fresh.

### Growth is fastest in the smallest categories:

| Category | 2017 | 2018 | Growth |
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

Grouped by customer city, every city in the dataset beats its estimate on average. All of them.

That result is wrong, and the reason is the grain. Averaging inside a city cancels early deliveries against late ones — half arriving ten days early and half arriving five days late reports as on time.

Per order instead:

| Late by | Orders | Share |
|---|---|---|
| 1+ days | 6,534 | 6.77% |
| 5+ days | 3,764 | 3.90% |
| 20+ days | 795 | 0.82% |
| 50+ days | 114 | 0.12% |
| 100+ days | 39 | 0.04% |

93% still arrive on time. But the city-level version could not see the 6,534 that did not.

### Three quarters of the journey is the carrier:

| Stage | Mean | Median | Max |
|---|---|---|---|
| Purchase → approval | 0.51 | 0 | 60 |
| Approval → carrier | 2.71 | 2 | 126 |
| Carrier → customer | **9.28** | 7 | 205 |
| Total | 12.50 | 10 | 210 |

### Transit scales with distance. Dispatch does not:

Straight-line seller-to-customer distance, calculated with PostGIS `ST_DistanceSphere`.

| Distance | Median transit |
|---|---|
| Under 250km | 5 days |
| 250-500km | 8 days |
| 500-750km | 10 days |
| 750-1000km | 11 days |
| 1000-1500km | 14 days |
| 1500-2000km | 17 days |
| 2000-3000km | 17 days |

Transit more than triples while dispatch holds at about 3 days in every band.

The spread widens too — under 250km, city transit ranges from 5 to 11 days; past 2,000km it is 17 to 29. Long-haul is not just slower, it is less predictable, and unpredictability is what breaks an estimate.

### Holding the seller constant, it happens five times out of five:

The objection to the table above is that distant customers might just have worse sellers. So the same question inside the five highest-volume seller cities. Same warehouses, same staff, only distance changes.

| Seller city | <250km | 250-500 | 500-1000 | 1000-2000 | >2000km |
|---|---|---|---|---|---|
| belo horizonte | 4 | 8 | 8 | 13 | 22 |
| curitiba | 5 | 7 | 10 | 13 | 18 |
| ibitinga | 7 | 8 | 14 | 17 | 21 |
| santo andre | 4 | 9 | 10 | 15 | 17 |
| sao paulo | 4 | 9 | 10 | 15 | 16 |

<!-- IMAGE 6: seller-city matrix from the Delivery page -->

Median transit days. Five sellers, five climbs, no exceptions, each roughly quadrupling from nearest to farthest.

Two things the platform average hides. **Ibitinga is slower everywhere** — 7 days under 250km where others manage 4. It is a furniture town shipping bulky goods, which is a plausible explanation this data cannot prove. And **São Paulo's volume is short-haul**: 9,671 orders under 250km against 1,724 over 2,000km. That mix is why the platform average looks tolerable despite a bad long-distance tail.

### Every delivery disaster is a transit failure:

Of the 114 orders more than 50 days late:

- Median dispatch: **2 days**, faster than the platform average
- Median transit: **99 days**
- Worst case: dispatched in 3 days, then 205 days in transit
- **111 of 114 are transit failures**

Checked for corruption first — no negative intervals, date sequence holds in every row.

Dispatch is flat regardless of geography. Transit scales with distance, confirmed with the seller held constant. Every catastrophic delivery is a transit failure. **This is a carrier problem, and seller-facing interventions will not move it.**

### Customers punish the broken promise, not the wait:

| Lateness | Orders | Avg score | 1★ | 2★ | 3★ | 4★ | 5★ |
|---|---|---|---|---|---|---|---|
| On time | 89,443 | 4.29 | 6.6% | 2.7% | 8.1% | 20.4% | 62.3% |
| 1-5 days | 2,722 | 2.99 | 33.6% | 7.5% | 13.6% | 17.0% | 28.3% |
| 6-15 days | 2,479 | 1.74 | 68.5% | 9.7% | 8.9% | 5.0% | 7.9% |
| 16-30 days | 851 | 1.60 | 71.8% | 10.6% | 8.8% | 3.8% | 5.1% |
| 31-45 days | 185 | 1.68 | 74.1% | 4.9% | 8.6% | 3.8% | 8.6% |
| 45+ days | 144 | 2.54 | 49.3% | 4.2% | 9.7% | 16.7% | 20.1% |

On time scores 4.29. One to five days late scores 2.99 — a 1.3 point collapse for under a week. Then it flattens: 6-15 days and 31-45 days are almost identical, 1.74 against 1.68.

So the length of the delay barely matters. What matters is whether the promise held.

That points somewhere counterintuitive: **better delivery estimates would raise satisfaction more than faster delivery would.** A padded estimate that is met beats an optimistic one missed by two days.

### The worst deliveries are rated by two opposed camps:

<!-- IMAGE 7: score distribution from the Reviews page -->

The 45+ band scores 2.54 where the bands above it sit near 1.6. The mean hides what is happening — 49.3% give one star and 36.8% give four or five. Two groups, not one.

Three possible explanations, none separable with this data: the angriest customers disputed and refunded and are not answering surveys two months later; orders that never arrived have no delivery date and are excluded entirely, so the band only holds parcels that turned up; or expectations reset to zero once a parcel is assumed lost, making arrival a positive surprise.

Also worth flagging: **6.6% of on-time orders still score one star**, close to 6,000 of them. Delivery explains most of the dissatisfaction here. Not all of it.

### Boleto approvals are the customer's delay, not Olist's:

| Payment type | Orders | Slow (>5 days) | Rate |
|---|---|---|---|
| debit_card | 1,515 | 9 | 0.594% |
| boleto | 19,523 | 97 | 0.497% |
| voucher | 3,745 | 4 | 0.107% |
| credit_card | 75,615 | 40 | 0.053% |

Boleto is about 9x more likely than credit card to take over 5 days, and holds 97 of the 149 slow orders while being a minority method. The skew runs opposite to volume, which is what makes it real.

Boleto bancário is a printed bank slip. The customer checks out, gets a barcode, then pays it at a bank or ATM or app whenever they choose. The merchant sees nothing until it clears. So `order_purchase_timestamp` is when the slip was generated and `order_approved_at` is when the money arrived — the gap is the customer's own delay. It is also what the `created` status is: slips generated, never paid.

Measured after approval, boleto is marginally faster than credit card. The entire difference sits in approval. Payment type changes how long the customer waited, not how well Olist performed.

### Freight is driven by weight and distance separately:

| Percentile | Freight |
|---|---|
| p50 | R$16.26 |
| p75 | R$21.15 |
| p90 | R$34.04 |
| p95 | R$45.12 |
| p99 | R$84.52 |
| max | R$409.68 |

p95 was used as the high-freight threshold to keep a workable sample, but the real break is p99 — p90 to p95 adds R$11, p95 to p99 adds R$39, p99 to max adds R$325.

High-freight items average 10,264g against 1,664g for normal ones: 6.2x the weight, 4.1x the freight.

But weight is not the only driver. Across distance bands, average weight never leaves the 1,977g–2,189g range while freight climbs from R$13.16 to R$35.92 — a 173% rise with weight effectively held flat.

The same thing shows up by state:

| State | Orders | Avg freight | % high freight |
|---|---|---|---|
| AC (Acre) | 81 | R$40.07 | 30.43% |
| RR (Roraima) | 45 | R$43.32 | 29.41% |
| PB (Paraíba) | 531 | R$42.75 | 27.17% |
| MG (Minas Gerais) | 11,496 | R$20.62 | 4.10% |
| SP (São Paulo) | 41,125 | R$15.15 | 2.21% |

Acre against São Paulo is 13.8x the high-freight rate. Same geography as the delivery finding, measured in money instead of days.

### Nothing except delivery moves the review score:

**Category** — 4.35 at the top, 4.03 at the bottom. A 0.32 spread across thirteen very different product types.

**Payment type** — 4.19 to 4.08. A 0.11 spread.

**Price** — the only clean pattern, and it is small:

| Order value | Orders | Avg score |
|---|---|---|
| Under R$50 | 29,070 | 4.18 |
| R$50-100 | 27,988 | 4.13 |
| R$100-200 | 25,555 | 4.10 |
| R$200-500 | 11,294 | 4.00 |
| R$500+ | 3,560 | 3.96 |

Every band drops with no exceptions, so it is real — expectations scale with spend. But the range is 0.22 points against delivery's 2.69.

13,306 of 96,083 reviews are 1 or 2 stars, about one in seven. The low-review share runs 10.17% to 15.67% across categories — a tight band spanning books, furniture, electronics and perfume. Product type barely matters, which is what points at delivery.

## Delivery Health Summary

| Area | | Position |
|---|---|---|
| On-time rate | 🟢 | 93% arrive on or before the promised date |
| Seller dispatch | 🟢 | Flat at ~3 days regardless of distance or city |
| Approval speed | 🟢 | Median 0 days; the boleto lag is customer-side |
| Estimate accuracy | 🟡 | Estimates are met, but missing one costs 1.3 review points |
| Carrier transit | 🔴 | ~9 of every 12.5 days, and scales with distance |
| Long-haul reliability | 🔴 | Spread widens from 5-11 days to 17-29 past 2,000km |
| Repeat purchase | 🔴 | 97% of customers order exactly once |

Olist and its sellers are performing. The delivery failures, the worst review scores and the highest freight costs all trace back to the same carrier network crossing the same distances.

## Recommendations

**1. Pad delivery estimates on long-haul routes.** Transit past 2,000km ranges from 17 to 29 days, so an estimate built on the median gets missed about half the time. Widening estimates where variance is highest raises satisfaction without changing a single delivery day.

**2. Stop measuring sellers on delivery time.** Dispatch is flat at 3 days everywhere, and 111 of the 114 worst deliveries had faster-than-average dispatch. A scorecard built on total delivery time grades merchants on carrier performance. Measure dispatch and nothing after it.

**3. Make the carrier leg the intervention point.** Nine of every 12.5 days sit between collection and the door. Regional carriers on long routes, a northern distribution point, or renegotiated terms — the improvement has to come from here.

**4. Investigate the 6,000 on-time one-star reviews.** Delivery does not explain those. Product condition, accuracy and packaging are the candidates, and the review text would answer it.

**5. Build a repeat-purchase motion.** 97% of customers order once. Shifting that by a few points changes the platform's economics more than any operational fix above.

**6. Price freight on distance, not only weight.** Freight rises 173% across distance bands at flat 2kg weight. If pricing is weight-led, long-haul is underpriced, and the northern states are where the gap is widest.

## Limitations

- **Straight-line distance, not road distance.** Brazil's road network is far denser in the southeast, so the far bands understate real travel. This strengthens the finding but makes the kilometre figures floors rather than actuals.
- **536 of 4,037 cities.** The 20-order guard is necessary — without it single-order cities produce impossible values including negative transit — but it drops the long tail, which is disproportionately remote.
- **Distance and order value are not fully separated.** Average item price rises from R$105 to R$157 across the freight distance bands. Weight is controlled for; value is not.
- **The dashboard measures freight at order grain, the SQL at item grain.** Directionally identical, not numerically identical.
- **Carrier-to-customer is one undifferentiated gap** covering depot handling, road time and failed attempts. It shows where the time goes, not why.
- **680 orders have negative dispatch times** and 20 have negative transit. 0.7% of orders, reported rather than dropped, excluded from timing averages.
- **Three orders have no line items**, 1,424 have no category.
- **Only 2017 is a complete year**, so seasonality comes from one year — and in a business growing 138% annually, that curve is mostly growth.
- **No review text**, so the bimodal 45+ distribution and the on-time one-star reviews both stay open.

## Tools Used

SQL for this project is in `/sql`, numbered in execution order. The `order_analysis` view has to run before the queries that sit on top of it.

| Tool | Purpose |
|---|---|
| PostgreSQL | Table creation, cleaning, transformation, analysis |
| PostGIS | `ST_DistanceSphere` for seller-to-customer distance |
| SQL | CTEs, window functions, `DISTINCT ON`, conditional aggregation, views |
| Power BI | Dashboard, data model, date table |
| DAX | Banding columns, measures, `CALCULATE` |
| DBeaver | Query development |
| Power Query | Fixing the reviews CSV, type handling on load |

**Temidayo Olubayo**  
Data Analytics | SQL | PostgreSQL | Power BI
