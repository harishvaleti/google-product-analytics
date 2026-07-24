-- Builds a chronological session-level purchase funnel, stage summary,
-- segment-level conversion metrics, and confidence intervals.

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


CREATE OR REPLACE TABLE
  `product-analytics-hv.product_analytics.funnel_segment_summary` AS

WITH funnel_base AS (
  SELECT
    funnel.session_id,
    funnel.device_category,
    funnel.traffic_source,
    funnel.traffic_medium,
    funnel.added_to_cart,
    funnel.began_checkout,
    funnel.purchased,
    sessions.purchase_revenue_usd
  FROM
    `product-analytics-hv.product_analytics.funnel_sessions` AS funnel
  INNER JOIN
    `product-analytics-hv.product_analytics.sessions` AS sessions
    ON funnel.session_id = sessions.session_id
),

segment_counts AS (
  SELECT
    'Device category' AS segment_type,
    COALESCE(device_category, 'unknown') AS segment_value,

    COUNT(*) AS product_view_sessions,
    COUNTIF(added_to_cart = 1) AS cart_sessions,
    COUNTIF(began_checkout = 1) AS checkout_sessions,
    COUNTIF(purchased = 1) AS purchase_sessions,

    SUM(
      IF(purchased = 1, purchase_revenue_usd, 0)
    ) AS purchase_revenue_usd

  FROM
    funnel_base

  GROUP BY
    segment_value

  UNION ALL

  SELECT
    'First-user source / medium' AS segment_type,

    CONCAT(
      COALESCE(traffic_source, '(direct)'),
      ' / ',
      COALESCE(traffic_medium, '(none)')
    ) AS segment_value,

    COUNT(*) AS product_view_sessions,
    COUNTIF(added_to_cart = 1) AS cart_sessions,
    COUNTIF(began_checkout = 1) AS checkout_sessions,
    COUNTIF(purchased = 1) AS purchase_sessions,

    SUM(
      IF(purchased = 1, purchase_revenue_usd, 0)
    ) AS purchase_revenue_usd

  FROM
    funnel_base

  GROUP BY
    segment_value
)

SELECT
  segment_type,
  segment_value,

  product_view_sessions,
  cart_sessions,
  checkout_sessions,
  purchase_sessions,

  ROUND(
    100 * SAFE_DIVIDE(
      cart_sessions,
      product_view_sessions
    ),
    2
  ) AS view_to_cart_conversion_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      checkout_sessions,
      cart_sessions
    ),
    2
  ) AS cart_to_checkout_conversion_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      purchase_sessions,
      checkout_sessions
    ),
    2
  ) AS checkout_to_purchase_conversion_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      purchase_sessions,
      product_view_sessions
    ),
    2
  ) AS view_to_purchase_conversion_pct,

  product_view_sessions - cart_sessions
    AS view_to_cart_dropoff_sessions,

  ROUND(
    100 * SAFE_DIVIDE(
      product_view_sessions - cart_sessions,
      product_view_sessions
    ),
    2
  ) AS view_to_cart_dropoff_pct,

  ROUND(purchase_revenue_usd, 2)
    AS purchase_revenue_usd,

  ROUND(
    SAFE_DIVIDE(
      purchase_revenue_usd,
      product_view_sessions
    ),
    2
  ) AS revenue_per_product_view_session_usd

FROM
  segment_counts

WHERE
  product_view_sessions >= 500;


CREATE OR REPLACE TABLE
  `product-analytics-hv.product_analytics.funnel_segment_statistics` AS

WITH overall AS (
  SELECT
    COUNT(*) AS product_view_sessions,
    COUNTIF(purchased = 1) AS purchase_sessions
  FROM
    `product-analytics-hv.product_analytics.funnel_sessions`
),

segment_rates AS (
  SELECT
    segment.segment_type,
    segment.segment_value,
    segment.product_view_sessions,
    segment.cart_sessions,
    segment.checkout_sessions,
    segment.purchase_sessions,
    segment.view_to_cart_conversion_pct,
    segment.cart_to_checkout_conversion_pct,
    segment.checkout_to_purchase_conversion_pct,
    segment.view_to_purchase_conversion_pct,
    segment.purchase_revenue_usd,
    segment.revenue_per_product_view_session_usd,

    SAFE_DIVIDE(
      segment.purchase_sessions,
      segment.product_view_sessions
    ) AS conversion_rate,

    SAFE_DIVIDE(
      overall.purchase_sessions,
      overall.product_view_sessions
    ) AS overall_conversion_rate,

    1.96 AS z_value

  FROM
    `product-analytics-hv.product_analytics.funnel_segment_summary`
      AS segment

  CROSS JOIN
    overall
),

wilson_inputs AS (
  SELECT
    *,

    1 + POW(z_value, 2) / product_view_sessions
      AS wilson_denominator,

    conversion_rate
      + POW(z_value, 2) / (2 * product_view_sessions)
      AS wilson_center_numerator,

    z_value * SQRT(
      SAFE_DIVIDE(
        conversion_rate * (1 - conversion_rate),
        product_view_sessions
      )
      + SAFE_DIVIDE(
          POW(z_value, 2),
          4 * POW(product_view_sessions, 2)
        )
    ) AS wilson_margin_numerator

  FROM
    segment_rates
)

SELECT
  segment_type,
  segment_value,

  product_view_sessions,
  cart_sessions,
  checkout_sessions,
  purchase_sessions,

  view_to_cart_conversion_pct,
  cart_to_checkout_conversion_pct,
  checkout_to_purchase_conversion_pct,
  view_to_purchase_conversion_pct,

  ROUND(
    100 * GREATEST(
      0,
      SAFE_DIVIDE(
        wilson_center_numerator - wilson_margin_numerator,
        wilson_denominator
      )
    ),
    2
  ) AS view_to_purchase_ci_lower_pct,

  ROUND(
    100 * LEAST(
      1,
      SAFE_DIVIDE(
        wilson_center_numerator + wilson_margin_numerator,
        wilson_denominator
      )
    ),
    2
  ) AS view_to_purchase_ci_upper_pct,

  ROUND(
    100 * (
      conversion_rate - overall_conversion_rate
    ),
    2
  ) AS difference_vs_overall_percentage_points,

  ROUND(
    100 * (
      SAFE_DIVIDE(
        conversion_rate,
        overall_conversion_rate
      ) - 1
    ),
    2
  ) AS relative_lift_vs_overall_pct,

  purchase_revenue_usd,
  revenue_per_product_view_session_usd

FROM
  wilson_inputs;
