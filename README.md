# Google Product Analytics

BigQuery and Python product analytics project using the public Google Analytics 4 e-commerce sample dataset to analyze user journeys, funnel drop-offs, cohort retention, product KPIs, and experiment launch decisions.

## Project Objective

This project analyzes event-level e-commerce behavior to identify where users drop out of the purchase journey, how retention changes by cohort, and whether a simulated product experiment should launch based on conversion lift and guardrail metrics.

The goal is to demonstrate an end-to-end product analytics workflow similar to the work performed by a data scientist or product analyst supporting a digital product team.

## Dataset

**Source:** Google Analytics 4 obfuscated sample e-commerce dataset in BigQuery public datasets

```sql
`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
```

**Analysis period:** November 1, 2020 through January 31, 2021

The source contains nested GA4 event data, including event parameters, user and session identifiers, device attributes, geography, traffic acquisition fields, e-commerce activity, and purchase revenue.

## Completed Analysis

### Event Exploration

Explored the available event taxonomy, event volume, unique users, and dataset date coverage before developing the analytical tables.

### Sessionization

Created a reusable session-level table by combining `user_pseudo_id` with the nested `ga_session_id` parameter. Each row represents one session and includes:

- Session start and end timestamps
- Session duration and event volume
- Product-view, cart, checkout, and purchase indicators
- Purchase revenue
- Device, operating system, country, traffic source, medium, and campaign context

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

#### Initial Finding

The largest funnel loss occurs between product view and add to cart: 80.31% of product-view sessions do not progress to the cart. Overall, 3.68% of product-view sessions complete the full chronological purchase funnel.

The funnel table passed validation with zero duplicate session IDs, zero out-of-sequence stages, zero checkouts without a qualifying cart event, and zero purchases without a qualifying checkout event.

## Remaining Analyses

- Cohort retention analysis
- Product KPI summary
- Simulated A/B experiment readout
- Conversion confidence intervals
- Logistic regression and segment analysis
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
- Python notebook for experiment testing, confidence intervals, logistic regression, segmentation, and guardrail metrics
- Dashboard with a funnel chart, retention heatmap, channel/device conversion analysis, and experiment results
- One-page product memo covering the business question, metric definitions, findings, experiment result, recommendation, and limitations

## Project Status

Sessionization and chronological funnel analysis are complete and validated. Cohort retention analysis is next.
