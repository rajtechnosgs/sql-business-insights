-- Q9b: Repeat Purchase Interval — Summary
-- Owner: Raj Dev  |  Last updated: 2026-07-17
-- Sanity check: median <= p90 in summary.

with order_sequence as (
    select
        customer_id
      , created_at::date as order_date
      , lead(created_at::date) over (
            partition by customer_id order by created_at
        ) as next_order_date
    from ecom.orders
    where lower(status) != 'cancelled'
)

, gaps as (
    select
        customer_id
      , (next_order_date - order_date) as days_to_next_order
    from order_sequence
    where next_order_date is not null
      and (next_order_date - order_date) > 0
)

select
    avg(days_to_next_order)                                           as avg_days_to_next_order
  , percentile_cont(0.5) within group (order by days_to_next_order)    as median_days_to_next_order
  , percentile_cont(0.9) within group (order by days_to_next_order)    as p90_days_to_next_order
  , count(distinct customer_id)                                       as customers_with_repeat_order
from gaps;
