
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

**Business interpretation (2–3 sentences):** The paid order rate stays
consistently high across the whole window, so payment failure isn't a major
day-to-day revenue leak. Revenue shows a recognizable weekday-vs-weekend
rhythm rather than random noise, which is why the same-weekday comparison
matters more than a plain yesterday-vs-today comparison for this business.

**What I'd ask next:** Is the paid order rate stable across every payment
method, or is one method dragging the overall number down? That would tell
us whether this is a checkout UX issue or a specific gateway issue.

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

**Business interpretation (2–3 sentences):** Only the earliest cohort has a
fully observable m3 retention figure — every later cohort's later months are
censored, not zero, which is an easy trap to fall into if you don't check
for it. Retention clearly drops off the further out you look, meaning most
of the "coming back" behavior, if it happens at all, happens early.

**What I'd ask next:** Is month-1 retention trending up or down across
successive cohorts? A declining trend would suggest something in the
post-signup experience is getting worse as the business scales, not better.

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

**Business interpretation (2–3 sentences):** Some channels convert
sessions to purchases far more efficiently than others, even when they
bring in fewer total sessions — volume and quality of traffic clearly
don't move together here. Across nearly every channel, the biggest
drop-off happens at the same funnel stage, which points to a shared
product or checkout issue rather than a channel-specific traffic-quality
problem.

**What I'd ask next:** Is that shared drop-off stage worse on mobile than
desktop? If it's a device-specific pattern, it's a UX fix; if it's uniform
across devices, the cause is probably somewhere else in the funnel.

---

## Q4 — Top Products by Net Revenue (After Refunds)

**What the query does (1 sentence):** Ranks products by revenue net of
refunds, by aggregating gross revenue, returns, and refunds in three
separate CTEs before combining them.

**Pattern choice (1–2 sentences):** Kept revenue, returns, and refunds as
three independent CTEs (`product_revenue`, `product_returns`,
`product_refunds`) rather than one multi-join query, since joining all
three raw tables directly would multiply rows and inflate the revenue
numbers.

**Business interpretation (2–3 sentences):** The top product by gross
revenue is not the same as the top product by net revenue — a couple of
high-selling products lose a meaningful chunk of their revenue to returns,
while some lower-gross products barely get returned at all. A founder
optimizing for margin rather than top-line sales should rank products by
net, not gross, or they'll keep pushing products that quietly cost more
than they earn.

**What I'd ask next:** For the highest-return products, are the return
reasons mostly about sizing/fit, quality, or "changed mind"? Each implies
a different fix — a sizing guide, a QC review, or clearer product-page
expectations.

---

## Q5 — Category Health: Purchases → Returns

**What the query does (1 sentence):** Aggregates revenue and return rate
per product category, restricted to paid orders only.

**Pattern choice (1–2 sentences):** Used two CTEs (`category_sales`,
`category_returns`) joined via `product_variants → products → categories`,
since `return_items` references variants, not products or categories
directly.

**Business interpretation (2–3 sentences):** The category driving the most
revenue is also the one with the highest return rate, which means its
"true" contribution to the business is smaller than the top-line number
suggests. Meanwhile, at least one smaller category is quietly healthy —
lower revenue, but a much lower return rate — making it a better candidate
for extra marketing spend relative to its current size.

**What I'd ask next:** Is the top category's high return rate driven by a
handful of specific products, or spread evenly across everything in that
category? That distinguishes a targeted product fix from a category-wide
sizing or quality problem.

---

## Q6 — Payment Failure Analysis (Method × Top Error Code)

**What the query does (1 sentence):** Calculates failure rate per payment
method and identifies each method's single most common failure error
using a top-N-per-group pattern.

**Pattern choice (1–2 sentences):** A plain `GROUP BY` can't return "the
top error per method," so used `ROW_NUMBER() OVER (PARTITION BY
payment_method ORDER BY error_count DESC)` on a pre-aggregated error-counts
CTE, then filtered to `rn = 1` in the outer query.

**Business interpretation (2–3 sentences):** One payment method clearly
fails more often than the others, and for that method, failures aren't
spread across many unrelated causes — a single error code accounts for
most of them. That concentration is good news operationally: fixing one
root cause could meaningfully move that method's overall failure rate,
rather than requiring a dozen small fixes.

**What I'd ask next:** Is that top error code a gateway-side issue (bank
declines, timeouts) or something fixable on our end (a broken OTP flow,
an expired session)? That determines whether this becomes a support
escalation to the payment partner or an internal engineering fix.

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

**Business interpretation (2–3 sentences):** One specific carrier-and-
shipping-method combination stands out with a noticeably higher late rate
and a p90 delivery time well past the SLA, while most other combinations
stay close to it. That single combination is likely responsible for a
disproportionate share of delivery complaints, even though it may only be
a small slice of total shipments.

**What I'd ask next:** Is that carrier's SLA breach concentrated in a
specific region, or consistent everywhere it ships? A regional pattern
points to a last-mile logistics gap; a uniform pattern points to a
carrier-wide capacity problem.

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

**Business interpretation (2–3 sentences):** A small top-spending segment
of customers accounts for a disproportionately large share of total
revenue compared to their share of the customer base — a classic Pareto
pattern. The largest bucket by customer count contributes the least to
revenue, which makes it valuable mainly as a pool for future upsell rather
than as a current revenue driver.

**What I'd ask next:** Which acquisition channel is over-represented in
the top-spending bucket? If one channel disproportionately brings in
high-LTV customers, it deserves more retention and loyalty budget, not
just acquisition budget.

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
behavior — this choice visibly shifted the median versus including them.

**Business interpretation (2–3 sentences):** Most customers who do return
come back within a fairly tight window, but there's a real tail of
customers who take much longer — the gap between the median and the p90
is wide. A win-back email timed around the typical return window would
catch the bulk of lapsing customers before they're fully gone, without
spamming people who were always going to come back on their own.

**What I'd ask next:** Does the repeat interval differ meaningfully by a
customer's first-order category or first-order channel? If certain
categories create "stickier" customers, that's a signal for what to
feature in onboarding flows for new signups.

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
bucketed as `'direct'` rather than dropped, so the two totals still
reconcile to overall revenue.

**Business interpretation (2–3 sentences):** At least one channel looks
much stronger under first-touch than under last-touch — it's good at
starting the customer journey but rarely gets credit for closing the
sale. Another channel shows the opposite pattern, doing more of the
"closing" work. Crediting the wrong model to the wrong channel risks
over-funding awareness at the expense of conversion, or vice versa.

**What I'd ask next:** If a channel is systematically undervalued by
last-touch attribution, would switching to a blended or time-decay model
change the marketing budget allocation enough to be worth moving off
last-touch as the default reporting view?

---

## General Note on Methodology (for reference when writing the case study)

- Cancelled orders were excluded from revenue calculations consistently
  across Q1, Q8, Q9, Q10 (documented choice).
- `orders.status` mixed-case values were normalized with `LOWER()`
  everywhere they were used for filtering or grouping.
- Session-level funnel analysis (Q3) was restricted to sessions on or
  after 2026-04-19, since event instrumentation didn't exist before that
  date.
- Same-day repeat orders (Q9) were treated as a single shopping session,
  not genuine repeat behavior — an explicit choice with business
  rationale (a win-back email is irrelevant to them).
