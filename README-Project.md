# Whose Fault Is the Late Delivery?
## Olist Brazilian E-Commerce Analysis
**Tools:** PostgreSQL + PostGIS | Power BI | **By:** Temidayo Olubayo

<img width="1279" height="722" alt="image" src="https://github.com/user-attachments/assets/872dc3c8-3d55-4c8b-881d-138490cf9656" />

93% of orders arrive on or before the promised date. But being one day late drops the average review score from 4.29 to 2.99, and of the 114 worst deliveries in the dataset, 111 were never the seller's fault.

This analysis works through 98,202 orders placed between 2016 and 2018 to answer a question that determines who should be held accountable:

> **Whose fault is the late delivery?**

## Business Context

Olist is a marketplace, not a retailer. Small Brazilian merchants list their products through Olist, and hand them to a carrier. Olist owns the platform and the review score. It does not own the truck.

So when a delivery goes wrong, the customer blames the platform and the seller carries the rating. The question is not how late deliveries are, but which part of the journey loses the time. A seller sitting on a parcel is fixable with dispatch targets. A carrier taking 99 days to cross the country is not.

This analysis splits the journey into stages, measures each one, and then tests the answer by holding the seller constant.

## Table of Contents

1. [Dataset Overview](#dataset-overview)
2. [Data Preparation](#data-preparation)
3. [Dashboard](#dashboard)
4. [Key Findings](#key-findings)
5. [Delivery Health Summary](#delivery-health-summary)
6. [Recommendations](#recommendations)
7. [Limitations](#limitations)
8. [Tools Used](#tools-used)

## Dataset Overview

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

Two grain issues shape almost every query in this project.

`order_items` holds one row per line item and `payments` holds one row per payment, so a three-item order paid in two parts produces multiple rows in each. Any query joining either table must use `COUNT(DISTINCT order_id)`, otherwise it counts items or payments and reports them as orders.

`customers` has one row per **order**, not per person. A single shopper who buys twice appears twice with two different `customer_id` values but one shared `customer_unique_id`. Counting `customer_id` counts orders wearing a customer's clothes; `customer_unique_id` counts people.

## Data Preparation

- **Reviews import** - duplicate `review_id` values in the source file; comment columns dropped.
- **Category rollup** - 70+ Portuguese category names cleaned, translated and grouped into 13.
- **Missing categories** - 1,424 orders with no category, excluded from category analysis.
- **Order-level view** - `order_analysis` created to give one row per order. Also the Power BI fact table.
  
### Conventions used
- REVENUE: `SUM(PRICE)`, freight tracked separately.
- `canceled`, `unavailable` and `created` order as excluded throughout.
- Delivery time: Whole delivery process, from time of purchase to customer doorstep

**Terms used in this analysis:**

- **Approval** - from the customer paying to the payment getting approved.
- **Dispatch** - from approved payment to the carrier.
- **Transit** - from the carrier collecting the parcel to it reaching the customer.
- **Delivery time** - the whole journey, from checkout to doorstep. Approval + dispatch + transit.
- **Late** - arrived after the estimated delivery date the customer was given.
- **Distance** - straight-line distance from the seller's location to the customer's.

## Dashboard

Four pages, built on `order_analysis` view table, each page answering a question rather than displaying a metric.

### Overview

Revenue, orders, customers and average order value, growth overtime

<img width="1281" height="722" alt="image" src="https://github.com/user-attachments/assets/ab3eac5c-69ef-4868-85ea-931131f71886" />

### Delivery

Each stage of the delivery, transit against distance, seller-city comparison matrix.

<img width="1282" height="720" alt="image" src="https://github.com/user-attachments/assets/228c06b1-662c-47d3-b341-32a920cc5f7c" />

### Reviews

Score by lateness, full score distribution, category and price comparisons.

<img width="1282" height="722" alt="image" src="https://github.com/user-attachments/assets/abb2089b-c9ee-4ce3-9459-4d3a303e8e6d" />

### Freight

Freight by state, freight against distance

<img width="1280" height="721" alt="image" src="https://github.com/user-attachments/assets/03c9082d-7810-4d23-87b3-5d5cb040f310" />

The `.pbix` file is in `/powerbi` and connects to a local PostgreSQL instance.

## Key Findings

### Growth is strong, but only if you compare the same months:

| Metric | Value |
|---|---|
| Revenue | R$13,494,400.74 |
| Freight | R$2,241,126.29 (16.6% of revenue) |
| Orders | 98,202 |
| Customers | 94,986 |
| Orders per customer | 1.03 |

For a fair comparison, January to August for each year was used to compare revenue per year, revenue went from **R$3,080,850 in 2017 to R$7,341,037 in 2018**, showing a growth of **138.3%**.

### 97% of customers never come back:

| Orders per customer | Customers |
|---|---|
| 1 | 92,099 |
| 2 | 2,651 |
| 3 | 188 |
| 4+ | 48 |

Almost every customer buys once and never returns. None of the revenue above is repeat business, and each order is majorly from somene new.

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

January to August is compared for both years so the comparison is fair.

Home & Furniture is the biggest category at R$3.35M and grew at half the rate of the small categories.

Construction & Tools category grew in orders from 106 to 1680, a **+1,484%** growth.

### Every city delivers on time, and 6,534 orders were still late:

On average, every city in the dataset receives its orders before the estimated date.

That is true, but an average can hide a lot. If half a city's orders arrive ten days early and the other half arrive five days late, the city still averages out as early, which the customers in the second half still got a late parcel.

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

### The time is in transit, not with the seller:

Each delivery broken into its three stages, in days:

| Stage | Average days | Median days | Longest |
|---|---|---|---|
| Purchase → approval | 0.51 | 0 | 60 |
| Approval → carrier | 2.71 | 2 | 126 |
| Carrier → customer | **9.28** | 7 | 205 |
| Total | 12.50 | 10 | 210 |

Approval is effectively instant for most orders. Dispatch is short and consistent. Nearly three quarters of the journey sits in the carrier stage., **BUT WHY?**

### Transit scales with distance. Dispatch does not:

> [!NOTE]
> Straight-line distance between seller and customer, calculated with PostGIS `ST_DistanceSphere`.

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

It's possible that far-away customers simply get worse sellers, and that's what makes their deliveries slow. But to rule that out, the table below takes the top five seller cities with the most orders and compares each one against itself.

If distance is the cause, each city should get slower as the distance grows. If the sellers are the cause, transit should not grow by distance.

| Seller city | <250km | 250-500 | 500-1000 | 1000-2000 | >2000km |
|---|---|---|---|---|---|
| belo horizonte | 4 | 8 | 8 | 13 | 22 |
| curitiba | 5 | 7 | 10 | 13 | 18 |
| ibitinga | 7 | 8 | 14 | 17 | 21 |
| santo andre | 4 | 9 | 10 | 15 | 17 |
| sao paulo | 4 | 9 | 10 | 15 | 16 |

<img width="621" height="256" alt="image" src="https://github.com/user-attachments/assets/e7ea4f03-99b0-4a92-bfe4-9df2893806eb" />

The numbers in the table are average transit days. 
Every one of the five cities gets slower the further it ships, which is roughly four times slower from the nearest customers to the farthest. Same sellers each time, so the slowdown comes from distance, not from the sellers.

Two other things stand out:

- **Ibitinga is slower at every distance.** It takes 7 days to reach nearby customers, while the other cities take 4 or 5. Ibitinga is known for furniture, and bulky items may take longer to move, but this data can not confirm that.
- **Most of São Paulo's orders go to nearby customers.** 9,671 of its orders travel under 250km, and only 1,724 go further than 2,000km. São Paulo's average looks good because most of its orders are short trips. The slow long-distance ones are there, but there are too few of them to move the average.

### Every delivery disaster is a transit failure:

The worst cases tell the same story. 114 orders arrived more than 50 days late. Here is where their time went:

| | Days |
|---|---|
| Median time with the seller (dispatch) | 2 |
| Median time with the carrier (transit) | 99 |
| Longest time with the carrier | 205 |

The sellers handed these parcels over faster than average. while the carrier held them for over three months. 111 of the 114 were delayed in transit, not at the seller.

Sellers take 2 days to dispatch whether the customer is nearby or across the country. Transit time grows with distance, even for the same seller. And on the worst deliveries, the seller was fast and the carrier was not. **The delay is with the carrier, so pushing sellers harder will not fix it.**

> **Olist's delivery problem is a carrier problem. Seller-facing interventions will not move the number.**

### Customers punish the broken promise, not the wait:

| Lateness | Reviewed orders | Avg score | 1★ | 2★ | 3★ | 4★ | 5★ |
|---|---|---|---|---|---|---|---|
| On time | 89,443 | 4.29 | 6.6% | 2.7% | 8.1% | 20.4% | 62.3% |
| 1-5 days | 2,722 | 2.99 | 33.6% | 7.5% | 13.6% | 17.0% | 28.3% |
| 6-15 days | 2,479 | 1.74 | 68.5% | 9.7% | 8.9% | 5.0% | 7.9% |
| 16-30 days | 851 | 1.60 | 71.8% | 10.6% | 8.8% | 3.8% | 5.1% |
| 31-45 days | 185 | 1.68 | 74.1% | 4.9% | 8.6% | 3.8% | 8.6% |
| 45+ days | 144 | 2.54 | 49.3% | 4.2% | 9.7% | 16.7% | 20.1% |

**On-time** orders score 4.29. **One to five days late scores 2.99.** That is a 1.3 point drop for being less than a week late. After that the score barely moves: 6-15 days and 31-45 days are almost the same, 1.74 against 1.68.

So how long the delay lasts barely matters. What matters is whether the delivery date was met.

**Giving customers a longer, more realistic delivery date would raise scores higher more than delivering faster would.** A date that is met beats an optimistic one that is missed by two days.

### Half the worst deliveries get 1 star, a third get 4 or 5:

<img width="552" height="279" alt="image" src="https://github.com/user-attachments/assets/637b4997-7a32-457e-9278-eef781dc4f04" />

The 45+ band breaks the pattern by scoring 2.54 where the other late bands above it sit near 1.6. A mean of 2.54 could mean everyone was mildly annoyed. 49.3% gave 1 star and 36.8% gave 4 or 5 — two opposite reactions to the same delivery.

Three candidate explanations, none of which this data can separate:

1. **Response selection** - the angriest customers disputed, refunded and moved on, and are not filling in a survey two months later
2. **Survivorship** - orders that were 45+ days late and never arrived have no delivery date, so they are excluded entirely. The band contains only the parcels that eventually turned up
3. **Relief** - once a parcel is assumed lost, arrival becomes a positive surprise

Reported as an open question rather than resolved, because resolving it would need the review text, which could not be imported.

One more number from that table deserves attention: **6.6% of on-time orders still score one star**, close to 6,000 orders. Delivery explains most of the dissatisfaction on this platform. It does not explain all of it.

### Slow boleto approvals are the customer's delay, not Olist's:

| Payment type | Orders | Slow approvals (>5 days) | Rate       |
| ------------ | ------ | ------------------------ | ---------- |
| debit_card   | 1,515  | 9                        | 0.594%     |
| boleto       | 19,523 | **97**                   | 0.497%     |
| voucher      | 3,745  | 4                        | 0.107%     |
| credit_card  | 75,615 | 40                       | **0.053%** |

Boleto is roughly **9 times more likely** than credit card to take more than five days to approve, and accounts for 97 of the 149 slow orders despite being a minority payment method. The skew runs opposite to volume, which is what makes it a finding rather than an artefact of boleto being common.

Boleto bancário is a printed bank slip. The customer checks out, receives a barcode, and then pays it at a bank, ATM, lottery agent or banking app **whenever they choose**. The merchant sees nothing until it clears. So `order_purchase_timestamp` records when the customer generated the slip and `order_approved_at` records when the money arrived. The gap between them is the customer's own delay.

This also explains the `created` status: slips generated and never paid.

Measured after approval, boleto is marginally **faster** than credit card:

| Payment type | Avg approval | Avg total delivery | Post-approval |
| ------------ | ------------ | ------------------ | ------------- |
| boleto       | 1.77         | 13.41              | 11.64         |
| voucher      | 0.33         | 12.46              | 12.13         |
| credit_card  | 0.19         | 12.29              | 12.10         |
| debit_card   | 0.39         | 10.73              | 10.34         |

Boleto's total is 1.1 days longer than credit card and its approval gap is 1.58 days longer, so the entire difference sits in approval.

The precise version matters here. Payment method affects **total elapsed time**, because the customer's clock starts at checkout and they genuinely waited longer. It does not affect **operational performance**. Anyone measuring purchase-to-doorstep by payment type would find boleto looks worse, and would be right about the experience but wrong about the cause.

### Freight is driven by weight and distance independently:

Freight is heavily skewed. Median to p75 is a gentle R$5 climb across a quarter of all items, then it accelerates sharply.

| Percentile | Freight     |
| ---------- | ----------- |
| p50        | R$16.26     |
| p75        | R$21.15     |
| p90        | R$34.04     |
| p95        | R$45.12     |
| p99        | **R$84.52** |
| max        | R$409.68    |

p95 was used as the high-freight threshold to keep a workable sample of 5,630 items, but the real break is at **p99**: p90 to p95 adds R$11, p95 to p99 adds R$39, and p99 to max adds R$325.

**Weight:**

| Band                | Items   | Avg weight | Avg freight |
| ------------------- | ------- | ---------- | ----------- |
| High freight (>p95) | 5,630   | 10,264g    | R$71.37     |
| Normal freight      | 107,020 | 1,664g     | R$17.29     |

6.2 times heavier, 4.1 times the freight.

**Distance, with weight effectively held constant:**

| Distance    | Items  | Avg freight | Avg weight |
| ----------- | ------ | ----------- | ---------- |
| Under 250km | 31,683 | R$13.16     | 2,109g     |
| 250-500km   | 32,245 | R$19.24     | 2,183g     |
| 500-750km   | 17,514 | R$20.59     | 1,982g     |
| 750-1000km  | 12,463 | R$21.88     | 1,990g     |
| 1000-1500km | 7,608  | R$26.21     | 2,107g     |
| 1500-2000km | 3,638  | R$35.49     | 2,189g     |
| Over 2000km | 6,402  | R$35.92     | 1,977g     |

Average weight never leaves the 1,977g to 2,189g range while **average freight rises 173%**. Whatever is driving that cost, it is not the parcels getting heavier.

**Location, which is the same story in a different unit:**

| State             | Orders | Avg freight | % high freight |
| ----------------- | ------ | ----------- | -------------- |
| AC (Acre)         | 81     | R$40.07     | **30.43%**     |
| RR (Roraima)      | 45     | R$43.32     | 29.41%         |
| PB (Paraíba)      | 531    | R$42.75     | 27.17%         |
| RO (Rondônia)     | 246    | R$41.13     | 26.71%         |
| PI (Piauí)        | 490    | R$39.16     | 25.05%         |
| MG (Minas Gerais) | 11,496 | R$20.62     | 4.10%          |
| SP (São Paulo)    | 41,125 | R$15.15     | **2.21%**      |

Acre against São Paulo: **13.8 times the high-freight rate and 2.6 times the average cost.** The top of the list is the remote north, the bottom is the southeast industrial core.

Neither driver explains freight alone. Heavy parcels cost more at any distance, and distant parcels cost more at any weight. It is the same geography that produces the delivery finding, expressed in money instead of days.

### Review scores are flat across everything except delivery:

Having found how hard lateness hits the score, the obvious check is whether anything else moves it. Almost nothing does.

**By category** - Books & Media 4.35 at the top, Home & Furniture 4.03 at the bottom. A 0.32 spread across thirteen wildly different product types.

**By payment type** - debit_card 4.19, boleto 4.12, credit_card 4.12, voucher 4.08. A 0.11 spread.

**By price** - the only one with a clean pattern, and it is small:

| Order value | Orders | Avg score |
| ----------- | ------ | --------- |
| Under R$50  | 29,070 | 4.18      |
| R$50-100    | 27,988 | 4.13      |
| R$100-200   | 25,555 | 4.10      |
| R$200-500   | 11,294 | 4.00      |
| R$500+      | 3,560  | 3.96      |

Every band drops, with no exceptions, which makes it a real effect rather than noise. Expectations scale with spend. But the total range is 0.22 points against delivery's **2.69**.

The share of 1-2 star reviews tells the same story. Across categories it runs from 10.17% for Food & Drinks to 15.67% for Home & Furniture - a 5.5 point band spanning books, furniture, electronics and perfume. Product type barely matters.

Overall, **13,306 of 96,083 reviews are 1 or 2 stars, or 13.85%**. Roughly one in seven.

A driver common to every order is doing the work here, not product quality. The two lowest-scoring categories, Home & Furniture and Electronics & Computers, are also the two bulkiest, which points back at freight, damage risk and delivery complexity rather than at the products themselves.

## Delivery Health Summary

| Area                  | Rating | Position                                                   |
| --------------------- | ------ | ---------------------------------------------------------- |
| On-time rate          | 🟢     | 93% of orders arrive on or before the promised date        |
| Seller dispatch       | 🟢     | Flat at ~3 days regardless of distance or seller city      |
| Approval speed        | 🟢     | Median 0 days; the boleto lag is customer-side             |
| Estimate accuracy     | 🟡     | Estimates are met, but missing one costs 1.3 review points |
| Carrier transit       | 🔴     | ~9 of every 12.5 days, and scales with distance            |
| Long-haul reliability | 🔴     | Spread widens from 5-11 days to 17-29 days past 2000km     |
| Repeat purchase       | 🔴     | 97% of customers order exactly once                        |

> **Final verdict:** operationally, Olist and its sellers are performing. The platform's delivery failures, its worst review scores and its highest freight costs all trace back to the same carrier network crossing the same distances, and none of it is within the sellers' control.

## Recommendations

**1. Pad delivery estimates for long-haul routes:**

The review data says customers punish a missed promise far more than a slow one. Transit past 2000km ranges from 17 to 29 days, so an estimate built on the median will be missed roughly half the time. Widening estimates on the routes where variance is highest would raise satisfaction without changing a single day of actual delivery time.

**2. Stop measuring sellers on delivery time:**

Dispatch is flat at 3 days regardless of seller city, and 111 of the 114 worst deliveries had faster-than-average dispatch. Any seller scorecard built on total delivery time is grading merchants on carrier performance. Measure dispatch, which they control, and nothing after it.

**3. Treat the carrier leg as the primary intervention point:**

Nine of every 12.5 days sit between carrier collection and the customer's door. This is where any improvement has to come from, whether that means regional carriers on long routes, a northern distribution point, or renegotiated terms.

**4. Investigate the 6,000 on-time one-star reviews:**

6.6% of orders that arrived on schedule still scored one star. Delivery does not explain those. Product condition, accuracy and packaging are the obvious candidates, and the review text would answer it directly.

**5. Build a repeat-purchase motion:**

97% of customers order once. Every real of revenue in this dataset was acquired fresh. Even shifting that rate by a few points changes the economics of the platform more than any operational fix listed above.

**6. Price freight on distance as well as weight:**

Freight rises 173% across distance bands while average weight stays flat at 2kg. If pricing is weight-led, long-haul orders are being underpriced relative to what they cost to move, and the northern states are where that gap is widest.

## Limitations

* **Straight-line distance, not road distance.** `ST_DistanceSphere` measures as the crow flies. Brazil's road network is far denser in the southeast than in the north, so the far bands understate real travel distance. This strengthens the distance finding rather than weakening it, but it means the absolute kilometre figures are floors, not actuals.

* **The distance analysis covers 536 of 4,037 cities.** The 20-order guard is doing necessary work - without it, single-order cities produce impossible values including negative transit times - but it excludes the long tail, and the long tail is disproportionately remote.

* **Average price rises with distance too.** Across the freight distance bands, average item price climbs from R$105 to R$157 while weight stays flat. Distance and item value are therefore not fully separated in the freight analysis. Weight is controlled for; value is not.

* **The dashboard measures freight at order grain, the SQL at item grain.** `order_analysis` carries freight as an order total, so the Power BI freight figures are coarser than the item-level numbers reported above. Directionally identical, not numerically identical.

* **"Carrier to customer" is a single undifferentiated gap.** It covers depot handling, road time, customs and failed delivery attempts with no way to distinguish them. The analysis shows *where* the time goes, not *why*.

* **680 orders have negative dispatch times** and 20 have negative transit times, recorded as the carrier receiving a parcel before it was approved. That is 0.7% of orders, small but not negligible. They are reported rather than silently dropped, and excluded from the timing averages they would distort.

* **Three orders have no line items** and 1,424 have no category, which accounts for small discrepancies in order counts between queries.

* **The data window is 23 months, not 24**, and one of the three years is a two-month stub. Only 2017 is complete, so seasonality can only be read from a single year, and in a business growing at 138% annually even that curve is mostly growth rather than season.

* **No review text.** The comment columns could not be imported, so the bimodal 45+ distribution and the 6,000 on-time one-star reviews are both left as open questions when the text would likely answer them.

## Tools Used

| Tool        | Purpose                                                               |
| ----------- | --------------------------------------------------------------------- |
| PostgreSQL  | Table creation, cleaning, transformation and analysis                 |
| PostGIS     | `ST_DistanceSphere` for seller-to-customer distance                   |
| SQL         | CTEs, window functions, `DISTINCT ON`, conditional aggregation, views |
| Power BI    | Dashboard, data model, date table                                     |
| DAX         | Banding columns, measures, filter context with `CALCULATE`            |
| DBeaver     | Query development and execution                                       |
| Power Query | Resolving the reviews CSV encoding failure, type handling on load     |

**Temidayo Olubayo**
Data Analytics | SQL | PostgreSQL | Power BI
