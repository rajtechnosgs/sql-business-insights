# INTERPRETATIONS.md

Interpretations for the 10 SQL Foundation queries on the `ecom` schema.

---

## Q1 — Daily Business Summary + DoD / Same-Weekday WoW

**What the query does (1 sentence):** Aggregates daily revenue, order counts,
AOV, paid/cancelled rates and refunds, then compares each day to yesterday
and to the same weekday last week.

**Pattern choice (1–2 sentences):** Used two separate CTEs (`daily_orders`,
`daily_refunds`) aggregated independently before joining, to avoid row
explosion from a one-to-many orders-refunds relationship. Used `LAG` with
offsets of 1 and 7 to get day-over-day and same-weekday comparisons in a
single pass.

**Business interpretation (2–3 sentences):** Across the 91-day window, the
business processed 40,000 orders worth ₹29.9 Cr in revenue, with a stable
average paid-order rate of 94.4% — payment failure isn't a meaningful
day-to-day revenue leak. One day stands out sharply: May 13, 2026 saw the
cancelled-order rate spike to 52.7%, roughly 9x the typical ~5.6% rate,
while every other day in the window stays close to normal — this looks
like a one-off operational incident (a promo gone wrong, a system issue,
or a fulfillment problem) rather than noise.

**What I'd ask next:** What happened operationally on May 13? A single-day
spike this extreme, isolated from the rest of the trend, is worth a direct
answer before assuming it's "normal variance."

---

## Q2 — Monthly Signup Cohort Retention

**What the query does (1 sentence):** Groups customers by signup month and
measures what share of each cohort placed an order 1, 2, and 3 months later.

**Pattern choice (1–2 sentences):** Built a `customer_signup` and
`customer_orders` CTE, joined on `customer_id` to compute a month-gap per
order, then aggregated into cohort size and retention counts. Used a
`CASE WHEN` guarded by the dataset's latest order month to null out
"censored" cells — months that haven't happened yet for recent cohorts —
instead of showing them as a misleading 0%.

**Business interpretation (2–3 sentences):** Month-1 retention is falling
sharply cohort over cohort: the March cohort (1,664 customers) retained
50.2% at m1, April (3,382 customers) dropped to 42.6%, and May (3,461
customers) fell further to just 18.2%. Only the March cohort has a fully
observed m3 rate (19.2%) — April's and May's later-month cells are
correctly left blank since that much time hasn't passed yet in the data,
not because retention is zero. Taken together, this is a real trend, not
noise: the business is retaining new signups roughly a third as well in
May as it was in March, even as it signs up more people each month.

**What I'd ask next:** What changed around April/May — a new acquisition
channel, a pricing change, or a product change — that coincides with the
drop from 50% to 18% month-1 retention? Growing signups while retention
collapses is a leaky-bucket problem, not a growth win.

---

## Q3 — Funnel Conversion by Acquisition Channel

**What the query does (1 sentence):** Measures how sessions from each
acquisition channel move through product-view → add-to-cart →
begin-checkout → purchase, restricted to sessions after the 2026-04-19
instrumentation launch.

**Pattern choice (1–2 sentences):** Used `COUNT(DISTINCT session_id)
FILTER (WHERE event_type = ...)` in a single pass over `session_events`
rather than four separate joins, which avoids row-explosion since a
session can log the same event type multiple times. Channel came from the
`session_channels` first-touch view, with unmatched sessions bucketed as
`'direct'` rather than dropped.

**Business interpretation (2–3 sentences):** The channel-to-channel
differences are surprisingly small — every channel converts sessions to
purchases at roughly the same rate (27.9%–28.6%), so this isn't a
traffic-quality problem for any one channel. What's consistent across
every channel is where the funnel actually breaks: only about 40% of
sessions that view a product ever add one to cart, meaning roughly 60% of
interested browsers are lost at that single step, while checkout-to-
purchase holds up well at 85–87%. Organic (19,539 sessions) and paid
(17,169 sessions) bring by far the most volume, so even a small lift at
the view-to-cart stage would move more absolute revenue than optimizing
any single channel's mix.

**What I'd ask next:** Since the view-to-cart drop is uniform across
channels, is it a product-page issue (pricing display, image quality,
missing size/stock info) rather than a channel-quality issue? A shared
funnel problem points to a shared fix.

---

## Q4 — Top Products by Net Revenue (After Refunds)

**⚠️ Not finalized — data quality issue found.** The result you sent shows
`refunds_amount = 0` for all 4,000 products, which conflicts with the
known correct refund total (~₹11.97L) confirmed earlier. This means the
`return_item_prices` join (linking `return_items` → `return_requests` →
`order_items`) isn't matching any rows — likely a column name or join
condition mismatch. **This section needs to be rewritten once the query is
re-run with correct refund numbers** — writing an interpretation now would
just document a wrong result as if it were real.

