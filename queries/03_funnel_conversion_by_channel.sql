WITH channels_per_session AS (
    SELECT
        COALESCE(sc.channel, 'direct') AS channel,
        COUNT(DISTINCT se.session_id) AS sessions,
        -- FILTER ki jagah standard CASE WHEN use kiya
        COUNT(DISTINCT CASE WHEN se.event_type = 'product_view' THEN se.session_id END) AS product_view_sessions,
        COUNT(DISTINCT CASE WHEN se.event_type = 'add_to_cart' THEN se.session_id END) AS add_to_cart_sessions,
        COUNT(DISTINCT CASE WHEN se.event_type = 'begin_checkout' THEN se.session_id END) AS begin_checkout_sessions,
        COUNT(DISTINCT CASE WHEN se.event_type = 'purchase' THEN se.session_id END) AS purchase_sessions
    FROM
        ecom.session_events se
    LEFT JOIN 
        ecom.session_channels sc ON se.session_id = sc.session_id
    WHERE
        se.occurred_at >= '2026-04-19'
    GROUP BY 
        1
)
SELECT
    *, -- Sari columns upar se utha li
    add_to_cart_sessions * 1.0 / NULLIF(product_view_sessions, 0) AS view_to_cart_rate,
    begin_checkout_sessions * 1.0 / NULLIF(add_to_cart_sessions, 0) AS cart_to_checkout_rate,
    purchase_sessions * 1.0 / NULLIF(begin_checkout_sessions, 0) AS checkout_to_purchase_rate,
    purchase_sessions * 1.0 / NULLIF(sessions, 0) AS session_to_purchase_rate
FROM
    channels_per_session;
