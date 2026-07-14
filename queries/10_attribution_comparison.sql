-- Q10: Attribution Comparison — First-Touch vs Last-Touch Revenue by Channel
-- Owner: <your name>  |  Last updated: 2026-07-08
-- Sanity check: total revenue under first_touch equals total under last_touch
-- equals total non-cancelled revenue in ecom.orders, within 0.5%.

with first_touch as (
    select
        s.customer_id
      , at.channel
      , row_number() over (
            partition by s.customer_id
            order by at.touched_at asc
        ) as rn
    from ecom.attribution_touches at
    join ecom.sessions s on at.session_id = s.session_id
)

, last_touch as (
    select
        s.customer_id
      , at.channel
      , row_number() over (
            partition by s.customer_id
            order by at.touched_at desc
        ) as rn
    from ecom.attribution_touches at
    join ecom.sessions s on at.session_id = s.session_id
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

, first_touch_channel_revenue as (
    select
        coalesce(ft.channel, 'direct') as channel
      , sum(orv.revenue)               as revenue
      , sum(orv.orders)                as orders
    from order_revenue orv
    left join first_touch ft on orv.customer_id = ft.customer_id and ft.rn = 1
    group by 1
)

, last_touch_channel_revenue as (
    select
        coalesce(lt.channel, 'direct') as channel
      , sum(orv.revenue)               as revenue
      , sum(orv.orders)                as orders
    from order_revenue orv
    left join last_touch lt on orv.customer_id = lt.customer_id and lt.rn = 1
    group by 1
)

select
    'first_touch'                                       as attribution_model
  , channel
  , revenue
  , orders
  , revenue * 1.0 / sum(revenue) over ()                 as share_of_revenue
from first_touch_channel_revenue

union all

select
    'last_touch'                                         as attribution_model
  , channel
  , revenue
  , orders
  , revenue * 1.0 / sum(revenue) over ()                 as share_of_revenue
from last_touch_channel_revenue

order by attribution_model, revenue desc;