**What the query does (1 sentence):** Ranks products by revenue net of
refunds, by aggregating gross revenue, returns, and refunds in three
separate CTEs before combining them.

**Pattern choice (1–2 sentences):** Kept revenue, returns, and refunds as
three independent CTEs (`product_revenue`, `product_returns`,
`product_refunds`) rather than one multi-join query, since joining all
three raw tables directly would multiply rows and inflate the revenue
numbers. Refund amounts are allocated proportionally across a return's
items by `line_total` share, since `refunds.amount` is stored at the
return level, not the item level.

**Business interpretation:** *(pending — will fill in once refunds_amount
is populated correctly)*

**What I'd ask next:** *(pending)*

---

## Q5 — Category Health: Purchases → Returns

**What the query does (1 sentence):** Aggregates revenue and return rate
per product category, restricted to paid orders only.

**Pattern choice (1–2 sentences):** Used two CTEs (`category_sales`,
`category_returns`) joined via `product_variants → products → categories`,
since `return_items` references variants, not products or categories
directly.

**Business interpretation (2–3 sentences):** Smartwatch is both the
highest-revenue category (₹5.97 Cr) and — counter to what I expected
going in — the *lowest*-return-rate category at 2.53%, so its revenue
number isn't being inflated by returns. Kitchen has the highest return
rate in the catalog at 3.03%, despite being a mid-tier revenue category
(₹1.36 Cr) — a smaller number, but proportionally the leakiest category.
Overall, though, return rates across all 14 categories sit in a fairly
tight 2.5%–3.0% band — there's no single category with a dramatically
outlying return problem.

**What I'd ask next:** Since Kitchen's return rate is highest but its
revenue is mid-tier, is that return rate driven by a few specific SKUs
(worth a targeted fix) or spread evenly across the category (a broader
sourcing or listing-accuracy issue)?

---

## Q6 — Payment Failure Analysis (Method × Top Error Code)

**What the query does (1 sentence):** Calculates failure rate per payment
method and identifies each method's single most common failure error
using a top-N-per-group pattern.

