
-- Q10: Attribution Comparison — First-Touch vs Last-Touch Revenue by Channel
-- Owner: <your name>  |  Last updated: 2026-07-08
-- Sanity check: total revenue under first_touch equals total under last_touch
-- equals total non-cancelled revenue in ecom.orders, within 0.5%.

with first_touch as (
    select
        at.customer_id
      , at.channel
      , row_number() over (
            partition by at.customer_id
            order by at.occurred_at asc
        ) as rn
    from ecom.attribution_touches at
)

, last_touch as (
    select
        at.customer_id
      , at.channel
      , row_number() over (
            partition by at.customer_id
            order by at.occurred_at desc
        ) as rn
    from ecom.attribution_touches at
)

, order_revenue as (
    select
        customer_id
      , sum(total) as revenue
      , count(*)   as orders
    from ecom.orders
    where lower(status) != 'cancelled'
    group by 1
)

select
    'first_touch'                                                       as attribution_model
  , coalesce(ft.channel, 'direct')                                      as channel
  , sum(orv.revenue)                                                    as revenue
  , sum(orv.orders)                                                     as orders
  , sum(orv.revenue) * 1.0 / sum(sum(orv.revenue)) over ()              as share_of_revenue
from order_revenue orv
left join first_touch ft on orv.customer_id = ft.customer_id and ft.rn = 1
group by 2

union all

select
    'last_touch'                                                        as attribution_model
  , coalesce(lt.channel, 'direct')                                      as channel
  , sum(orv.revenue)                                                    as revenue
  , sum(orv.orders)                                                     as orders
  , sum(orv.revenue) * 1.0 / sum(sum(orv.revenue)) over ()              as share_of_revenue
from order_revenue orv
left join last_touch lt on orv.customer_id = lt.customer_id and lt.rn = 1
group by 2

order by attribution_model, revenue desc;
