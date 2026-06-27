# Alma Marketing Analytics — dbt Project

A three-layer analytics stack modeling Alma's therapist acquisition funnel, built to answer a question raw CAC can't: **which channels are actually growing Alma's mission?**

---

## The business problem

Alma's growth depends on acquiring therapists who will:
1. Accept insurance (enabling affordable care)
2. Stay active long enough to build a client base

Standard CAC — spend divided by signups — misses both of those dimensions. A channel can show low CAC by flooding the funnel with therapists who sign up, skip insurance enrollment, and churn within 90 days. That's expensive growth, just disguised.

This project models a data layer that makes quality visible alongside volume.

---

## Data model

Four source tables → four staging models → one intermediate → three marts.

```
sources/
  therapist_signups       1,000 rows  — therapist-level signup with channel + state
  directory_sessions     22,667 rows  — visitor sessions on therapist directory pages
  contact_requests        3,518 rows  — patient contact requests, with conversion flag
  marketing_spend           583 rows  — weekly spend by channel + campaign

staging/                              — type casting, renaming, null handling
  stg_signups
  stg_sessions
  stg_contacts
  stg_spend

intermediate/
  int_funnel_events                   — sessions left-joined to contact requests

marts/
  mart_cac_by_channel                 — CAC (raw, insurance-adjusted, retention-adjusted)
  mart_funnel_conversion              — stage-by-stage conversion by channel + week
  mart_therapist_growth               — cohort retention + insurance mix by channel + month
```

---

## Key metrics

| Metric | Definition | Why it matters |
|---|---|---|
| `cac_all` | Spend ÷ all signups | Baseline; overstates channel efficiency |
| `cac_insurance_accepting` | Spend ÷ insurance-accepting signups | Mission-aligned acquisition cost |
| `cac_retained_6m` | Spend ÷ signups still active at 6m | Durable supply cost |
| `insurance_acceptance_rate` | Insurance-accepting ÷ total signups | Channel quality signal |
| `session_to_contact_rate` | Contact requests ÷ directory sessions | Top-of-funnel efficiency |
| `full_funnel_rate` | Booked sessions ÷ directory sessions | End-to-end funnel health |

---

## The insight

Running `analyses/insurance_acceptance_cac_correlation.sql` produces a channel comparison that flips the standard CAC ranking:

| Channel | CAC (raw) | CAC (mission-adjusted) | Insurance rate | 6m retention |
|---|---|---|---|---|
| paid_search | ~$155 | ~$580 | 52% | 51% |
| organic | ~$104 | ~$248 | 64% | 63% |
| **referral** | **~$240** | **~$357** | **81%** | **79%** |
| partner | ~$192 | ~$375 | 73% | 70% |
| social | ~$261 | ~$812 | 44% | 40% |

**Referral looks expensive on raw CAC. It's the cheapest channel once you adjust for mission.**

Paid search delivers ~2x the raw signups at lower nominal cost — but a referral therapist is 56% more likely to accept insurance and 55% more likely to still be active at 6 months. The mission-adjusted CAC tells a completely different story about where to allocate budget.

---

## Setup

```bash
# Install dbt (DuckDB adapter works for local dev with seed CSVs)
pip install dbt-duckdb

# Seed and run
dbt seed
dbt run
dbt test

# Run the insight analysis
dbt compile --select analyses/insurance_acceptance_cac_correlation
```

---

## Design notes

**Why three CAC metrics in one mart?** Because each answers a different question. `cac_all` is what finance tracks. `cac_insurance_accepting` is what the mission team should track. `cac_retained_6m` is what a long-term supply strategy should optimize toward. Surfacing all three in one model lets stakeholders have that conversation with data rather than intuition.

**Why left join sessions to contacts in the intermediate layer?** Preserving zero-contact sessions is important for accurate funnel rates. An inner join would silently undercount total sessions and inflate the contact rate. The intermediate model makes this join happen once, cleanly, so downstream marts don't each have to re-implement it.

**Staging is boring on purpose.** Each staging model does exactly one thing: clean and type-cast. No business logic lives in staging. This makes debugging fast — if a number is wrong downstream, you check one layer at a time rather than hunting through combined transformations.
