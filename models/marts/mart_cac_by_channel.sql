-- mart_cac_by_channel.sql
-- Cost per therapist acquired, by channel and week.
-- Joins marketing spend to signups on channel + signup week.
-- Also surfaces insurance acceptance rate so CAC can be evaluated
-- on quality (insurance-accepting signups) not just raw volume.

with

spend as (

    select
        channel,
        date_trunc('week', spend_date)   as spend_week,
        sum(spend_usd)                   as total_spend_usd

    from {{ ref('stg_spend') }}
    group by 1, 2

),

signups as (

    select
        referral_source                              as channel,
        date_trunc('week', signup_date)             as signup_week,
        count(*)                                     as therapists_acquired,

        -- Quality signal: how many of this week's signups accepted insurance?
        sum(case when insurance_accepted then 1 else 0 end)
                                                     as insurance_accepting_signups,

        -- Retention signal: still active at 6 months
        sum(case when active_6m then 1 else 0 end)  as retained_6m_signups

    from {{ ref('stg_signups') }}
    group by 1, 2

),

joined as (

    select
        s.channel,
        s.signup_week,
        sp.total_spend_usd,
        s.therapists_acquired,
        s.insurance_accepting_signups,
        s.retained_6m_signups,

        -- Standard CAC: total spend ÷ all signups
        round(
            sp.total_spend_usd / nullif(s.therapists_acquired, 0),
            2
        )                                                       as cac_all,

        -- Quality-adjusted CAC: spend ÷ insurance-accepting signups only
        -- This is the metric that matters for Alma's mission
        round(
            sp.total_spend_usd / nullif(s.insurance_accepting_signups, 0),
            2
        )                                                       as cac_insurance_accepting,

        -- Retention-adjusted CAC: spend ÷ therapists still active at 6m
        -- Exposes the true cost of durable growth vs. churn-prone signups
        round(
            sp.total_spend_usd / nullif(s.retained_6m_signups, 0),
            2
        )                                                       as cac_retained_6m,

        -- Insurance acceptance rate for the cohort
        round(
            s.insurance_accepting_signups::numeric
                / nullif(s.therapists_acquired, 0),
            4
        )                                                       as insurance_acceptance_rate,

        -- 6-month retention rate for the cohort
        round(
            s.retained_6m_signups::numeric
                / nullif(s.therapists_acquired, 0),
            4
        )                                                       as retention_rate_6m

    from signups s
    left join spend sp
        on  s.channel     = sp.channel
        and s.signup_week = sp.spend_week

)

select * from joined
order by channel, signup_week
