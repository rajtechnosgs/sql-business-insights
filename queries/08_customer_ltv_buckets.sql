
-- Q8: Customer LTV + Bucket Share of Revenue
-- Owner: <your name>  |  Last updated: 2026-07-08
-- Sanity check: sum(total_revenue) equals revenue from ecom.orders (excluding
-- cancelled), within 0.5%. ltv_bucket_share_of_revenue sums to 1.0 across buckets.

with customer_ltv as (
    select
        o.customer_id
      , min(o.created_at)::date         as first_order_date
      , max(o.created_at)::date         as last_order_date
      , count(*)                        as total_orders
      , sum(o.total)                    as total_revenue
    from ecom.orders o
    where lower(o.status) != 'cancelled'
    group by 1
)

select
    customer_id
  , first_order_date
  , last_order_date
  , total_orders
  , total_revenue
  , total_revenue * 1.0 / nullif(total_orders, 0)                    as aov
  , case
        when total_revenue >= 20000 then '20000+'
        when total_revenue >= 5000  then '5000-19999'
        when total_revenue >= 1000  then '1000-4999'
        else '0-999'
    end                                                                as ltv_bucket
  , sum(total_revenue) over (
        partition by case
            when total_revenue >= 20000 then '20000+'
            when total_revenue >= 5000  then '5000-19999'
            when total_revenue >= 1000  then '1000-4999'
            else '0-999'
        end
    ) * 1.0 / sum(total_revenue) over ()                              as ltv_bucket_share_of_revenue
from customer_ltv
order by total_revenue desc;
