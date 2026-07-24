-- Builds a chronological session-level purchase funnel and a stage summary table.

CREATE OR REPLACE TABLE
  `product-analytics-hv.product_analytics.funnel_sessions` AS

WITH raw_events AS (
  SELECT
    event_timestamp,
    event_name,
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN (
      'view_item',
      'add_to_cart',
      'begin_checkout',
      'purchase'
    )
),

stage_events AS (
  SELECT
    CONCAT(
      user_pseudo_id,
      '-',
      CAST(ga_session_id AS STRING)
    ) AS session_id,
    event_name,
    event_timestamp
  FROM
    raw_events
  WHERE
    ga_session_id IS NOT NULL
),

view_stage AS (
  SELECT
    session_id,
    MIN(event_timestamp) AS view_item_timestamp
  FROM
    stage_events
  WHERE
    event_name = 'view_item'
  GROUP BY
    session_id
),

cart_stage AS (
  SELECT
    view_stage.session_id,
    view_stage.view_item_timestamp,
    MIN(stage_events.event_timestamp) AS add_to_cart_timestamp
  FROM
    view_stage
  LEFT JOIN
    stage_events
    ON view_stage.session_id = stage_events.session_id
    AND stage_events.event_name = 'add_to_cart'
    AND stage_events.event_timestamp >= view_stage.view_item_timestamp
  GROUP BY
    view_stage.session_id,
    view_stage.view_item_timestamp
),

checkout_stage AS (
  SELECT
    cart_stage.session_id,
    cart_stage.view_item_timestamp,
    cart_stage.add_to_cart_timestamp,
    MIN(stage_events.event_timestamp) AS begin_checkout_timestamp
  FROM
    cart_stage
  LEFT JOIN
    stage_events
    ON cart_stage.session_id = stage_events.session_id
    AND stage_events.event_name = 'begin_checkout'
    AND cart_stage.add_to_cart_timestamp IS NOT NULL
    AND stage_events.event_timestamp >= cart_stage.add_to_cart_timestamp
  GROUP BY
    cart_stage.session_id,
    cart_stage.view_item_timestamp,
    cart_stage.add_to_cart_timestamp
),

purchase_stage AS (
  SELECT
    checkout_stage.session_id,
    checkout_stage.view_item_timestamp,
    checkout_stage.add_to_cart_timestamp,
    checkout_stage.begin_checkout_timestamp,
    MIN(stage_events.event_timestamp) AS purchase_timestamp
  FROM
    checkout_stage
  LEFT JOIN
    stage_events
    ON checkout_stage.session_id = stage_events.session_id
    AND stage_events.event_name = 'purchase'
    AND checkout_stage.begin_checkout_timestamp IS NOT NULL
    AND stage_events.event_timestamp >= checkout_stage.begin_checkout_timestamp
  GROUP BY
    checkout_stage.session_id,
    checkout_stage.view_item_timestamp,
    checkout_stage.add_to_cart_timestamp,
    checkout_stage.begin_checkout_timestamp
)

SELECT
  sessions.session_id,
  sessions.user_pseudo_id,
  sessions.session_date,
  sessions.device_category,
  sessions.operating_system,
  sessions.country,
  sessions.traffic_source,
  sessions.traffic_medium,
  sessions.campaign_name,

  TIMESTAMP_MICROS(
    purchase_stage.view_item_timestamp
  ) AS view_item_timestamp,

  TIMESTAMP_MICROS(
    purchase_stage.add_to_cart_timestamp
  ) AS add_to_cart_timestamp,

  TIMESTAMP_MICROS(
    purchase_stage.begin_checkout_timestamp
  ) AS begin_checkout_timestamp,

  TIMESTAMP_MICROS(
    purchase_stage.purchase_timestamp
  ) AS purchase_timestamp,

  1 AS viewed_item,

  IF(
    purchase_stage.add_to_cart_timestamp IS NOT NULL,
    1,
    0
  ) AS added_to_cart,

  IF(
    purchase_stage.begin_checkout_timestamp IS NOT NULL,
    1,
    0
  ) AS began_checkout,

  IF(
    purchase_stage.purchase_timestamp IS NOT NULL,
    1,
    0
  ) AS purchased

FROM
  purchase_stage
INNER JOIN
  `product-analytics-hv.product_analytics.sessions` AS sessions
  ON purchase_stage.session_id = sessions.session_id;


CREATE OR REPLACE TABLE
  `product-analytics-hv.product_analytics.funnel_summary` AS

WITH funnel_counts AS (
  SELECT
    COUNT(*) AS product_view_sessions,
    COUNTIF(added_to_cart = 1) AS cart_sessions,
    COUNTIF(began_checkout = 1) AS checkout_sessions,
    COUNTIF(purchased = 1) AS purchase_sessions
  FROM
    `product-analytics-hv.product_analytics.funnel_sessions`
)

SELECT
  1 AS stage_order,
  'Product view' AS stage_name,
  product_view_sessions AS sessions,
  100.00 AS conversion_from_previous_stage_pct,
  100.00 AS conversion_from_product_view_pct,
  product_view_sessions - cart_sessions AS dropoff_to_next_stage,
  ROUND(
    100 * SAFE_DIVIDE(
      product_view_sessions - cart_sessions,
      product_view_sessions
    ),
    2
  ) AS dropoff_to_next_stage_pct
FROM
  funnel_counts

UNION ALL

SELECT
  2,
  'Add to cart',
  cart_sessions,
  ROUND(
    100 * SAFE_DIVIDE(cart_sessions, product_view_sessions),
    2
  ),
  ROUND(
    100 * SAFE_DIVIDE(cart_sessions, product_view_sessions),
    2
  ),
  cart_sessions - checkout_sessions,
  ROUND(
    100 * SAFE_DIVIDE(
      cart_sessions - checkout_sessions,
      cart_sessions
    ),
    2
  )
FROM
  funnel_counts

UNION ALL

SELECT
  3,
  'Begin checkout',
  checkout_sessions,
  ROUND(
    100 * SAFE_DIVIDE(checkout_sessions, cart_sessions),
    2
  ),
  ROUND(
    100 * SAFE_DIVIDE(checkout_sessions, product_view_sessions),
    2
  ),
  checkout_sessions - purchase_sessions,
  ROUND(
    100 * SAFE_DIVIDE(
      checkout_sessions - purchase_sessions,
      checkout_sessions
    ),
    2
  )
FROM
  funnel_counts

UNION ALL

SELECT
  4,
  'Purchase',
  purchase_sessions,
  ROUND(
    100 * SAFE_DIVIDE(purchase_sessions, checkout_sessions),
    2
  ),
  ROUND(
    100 * SAFE_DIVIDE(purchase_sessions, product_view_sessions),
    2
  ),
  CAST(NULL AS INT64),
  CAST(NULL AS FLOAT64)
FROM
  funnel_counts;
