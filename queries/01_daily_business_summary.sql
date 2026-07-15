-- Q1: Daily Business Summary + DoD / Same-Weekday WoW Comparisons
-- Owner: RAJ DEV |  Last updated: 2026-07-05
-- Sanity check: paid_order_rate between 0 and 1 on every row;
-- sum(orders) across all days equals count(*) of ecom.orders for the same window.

with daily_orders as (
    select
        date_trunc('day', o.created_at)::date                      as order_date
      , count(*)                                                   as orders
      , sum(o.total)                                                as revenue
      , count(*) filter (where o.payment_status = 'paid')          as paid_orders
      , count(*) filter (where lower(o.status) = 'cancelled')      as cancelled_orders
    from ecom.orders o
    group by 1
)

, daily_refunds as (
    select
        date_trunc('day', r.created_at)::date as order_date
      , sum(r.amount)                          as refunds_amount
    from ecom.refunds r
    group by 1
)

select
    dor.order_date
  , dor.revenue
  , dor.orders
  , (dor.revenue * 1.0 / nullif(dor.orders, 0))                as aov
  , (dor.paid_orders      * 1.0 / nullif(dor.orders, 0))       as paid_order_rate
  , (dor.cancelled_orders  * 1.0 / nullif(dor.orders, 0))      as cancelled_order_rate
  , coalesce(dr.refunds_amount, 0)                            as refunds_amount
  , (dor.revenue - lag(dor.revenue, 1) over (order by dor.order_date))
        / nullif(lag(dor.revenue, 1) over (order by dor.order_date), 0) as revenue_vs_yesterday_pct
  , (dor.revenue - lag(dor.revenue, 7) over (order by dor.order_date))
        / nullif(lag(dor.revenue, 7) over (order by dor.order_date), 0) as revenue_vs_last_weekday_pct
from daily_orders dor
left join daily_refunds dr using (order_date)
order by dor.order_date desc;
