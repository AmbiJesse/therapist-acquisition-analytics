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

Querying `mart_cac_by_channel` and `mart_therapist_growth` together surfaces a channel ranking that flips what raw CAC implies:

| Channel | Signups | Insurance rate | 6m retention |
|---|---|---|---|
| **referral** | **192** | **80%** | **83%** |
| partner | 104 | 73% | 62% |
| organic | 294 | 65% | 60% |
| paid_search | 347 | 50% | 50% |
| social | 63 | 33% | 41% |

**Referral is the highest-quality channel by every mission-relevant metric — and it's not close.**

Paid search drives the most raw signups (347 vs. referral's 192) but only half of those therapists accept insurance and half churn within 6 months. A referral therapist is 60% more likely to accept insurance and 66% more likely to still be active at 6 months. The implication: budget decisions made on signup volume alone systematically underinvest in the channel that best serves Alma's mission.

The mart models make this comparison available on demand — sliced by week, cohort month, or state — rather than requiring a one-off analysis each time the question comes up.

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
