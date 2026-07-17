# Google Product Analytics

BigQuery and Python product analytics project using the public Google Analytics e-commerce sample dataset to analyze user journeys, funnel drop-offs, cohort retention, product KPIs, and experiment launch decisions.

## Project Objective

This project analyzes event-level e-commerce user behavior to identify where users drop off, how retention changes by cohort, and whether a simulated product experiment should launch based on conversion lift and guardrail metrics.

The goal is to show a practical product analytics workflow similar to what a data scientist or product analyst would build for a digital product team.

## Dataset

**Source:** Google Analytics Sample E-commerce dataset in BigQuery public datasets

Expected table pattern:

```sql
`bigquery-public-data.google_analytics_sample.ga_sessions_*`
```

## Key Analyses

- Event and session exploration
- User journey and funnel analysis
- Cohort retention analysis
- Product KPI summary
- Simulated A/B experiment readout
- Guardrail metric review
- Python statistical testing and launch recommendation

## Repository Structure

```text
sql/
  00_event_exploration.sql
  01_sessionization.sql
  02_funnel_analysis.sql
  03_cohort_retention.sql
  04_kpi_summary.sql
  05_experiment_readout.sql

notebooks/
  experiment_readout.ipynb

dashboard/
  dashboard_screenshot.png

memo/
  product_analytics_memo.md
```

## Tools

- BigQuery SQL
- Python
- pandas
- scipy / statsmodels
- Tableau or Looker Studio
- GitHub

## Planned Deliverables

- SQL pipeline files for event exploration, sessionization, funnel, cohort, KPI, and experiment analysis
- Python notebook for statistical experiment evaluation
- Dashboard screenshot showing product analytics metrics
- One-page product memo with business recommendation

## Project Status

In progress.
