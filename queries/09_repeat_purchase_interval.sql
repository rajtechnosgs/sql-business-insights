-- Q9: Repeat Purchase Interval
-- Owner: <your name>  |  Last updated: 2026-07-09
-- Sanity check: days_to_next_order >= 0 on every row; median <= p90 in summary.

-- === Row-level output ===
with order_sequence as (
    select
        customer_id
      , order_id
      , created_at::date as order_date
      , lead(created_at::date) over (
            partition by customer_id order by created_at
        ) as next_order_date
    from ecom.orders
    where lower(status) != 'cancelled'
)

select
    customer_id
  , order_id
  , order_date
  , next_order_date
  , (next_order_date - order_date) as days_to_next_order
from order_sequence
order by customer_id, order_date;


-- === Summary output ===
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
      and (next_order_date - order_date) > 0   -- excludes same-day split orders
)

select
    avg(days_to_next_order)                                           as avg_days_to_next_order
  , percentile_cont(0.5) within group (order by days_to_next_order)    as median_days_to_next_order
  , percentile_cont(0.9) within group (order by days_to_next_order)    as p90_days_to_next_order
  , count(distinct customer_id)                                       as customers_with_repeat_order
from gaps;
