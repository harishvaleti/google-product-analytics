# Google Product Analytics

BigQuery and Python product analytics project using the public Google Analytics 4 e-commerce sample dataset to analyze user journeys, funnel drop-offs, cohort retention, product KPIs, and experiment launch decisions.

## Project Objective

This project analyzes event-level e-commerce behavior to identify where users drop out of the purchase journey, which device and acquisition segments experience the most friction, how retention changes by cohort, and whether a simulated product experiment should launch based on conversion lift and guardrail metrics.

The goal is to demonstrate an end-to-end product analytics workflow similar to the work performed by a data scientist or product analyst supporting a digital product team.

## Dataset

**Source:** Google Analytics 4 obfuscated sample e-commerce dataset in BigQuery public datasets

```sql
`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
```

**Analysis period:** November 1, 2020 through January 31, 2021

The source contains nested GA4 event data, including event parameters, user and session identifiers, device attributes, geography, first-user traffic acquisition fields, e-commerce activity, and purchase revenue.

## Completed Analysis

### Event Exploration

Explored the available event taxonomy, event volume, unique users, and dataset date coverage before developing the analytical tables.

### Sessionization

Created a reusable session-level table by combining `user_pseudo_id` with the nested `ga_session_id` parameter. Each row represents one session and includes:

- Session start and end timestamps
- Session duration and event volume
- Product-view, cart, checkout, and purchase indicators
- Purchase revenue
- Device, operating system, country, first-user source, medium, and campaign context

#### Validation Results

| Metric | Result |
|---|---:|
| Sessions | 360,129 |
| Unique session IDs | 360,129 |
| Unique users | 270,154 |
| Product-view sessions | 77,020 |
| Cart sessions | 15,188 |
| Checkout sessions | 11,106 |
| Purchase sessions | 4,848 |
| Purchase revenue | $362,165 |
| Duplicate session IDs | 0 |
| Sessions with missing keys | 0 |
| Sessions with negative duration | 0 |

### Chronological Funnel Analysis

Built a strict session-level funnel that requires each stage to occur after the preceding stage:

`view_item` → `add_to_cart` → `begin_checkout` → `purchase`

This prevents sessions from being counted as funnel completions when events occurred out of sequence.

| Funnel stage | Sessions | Conversion from previous stage | Conversion from product view | Drop-off to next stage |
|---|---:|---:|---:|---:|
| Product view | 77,020 | 100.00% | 100.00% | 80.31% |
| Add to cart | 15,167 | 19.69% | 19.69% | 64.29% |
| Begin checkout | 5,416 | 35.71% | 7.03% | 47.67% |
| Purchase | 2,834 | 52.33% | 3.68% | — |

#### Funnel Finding

The largest funnel loss occurs between product view and add to cart: 80.31% of product-view sessions do not progress to the cart. Overall, 3.68% of product-view sessions complete the full chronological purchase funnel.

The funnel table passed validation with zero duplicate session IDs, zero out-of-sequence stages, zero checkouts without a qualifying cart event, and zero purchases without a qualifying checkout event.

### Device and Acquisition Segmentation

Segmented the chronological funnel by device category and first-user acquisition source/medium. Segments with fewer than 500 product-view sessions were excluded from the comparison to reduce instability from very small samples.

#### Device Results

| Device | Product-view sessions | View-to-cart conversion | View-to-purchase conversion | 95% CI for purchase conversion |
|---|---:|---:|---:|---:|
| Mobile | 30,501 | 19.90% | 3.84% | 3.63%–4.06% |
| Desktop | 44,819 | 19.58% | 3.57% | 3.40%–3.75% |
| Tablet | 1,700 | 18.88% | 3.59% | 2.80%–4.58% |

The product-view-to-cart rate remains close to 19% across all three device categories. The main funnel friction therefore appears broad rather than isolated to one device type. Mobile conversion is directionally higher than desktop conversion, but the confidence intervals overlap, so the current analysis does not establish a decisive device advantage.

#### First-User Acquisition Findings

| Source / medium | Product-view sessions | View-to-purchase conversion | 95% CI |
|---|---:|---:|---:|
| Direct / none | 17,678 | 3.64% | 3.37%–3.92% |
| Google / organic | 23,663 | 3.11% | 2.90%–3.34% |
| Google / CPC | 3,167 | 2.87% | 2.35%–3.51% |
| Merchandise Store referral | 6,634 | 5.16% | 4.65%–5.71% |

The referral segment has a higher observed conversion rate, but the source name may indicate self-referral or attribution-quality issues. It is treated as a tracking investigation opportunity rather than evidence that referral is the strongest acquisition channel. Obfuscated `(data deleted)` traffic is excluded from business recommendations.

#### Segmentation Validation

- Device segments reconcile exactly to the overall funnel totals.
- Source segments with at least 500 product-view sessions cover 76,919 of 77,020 qualifying sessions.
- Invalid funnel rows: 0
- Invalid conversion rows: 0
- Duplicate segment rows: 0

### Statistical Interpretation

Wilson 95% confidence intervals were calculated for segment-level view-to-purchase conversion rates. Formal two-proportion tests and regression-based inference are planned in Python. Pairwise tests will focus on pre-specified comparisons and account for multiple testing where appropriate. Because users can contribute more than one session, session-level tests will be interpreted as approximations and supplemented with user-aware or clustered modeling.

## Remaining Analyses

- Formal two-proportion tests for selected segment comparisons
- User-aware logistic regression for conversion drivers
- Cohort retention analysis
- Product KPI summary
- Simulated A/B experiment readout
- Guardrail metric evaluation
- Dashboard and visualizations
- One-page product recommendation memo

## Repository Structure

```text
sql/
  00_event_exploration.sql       # Complete
  01_sessionization.sql          # Complete
  02_funnel_analysis.sql         # Complete
  03_cohort_retention.sql        # Planned
  04_kpi_summary.sql             # Planned
  05_experiment_readout.sql      # Planned

notebooks/
  funnel_segment_analysis.ipynb  # Planned
  experiment_readout.ipynb       # Planned

dashboard/
  dashboard_screenshot.png       # Planned

memo/
  product_analytics_memo.md      # Planned
```

## Tools

- BigQuery SQL
- Python
- pandas
- scipy / statsmodels
- Tableau or Looker Studio
- GitHub

## Planned Deliverables

- SQL pipelines for event exploration, sessionization, funnel, cohort, KPI, and experiment analysis
- Python notebooks for segment inference and experiment evaluation, including confidence intervals, two-proportion tests, logistic regression, and guardrail metrics
- Dashboard with a funnel chart, retention heatmap, channel/device conversion analysis, and experiment results
- One-page product memo covering the business question, metric definitions, findings, experiment result, recommendation, and limitations

## Project Status

Sessionization, chronological funnel analysis, device/acquisition segmentation, and segment confidence intervals are complete and validated. Formal segment inference is the next step.