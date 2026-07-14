
-- Q7: Delivery SLA Breach by Carrier × Shipping Method
-- Owner: <your name>  |  Last updated: 2026-07-08
-- Sanity check: avg_delivery_days <= p90_delivery_days on every row; late_rate in [0, 1].

with delivery_stats as (
    select
        sc.carrier_name                                                    as carrier
      , sm.method_name                                                     as shipping_method
      , (s.delivered_at::date - s.shipped_at::date)                        as delivery_days
    from ecom.shipments s
    join ecom.shipping_carriers sc on s.carrier_id = sc.carrier_id
    join ecom.shipping_methods sm on s.shipping_method_id = sm.shipping_method_id
    where s.delivered_at is not null
)

select
    carrier
  , shipping_method
  , count(*)                                                              as delivered_orders
  , avg(delivery_days)                                                    as avg_delivery_days
  , percentile_cont(0.5) within group (order by delivery_days)            as median_delivery_days
  , percentile_cont(0.9) within group (order by delivery_days)            as p90_delivery_days
  , count(*) filter (where delivery_days > 5)                             as late_deliveries
  , count(*) filter (where delivery_days > 5) * 1.0 / nullif(count(*), 0) as late_rate
from delivery_stats
group by 1, 2
order by late_rate desc;
