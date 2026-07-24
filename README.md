# Google Product Analytics

BigQuery SQL and Python product analytics project using the public Google Analytics 4 e-commerce sample dataset to analyze event-level user journeys, conversion drop-offs, segment performance, and product experimentation opportunities.

The current completed phase covers sessionization, chronological funnel analysis, device and acquisition segmentation, confidence intervals, hypothesis testing, multiple-testing correction, and user-clustered logistic regression. Cohort retention, KPI reporting, experiment evaluation, dashboard development, and the product memo are the next planned phases.

## Project Objective

This project is designed to demonstrate an end-to-end product analytics workflow similar to the work performed by a data scientist or product analyst supporting a digital product team.

The analysis addresses four initial questions:

1. Where does the purchase journey lose the most users?
2. Is the largest funnel problem concentrated on a particular device?
3. Do meaningful conversion differences exist across acquisition segments?
4. Do any apparent channel advantages indicate measurement problems rather than product performance?

## Dataset

**Source:** Google Analytics 4 obfuscated sample e-commerce dataset in BigQuery public datasets

```sql
`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
```

**Analysis period:** November 1, 2020 through January 31, 2021

The source contains nested GA4 event data, including event parameters, user and session identifiers, device attributes, geography, first-user acquisition fields, e-commerce activity, and purchase revenue.

## Completed Analysis

### 1. Event Exploration

Explored the available event taxonomy, event volume, unique users, and dataset date coverage before developing the analytical tables.

### 2. Sessionization

Created a reusable session-level BigQuery table by combining `user_pseudo_id` with the nested `ga_session_id` parameter. Each row represents one session and includes:

- Session start and end timestamps
- Session duration and event volume
- Product-view, cart, checkout, and purchase indicators
- Purchase revenue
- Device, operating system, country, first-user source, medium, and campaign context

#### Sessionization Validation

| Metric | Result |
|---|---:|
| Sessions | 360,129 |
| Unique session IDs | 360,129 |
| Unique users | 270,154 |
| Product-view sessions | 77,020 |
| Sessions containing any cart event | 15,188 |
| Sessions containing any checkout event | 11,106 |
| Sessions containing any purchase event | 4,848 |
| Purchase revenue | $362,165 |
| Duplicate session IDs | 0 |
| Sessions with missing keys | 0 |
| Sessions with negative duration | 0 |

The event-presence counts above describe whether a session contained each event anywhere in the session. The stricter chronological funnel below requires every stage to occur after the preceding stage, so its later-stage counts are intentionally lower.

### 3. Chronological Funnel Analysis

Built a strict session-level funnel that requires each event to occur after the preceding stage:

```text
Product view → Add to cart → Begin checkout → Purchase
```

This prevents sessions from being counted as funnel completions when events occur out of sequence.

| Funnel stage | Sessions | Conversion from previous stage | Conversion from product view | Drop-off to next stage |
|---|---:|---:|---:|---:|
| Product view | 77,020 | 100.00% | 100.00% | 80.31% |
| Add to cart | 15,167 | 19.69% | 19.69% | 64.29% |
| Begin checkout | 5,416 | 35.71% | 7.03% | 47.67% |
| Purchase | 2,834 | 52.33% | 3.68% | — |

#### Primary Funnel Finding

The largest loss occurs between product view and add to cart: **80.31%** of product-view sessions do not progress to cart. Overall, **3.68%** of product-view sessions complete the full chronological purchase funnel.

The funnel table passed validation with:

- Zero duplicate session IDs
- Zero invalid cart sequences
- Zero checkouts without a qualifying prior cart event
- Zero purchases without a qualifying prior checkout event

### 4. Device and Acquisition Segmentation

Segmented the chronological funnel by device category and first-user source/medium. Acquisition segments with fewer than 500 product-view sessions were excluded from the summary to reduce instability from very small samples.

#### Device Results

| Device | Product-view sessions | View-to-cart conversion | View-to-purchase conversion | 95% Wilson CI |
|---|---:|---:|---:|---:|
| Mobile | 30,501 | 19.90% | 3.84% | 3.63%–4.06% |
| Desktop | 44,819 | 19.58% | 3.57% | 3.40%–3.75% |
| Tablet | 1,700 | 18.88% | 3.59% | 2.80%–4.58% |

View-to-cart conversion remains close to 19%–20% across all device categories. The dominant funnel friction therefore appears to be **cross-device**, rather than a mobile-only problem.

#### First-User Acquisition Results

| Source / medium | Product-view sessions | View-to-purchase conversion | 95% Wilson CI |
|---|---:|---:|---:|
| Direct / none | 17,678 | 3.64% | 3.37%–3.92% |
| Google / organic | 23,663 | 3.11% | 2.90%–3.34% |
| Google / CPC | 3,167 | 2.87% | 2.35%–3.51% |
| Merchandise Store referral | 6,634 | 5.16% | 4.65%–5.71% |

The Merchandise Store referral segment has a higher observed conversion rate, but its referring domain appears related to the analyzed property. The result is therefore treated as a potential **self-referral or attribution-quality issue**, not automatically as evidence of superior acquisition performance. Obfuscated `(data deleted)` traffic is retained in the underlying data but excluded from business recommendations.

#### Segmentation Validation

- Device segments reconcile exactly to the overall chronological funnel totals.
- Source segments with at least 500 product-view sessions cover 76,919 of 77,020 qualifying sessions.
- Invalid funnel rows: 0
- Invalid conversion rows: 0
- Duplicate segment rows: 0

### 5. Statistical Inference in Python

The executed notebook `notebooks/funnel_segment_analysis.ipynb` extends the SQL analysis with:

- 95% Wilson confidence intervals
- Predefined two-proportion z-tests
- Absolute percentage-point differences and relative lift
- Benjamini–Hochberg false discovery rate correction
- Session-level logistic regression
- Standard errors clustered by `user_pseudo_id`
- Odds ratios and confidence intervals
- An embedded adjusted-odds-ratio chart
- Product recommendations and analytical limitations

#### Two-Proportion Tests

| Comparison | Difference | Raw p-value | BH-adjusted p-value | Conclusion |
|---|---:|---:|---:|---|
| Mobile vs. desktop | +0.2704 pp | 0.0531 | 0.0796 | Not statistically significant |
| Google organic vs. Google CPC | +0.2370 pp | 0.4687 | 0.4687 | Not statistically significant |
| Merchandise referral vs. other identified traffic | +1.9048 pp | <0.0001 | <0.0001 | Statistically significant; attribution concern |

Mobile conversion is directionally higher than desktop conversion, but the evidence is insufficient to claim a statistically reliable device advantage after multiple-testing correction. Google organic and Google CPC also do not differ significantly from each other.

#### User-Clustered Logistic Regression

The model estimates purchase odds while controlling simultaneously for device and acquisition-source group. Desktop and direct traffic are the reference categories.

| Comparison | Adjusted odds ratio | 95% CI | p-value | Interpretation |
|---|---:|---:|---:|---|
| Mobile vs. desktop | 1.085 | 0.997–1.180 | 0.0586 | Not statistically significant |
| Tablet vs. desktop | 0.982 | 0.738–1.308 | 0.9026 | No evidence of a difference |
| Google organic vs. direct | 0.850 | 0.764–0.946 | 0.0029 | Lower adjusted purchase odds |
| Google CPC vs. direct | 0.784 | 0.627–0.981 | 0.0337 | Lower adjusted purchase odds |
| Merchandise referral vs. direct | 1.439 | 1.256–1.648 | <0.0001 | Higher odds; attribution concern |
| Other identified vs. direct | 0.857 | 0.767–0.959 | 0.0068 | Lower adjusted purchase odds |

The z-test and regression findings are complementary: organic and CPC do not differ significantly from each other, while each has lower adjusted purchase odds than direct traffic after controlling for device.

## Current Product Recommendation

Prioritize investigation and experimentation at the **product-view-to-cart transition across all device categories**.

The recommendation is supported by three findings:

1. The view-to-cart transition loses 80.31% of qualifying sessions.
2. View-to-cart conversion remains near 19%–20% across desktop, mobile, and tablet.
3. Neither the z-test nor the user-clustered regression establishes a reliable mobile-versus-desktop difference.

Potential experiment areas include:

- Increasing add-to-cart visibility
- Clarifying product value and product-detail information
- Improving pricing, availability, and shipping messaging
- Reducing interaction steps between product view and cart
- Auditing referral and campaign attribution before reallocating acquisition spend

## Limitations

- The public GA4 sample is obfuscated and covers only three months.
- The analysis is observational and does not establish causal effects.
- Traffic-source fields represent first-user acquisition and may not describe the source responsible for each individual session.
- Some acquisition values are deleted or grouped into generic categories.
- The Merchandise Store referral result may reflect self-referral or attribution configuration.
- Users may contribute multiple sessions. Regression standard errors are clustered by user, while the simpler two-proportion tests remain session-level comparisons.
- The current analysis evaluates selected predefined comparisons; additional exploratory tests would require further multiplicity control.

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
  funnel_segment_analysis.ipynb  # Complete and executed
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
- NumPy
- statsmodels
- Matplotlib
- Tableau or Looker Studio
- GitHub

## Next Phases

1. Build `03_cohort_retention.sql` and a dashboard-ready retention matrix.
2. Build `04_kpi_summary.sql` for product, conversion, revenue, device, and acquisition KPIs.
3. Create a clearly documented simulated experiment around the product-view-to-cart bottleneck.
4. Evaluate primary and guardrail metrics in `experiment_readout.ipynb`.
5. Build a dashboard containing the funnel, retention heatmap, segment performance, KPI trends, and experiment results.
6. Write a one-page product memo covering the business question, metric definitions, findings, experiment result, recommendation, and limitations.

## Project Status

**Completed and validated:** event exploration, sessionization, chronological funnel analysis, device and acquisition segmentation, Wilson confidence intervals, predefined z-tests, Benjamini–Hochberg correction, user-clustered logistic regression, statistical interpretation, and the current product recommendation.

**Planned:** cohort retention, KPI summary, simulated experiment analysis, guardrail evaluation, dashboard development, and the final product memo.