**Pattern choice (1–2 sentences):** A plain `GROUP BY` can't return "the
top error per method," so used `ROW_NUMBER() OVER (PARTITION BY
payment_method ORDER BY error_count DESC)` on a pre-aggregated error-counts
CTE, then filtered to `rn = 1` in the outer query.

**Business interpretation (2–3 sentences):** UPI has the highest failure
rate at 5.54%, well above every other method (wallet 4.79%, cod 4.69%,
card 4.18%, netbanking 4.17%) — and nearly a quarter of those UPI
failures (23.6%) trace back to a single cause: `GATEWAY_TIMEOUT`. Card
failures are dominated by `FRAUD` flags (27.5% of its failures), which is
a very different kind of problem — one is an infrastructure/reliability
issue, the other is a risk-screening issue. One oddity worth flagging: COD's
top listed error is `UPI_TIMEOUT`, which doesn't make intuitive sense for
a cash-on-delivery method and is worth a data-quality check rather than a
business conclusion.

**What I'd ask next:** Is UPI's gateway timeout concentrated at specific
times of day (peak load) or specific banks? And is the COD/`UPI_TIMEOUT`
pairing a real data issue — e.g. a mislabeled `payment_method_id` — that
should be flagged before trusting this number further?

---

## Q7 — Delivery SLA Breach by Carrier × Shipping Method

**What the query does (1 sentence):** Measures average, median, and p90
delivery days per carrier and shipping method combination, and flags what
share of deliveries breach the 5-day SLA.

**Pattern choice (1–2 sentences):** Used `PERCENTILE_CONT(0.9) WITHIN
GROUP (ORDER BY delivery_days)` to get the p90 — a more honest picture of
"how bad do the worst deliveries get" than an average alone, which a few
very fast deliveries can mask. Excluded shipments with `delivered_at IS
NULL` since those are still in transit, not late by definition.

**Business interpretation (2–3 sentences):** EcomExpress is the clear
underperformer across every shipping method it offers — its express
service has a 21.4% late rate and a p90 of 8 days (60% over the 5-day
SLA), and even its "standard" tier (10.5% late) is worse than any other
carrier's worst combination. Delhivery is the strongest performer,
topping out at just 3.1%–7.1% late rates across all three shipping
methods, with its standard tier the single best combination in the
dataset. This isn't a shipping-method problem, it's a carrier problem —
EcomExpress underperforms Delhivery and Bluedart on every method, not
just one.

**What I'd ask next:** Is EcomExpress's underperformance region-specific
(a last-mile capacity issue in certain areas) or true everywhere it
operates? If it's everywhere, that's a strong case for shifting express/
same-day volume away from EcomExpress toward Delhivery.

---

## Q8 — Customer LTV + Bucket Share of Revenue

**What the query does (1 sentence):** Buckets customers into LTV tiers
(0–999, 1000–4999, 5000–19999, 20000+) and calculates what share of total
revenue each tier represents.

**Pattern choice (1–2 sentences):** Used `SUM(total_revenue) OVER
(PARTITION BY ltv_bucket)` alongside `SUM(total_revenue) OVER ()` to get
each bucket's share of the grand total while still keeping customer-level
rows visible — mixing row-level and aggregate-level reasoning in one pass
rather than collapsing to a bucket-only summary.

**Business interpretation (2–3 sentences):** The concentration here is
extreme: the top `20000+` bucket is 39.7% of customers but accounts for
88.4% of total revenue, while the bottom `0-999` bucket is 5.9% of
customers and contributes just 0.1% of revenue. This isn't a mild Pareto
skew — it's close to the entire business's revenue sitting in two out of
four buckets (`20000+` and `5000-19999` together are ~70% of customers
and ~98% of revenue). Losing even a small percentage of the top bucket
would hurt far more than losing a large share of the bottom one.

**What I'd ask next:** What acquisition channel and first-purchase
category are most associated with customers who end up in the `20000+`
bucket? With this much revenue concentration, identifying what makes a
top-bucket customer is probably the single highest-leverage question in
this whole project.

---

## Q9 — Repeat Purchase Interval

**What the query does (1 sentence):** Calculates the number of days
between each customer's order and their next order, then summarizes the
average, median, and p90 across all customers with a repeat order.

**Pattern choice (1–2 sentences):** Used `LEAD(created_at) OVER
(PARTITION BY customer_id ORDER BY created_at)` to find each order's
successor without a self-join. Filtered out same-day (0-day-gap) repeat
orders before computing the summary, treating them as one shopping
session split into multiple orders rather than genuine "coming back"
behavior.

**Business interpretation (2–3 sentences):** Excluding same-day orders,
customers who return take a median of 6 days to place their next order,
with a p90 of 27 days and an average pulled up to 10.6 days by that
longer tail. The same-day exclusion turned out to matter a lot in
practice, not just in theory: 31.8% of all order-to-next-order rows were
same-day repeats — nearly a third of the raw data would have quietly
dragged the "time to return" numbers toward zero if they hadn't been
filtered out. Only 3,418 customers show a genuine repeat order at all in
this window, which is worth reading alongside Q2's retention numbers.

**What I'd ask next:** A win-back email timed for day 6–10 would catch
the median customer, but should there be a second, later nudge around
day 20–25 to catch the p90 tail before they're gone for good? Two-touch
win-back campaigns often outperform a single fixed-day trigger.

---

## Q10 — Attribution Comparison: First-Touch vs Last-Touch Revenue by Channel

**What the query does (1 sentence):** Compares how revenue is allocated
across channels under first-touch attribution (which channel started the
journey) versus last-touch (which channel closed the sale).

**Pattern choice (1–2 sentences):** Used two separate `ROW_NUMBER()`
partitions on `attribution_touches` — one ordered ascending by touch time
for first-touch, one descending for last-touch — joined back to
per-customer revenue and combined with `UNION ALL` so both models appear
as comparable rows per channel. Customers with no attribution touch were
bucketed as `'direct'` rather than dropped.

**Business interpretation (2–3 sentences):** Organic is the clearest
"opener" channel: it earns 40.2% of first-touch revenue credit but only
38.7% under last-touch — a real 1.5-point drop, meaning it's better at
starting journeys than closing them. Email shows the opposite and more
pronounced pattern: its share rises from 6.27% (first-touch) to 7.16%
(last-touch), roughly a 14% relative increase — email is disproportionately
a *closing* channel. Paid and referral stay almost flat across both models
(paid: 35.9% → 36.1%), suggesting they play a fairly balanced role
throughout the journey rather than skewing toward either end.

**What I'd ask next:** If marketing reporting currently defaults to
last-touch only, is organic's true value being underweighted in budget
decisions by roughly 1.5 points of revenue credit? Testing a modest
reallocation toward organic (or a blended attribution model) could reveal
whether last-touch has been quietly starving the channel that actually
brings people in.

---

## General Note on Methodology

- Cancelled orders were excluded from revenue calculations consistently
  across Q1, Q8, Q9, Q10 (documented choice).
- `orders.status` mixed-case values were normalized with `LOWER()`
  everywhere they were used for filtering or grouping.
- Session-level funnel analysis (Q3) was restricted to sessions on or
  after 2026-04-19, since event instrumentation didn't exist before that
  date.
- Same-day repeat orders (Q9) were excluded from the summary statistics —
  confirmed to be a meaningful decision, since they represented 31.8% of
  all order-pairs in the raw data.
- **Q4 is currently blocked on a data issue** (refunds showing as ₹0
  across all products) and needs to be re-run before its interpretation
  can be finalized.
