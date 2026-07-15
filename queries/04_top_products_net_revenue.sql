-- Q4: Top Products by Net Revenue (After Refunds)
-- Owner: RAJ DEV  |  Last updated: 2026-07-09
-- Sanity check: sum(gross_revenue) across all products equals
-- sum(qty * unit_price) from ecom.order_items for the same window, within 0.5%.

with product_revenue as (
    select
        p.product_id
      , p.product_name
      , c.category_name
      , sum(oi.qty)                       as units_sold
      , sum(oi.unit_price * oi.qty)        as gross_revenue
      , count(distinct oi.order_id)        as order_count
    from ecom.order_items oi
    join ecom.product_variants pv on oi.variant_id = pv.variant_id
    join ecom.products p on pv.product_id = p.product_id
    join ecom.categories c on c.category_id = p.category_id
    group by 1, 2, 3
)

, product_returns as (
    select
        p.product_id
      , count(*) as returns_count
    from ecom.return_items ri
    join ecom.product_variants pv on ri.variant_id = pv.variant_id
    join ecom.products p on pv.product_id = p.product_id
    group by 1
)

, return_item_prices as (
    select
        ri.return_id
      , ri.variant_id
      , ri.qty
      , oi.unit_price
      , (ri.qty * oi.unit_price) as line_total
    from ecom.return_items ri
    join ecom.return_requests rr on ri.return_id = rr.return_id
    join ecom.order_items oi on rr.order_id = oi.order_id and ri.variant_id = oi.variant_id
)

, return_item_shares as (
    select
        return_id
      , variant_id
      , line_total
      , line_total * 1.0 / nullif(sum(line_total) over (partition by return_id), 0) as line_total_share
    from return_item_prices
)

, product_refunds as (
    select
        p.product_id
      , sum(rf.amount * ris.line_total_share) as refunds_amount
    from ecom.refunds rf
    join ecom.return_requests rr on rf.order_id = rr.order_id
    join return_item_shares ris on rr.return_id = ris.return_id
    join ecom.product_variants pv on ris.variant_id = pv.variant_id
    join ecom.products p on pv.product_id = p.product_id
    group by 1
)

select
    pr.product_id
  , pr.product_name
  , pr.category_name
  , pr.gross_revenue
  , pr.order_count                                                        as orders_count
  , pr.units_sold
  , coalesce(pret.returns_count, 0)                                       as returns_count
  , coalesce(pret.returns_count, 0) * 1.0 / nullif(pr.order_count, 0)     as return_rate
  , coalesce(pf.refunds_amount, 0)                                        as refunds_amount
  , pr.gross_revenue - coalesce(pf.refunds_amount, 0)                     as net_revenue
from product_revenue pr
left join product_returns pret on pr.product_id = pret.product_id
left join product_refunds pf on pr.product_id = pf.product_id
order by net_revenue desc;
