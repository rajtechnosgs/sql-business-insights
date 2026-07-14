
-- Q6: Payment Failure Analysis (Method × Top Error Code)
-- Owner: <your name>  |  Last updated: 2026-07-08
-- Sanity check: failure_rate and top_error_share_of_failures both in [0, 1].

with method_attempts as (
    select
        pm.method_name                                              as payment_method
      , count(*)                                                    as attempts
      , count(*) filter (where lower(pt.status) = 'failed')         as failures
    from ecom.payment_transactions pt
    join ecom.payment_intents pi on pt.payment_intent_id = pi.payment_intent_id
    join ecom.payment_methods pm on pi.payment_method_id = pm.payment_method_id
    group by 1
)

, ranked_errors as (
    select
        pm.method_name                                    as payment_method
      , pt.error_code
      , pt.error_message
      , count(*)                                           as error_count
      , row_number() over (
            partition by pm.method_name
            order by count(*) desc
        )                                                   as rn
    from ecom.payment_transactions pt
    join ecom.payment_intents pi on pt.payment_intent_id = pi.payment_intent_id
    join ecom.payment_methods pm on pi.payment_method_id = pm.payment_method_id
    where lower(pt.status) = 'failed'
    group by 1, 2, 3
)

select
    ma.payment_method
  , ma.attempts
  , ma.failures
  , ma.failures * 1.0 / nullif(ma.attempts, 0)              as failure_rate
  , re.error_code                                            as top_error_code
  , re.error_message                                         as top_error_message
  , re.error_count * 1.0 / nullif(ma.failures, 0)            as top_error_share_of_failures
from method_attempts ma
left join ranked_errors re on ma.payment_method = re.payment_method and re.rn = 1
order by ma.failure_rate desc;
