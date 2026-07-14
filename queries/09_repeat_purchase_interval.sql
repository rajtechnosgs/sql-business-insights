-- Q9: Repeat Purchase Interval
-- Owner: <your name>  |  Last updated: 2026-07-08
-- Sanity check: days_to_next_order >= 0 on every row; median <= p90 in summary.

with order_sequence as (
    select
        customer_id
      , order_id
      , created_at::date                                                as order_date
      , lead(created_at::date) over (
            partition by customer_id order by created_at
        )                                                                 as next_order_date
    from ecom.orders
    where lower(status) != 'cancelled'
)

select
    customer_id
  , order_id
  , order_date
  , next_order_date
  , (next_order_date - order_date)                                       as days_to_next_order
from order_sequence
order by customer_id, order_date;
