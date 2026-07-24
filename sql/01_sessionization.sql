-- Builds a session-level analytics table from the GA4 event export.
-- Each row represents one user session with engagement, funnel, revenue,
-- device, geography, and acquisition attributes.

CREATE OR REPLACE TABLE
  `product-analytics-hv.product_analytics.sessions` AS

WITH event_base AS (
  SELECT
    event_date,
    event_timestamp,
    event_name,
    user_pseudo_id,

    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,

    device.category AS device_category,
    device.operating_system AS operating_system,
    geo.country AS country,

    COALESCE(traffic_source.source, '(direct)') AS traffic_source,
    COALESCE(traffic_source.medium, '(none)') AS traffic_medium,
    COALESCE(traffic_source.name, '(not set)') AS campaign_name,

    COALESCE(ecommerce.purchase_revenue_in_usd, 0) AS purchase_revenue_usd

  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

session_rollup AS (
  SELECT
    CONCAT(
      user_pseudo_id,
      '-',
      CAST(ga_session_id AS STRING)
    ) AS session_id,

    user_pseudo_id,
    ga_session_id,

    MIN(PARSE_DATE('%Y%m%d', event_date)) AS session_date,
    MIN(event_timestamp) AS session_start_micros,
    MAX(event_timestamp) AS session_end_micros,

    COUNT(*) AS event_count,
    COUNTIF(event_name = 'page_view') AS page_views,

    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS added_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS began_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS added_shipping_info,
    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS added_payment_info,
    MAX(IF(event_name = 'purchase', 1, 0)) AS purchased,

    SUM(
      IF(event_name = 'purchase', purchase_revenue_usd, 0)
    ) AS purchase_revenue_usd,

    ARRAY_AGG(
      STRUCT(
        device_category,
        operating_system,
        country,
        traffic_source,
        traffic_medium,
        campaign_name
      )
      ORDER BY event_timestamp
      LIMIT 1
    )[OFFSET(0)] AS session_context

  FROM
    event_base

  WHERE
    ga_session_id IS NOT NULL

  GROUP BY
    user_pseudo_id,
    ga_session_id
)

SELECT
  session_id,
  user_pseudo_id,
  ga_session_id,
  session_date,

  TIMESTAMP_MICROS(session_start_micros) AS session_start_timestamp,
  TIMESTAMP_MICROS(session_end_micros) AS session_end_timestamp,

  ROUND(
    (session_end_micros - session_start_micros) / 1000000.0,
    2
  ) AS session_duration_seconds,

  event_count,
  page_views,

  viewed_item,
  added_to_cart,
  began_checkout,
  added_shipping_info,
  added_payment_info,
  purchased,

  purchase_revenue_usd,

  session_context.device_category AS device_category,
  session_context.operating_system AS operating_system,
  session_context.country AS country,
  session_context.traffic_source AS traffic_source,
  session_context.traffic_medium AS traffic_medium,
  session_context.campaign_name AS campaign_name

FROM
  session_rollup;
