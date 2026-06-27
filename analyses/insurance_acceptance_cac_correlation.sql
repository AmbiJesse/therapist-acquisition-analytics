-- analyses/insurance_acceptance_cac_correlation.sql
--
-- The core insight this project is built to surface:
--
-- Channels with higher CAC (paid_search) often look expensive on a
-- per-signup basis. But when you adjust for insurance acceptance rate
-- and 6-month retention, the cost per *durable, mission-aligned*
-- therapist looks very different.
--
-- Referral channels tend to:
--   - Accept insurance at higher rates (>80% vs. ~52% for paid search)
--   - Retain at higher rates at 6 months (>79% vs. ~51%)
--
-- This means referral's effective CAC per retained, insurance-accepting
-- therapist can be LOWER than paid search despite similar or higher
-- nominal CAC — the opposite of what raw CAC implies.
--
-- This query produces the full-year channel summary for executive review.

with

spend_totals as (

    select
        channel,
        sum(spend_usd) as total_spend_usd

    from {{ ref('stg_spend') }}
    group by 1

),

signup_totals as (

    select
        referral_source                                        as channel,
        count(*)                                               as total_signups,
        sum(case when insurance_accepted then 1 else 0 end)   as insurance_accepting,
        sum(case when active_6m          then 1 else 0 end)   as retained_6m,
        sum(case when active_6m
                  and insurance_accepted then 1 else 0 end)   as retained_and_insurance

    from {{ ref('stg_signups') }}
    group by 1

),

final as (

    select
        s.channel,
        sp.total_spend_usd,
        s.total_signups,
        s.insurance_accepting,
        s.retained_6m,
        s.retained_and_insurance,

        -- Standard CAC (what most teams report)
        round(sp.total_spend_usd / nullif(s.total_signups, 0), 0)
                                                    as cac_raw,

        -- Quality-adjusted CAC (spend per insurance-accepting signup)
        round(sp.total_spend_usd / nullif(s.insurance_accepting, 0), 0)
                                                    as cac_insurance_adjusted,

        -- Mission-adjusted CAC (spend per retained, insurance-accepting therapist)
        -- This is the number Alma's growth team should optimize toward
        round(sp.total_spend_usd / nullif(s.retained_and_insurance, 0), 0)
                                                    as cac_mission_adjusted,

        round(s.insurance_accepting::numeric / nullif(s.total_signups, 0), 4)
                                                    as insurance_acceptance_rate,
        round(s.retained_6m::numeric         / nullif(s.total_signups, 0), 4)
                                                    as retention_rate_6m,

        -- CAC inflation factor: how much worse does raw CAC look vs. mission CAC?
        -- High = channel looks cheap up front but churns/doesn't accept insurance
        round(
            (sp.total_spend_usd / nullif(s.retained_and_insurance, 0))
                / nullif(sp.total_spend_usd / nullif(s.total_signups, 0), 0),
            2
        )                                           as cac_inflation_factor

    from signup_totals s
    left join spend_totals sp on s.channel = sp.channel

)

select * from final
order by cac_mission_adjusted asc   -- rank by what actually matters
