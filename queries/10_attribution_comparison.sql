-- Q10: Attribution Comparison — First-Touch vs Last-Touch Revenue by Channel
-- Owner: Raj Dev  |  Last updated: 2026-07-17
-- Sanity check: total revenue under first_touch equals total under last_touch
-- equals total non-cancelled revenue in ecom.orders, within 0.5%.

with order_amounts as (
    select
        order_id
      , customer_id
      , created_at
      , total
    from ecom.orders
    where lower(status) != 'cancelled'
)

, order_touches as (
    select
        oa.order_id
      , at.channel
      , row_number() over (
            partition by oa.order_id order by at.touched_at asc
        ) as rn_first
      , row_number() over (
            partition by oa.order_id order by at.touched_at desc
        ) as rn_last
    from order_amounts oa
    join ecom.sessions s on oa.customer_id = s.customer_id
    join ecom.attribution_touches at on s.session_id = at.session_id
    where at.touched_at <= oa.created_at
)

, first_touch_orders as (
    select order_id, channel from order_touches where rn_first = 1
)

, last_touch_orders as (
    select order_id, channel from order_touches where rn_last = 1
)

, first_touch_channel_revenue as (
    select
        coalesce(ft.channel, 'direct') as channel
      , sum(oa.total)                  as revenue
      , count(*)                       as orders
    from order_amounts oa
    left join first_touch_orders ft on oa.order_id = ft.order_id
    group by 1
)

, last_touch_channel_revenue as (
    select
        coalesce(lt.channel, 'direct') as channel
      , sum(oa.total)                  as revenue
      , count(*)                       as orders
    from order_amounts oa
    left join last_touch_orders lt on oa.order_id = lt.order_id
    group by 1
)

select
    'first_touch' as attribution_model
  , channel
  , revenue
  , orders
  , revenue * 1.0 / sum(revenue) over () as share_of_revenue
from first_touch_channel_revenue

union all

select
    'last_touch' as attribution_model
  , channel
  , revenue
  , orders
  , revenue * 1.0 / sum(revenue) over () as share_of_revenue
from last_touch_channel_revenue

order by attribution_model, revenue desc;
