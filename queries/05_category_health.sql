
-- Q5: Category Health — Purchases → Returns
-- Owner: RAJ DEV  |  Last updated: 2026-07-07
-- Sanity check: return_rate_pct between 0 and 100. returns <= orders_with_category
-- for every category. sum(revenue) equals sum(line_total) from ecom.order_items
-- on paid orders, within 0.5%.

with category_sales as (
    select
        c.category_name                     as category
      , count(distinct oi.order_id)         as orders_with_category
      , sum(oi.qty)                          as units_sold
      , sum(oi.unit_price * oi.qty)          as revenue
    from ecom.order_items oi
    join ecom.orders o on oi.order_id = o.order_id
    join ecom.product_variants pv on oi.variant_id = pv.variant_id
    join ecom.products p on pv.product_id = p.product_id
    join ecom.categories c on c.category_id = p.category_id
    where o.payment_status = 'paid'
    group by 1
)

, category_returns as (
    select
        c.category_name as category
      , count(*)          as returns
    from ecom.return_items ri
    join ecom.product_variants pv on ri.variant_id = pv.variant_id
    join ecom.products p on pv.product_id = p.product_id
    join ecom.categories c on c.category_id = p.category_id
    group by 1
)

select
    cs.category
  , cs.orders_with_category
  , cs.units_sold
  , cs.revenue
  , coalesce(cr.returns, 0)                                          as returns
  , coalesce(cr.returns, 0) * 100.0 / nullif(cs.orders_with_category, 0) as return_rate_pct
from category_sales cs
left join category_returns cr on cs.category = cr.category
order by cs.revenue desc;
