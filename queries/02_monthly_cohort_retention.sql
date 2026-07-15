-- Q2: Monthly Signup Cohort Retention
-- Owner: Raj Dev  |  Last updated: 2026-07-09
-- Sanity check: cohort_size for any month equals count(distinct customer_id)
-- from customers where date_trunc('month', created_at) = cohort_month.
-- All retention rates in [0, 1]. Censored cells are NULL, not 0.

with customer_signup as (
    select
        customer_id
      , date_trunc('month', created_at)::date as signup_month
    from ecom.customers
)

, customer_orders as (
    select
        o.customer_id
      , date_trunc('month', o.created_at)::date as order_month
    from ecom.orders o
    where lower(o.status) != 'cancelled'
    group by 1, 2
)

, customer_activity as (
    select
        cs.customer_id
      , cs.signup_month
      , co.order_month
      , (extract(year from co.order_month) - extract(year from cs.signup_month)) * 12
          + (extract(month from co.order_month) - extract(month from cs.signup_month)) as month_gap
    from customer_signup cs
    left join customer_orders co on cs.customer_id = co.customer_id
)

, cohort_sizes as (
    select
        signup_month
      , count(distinct customer_id) as cohort_size
    from customer_signup
    group by 1
)

, retention_counts as (
    select
        signup_month
      , count(distinct customer_id) filter (where month_gap = 1) as m1_retained
      , count(distinct customer_id) filter (where month_gap = 2) as m2_retained
      , count(distinct customer_id) filter (where month_gap = 3) as m3_retained
    from customer_activity
    group by 1
)

, max_order_month as (
    select max(order_month) as latest_month
    from customer_orders
)

select
    cs.signup_month                                                   as cohort_month
  , cs.cohort_size
  , rc.m1_retained
  , rc.m2_retained
  , rc.m3_retained
  , case
        when cs.signup_month + interval '1 month' <= mo.latest_month
        then rc.m1_retained * 1.0 / nullif(cs.cohort_size, 0)
        else null
    end as m1_retention_rate
  , case
        when cs.signup_month + interval '2 months' <= mo.latest_month
        then rc.m2_retained * 1.0 / nullif(cs.cohort_size, 0)
        else null
    end as m2_retention_rate
  , case
        when cs.signup_month + interval '3 months' <= mo.latest_month
        then rc.m3_retained * 1.0 / nullif(cs.cohort_size, 0)
        else null
    end as m3_retention_rate
from cohort_sizes cs
left join retention_counts rc on cs.signup_month = rc.signup_month
cross join max_order_month mo
order by cs.signup_month;
