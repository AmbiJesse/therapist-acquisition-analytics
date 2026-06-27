-- mart_therapist_growth.sql
-- Cohort view of therapist retention by acquisition channel.
-- Each row = one signup cohort month x channel.
-- Key output: retained_6m_rate by channel reveals which channels
-- drive durable supply growth vs. high-churn signups.

with

cohorts as (

    select
        therapist_id,
        referral_source                              as channel,
        date_trunc('month', signup_date)            as cohort_month,
        insurance_accepted,
        active_6m

    from {{ ref('stg_signups') }}

),

aggregated as (

    select
        cohort_month,
        channel,
        count(*)                                                as cohort_size,

        sum(case when insurance_accepted then 1 else 0 end)    as insurance_accepting,
        sum(case when active_6m          then 1 else 0 end)    as retained_6m,

        -- Insurance acceptance rate for the cohort
        round(
            sum(case when insurance_accepted then 1 else 0 end)::numeric
                / nullif(count(*), 0),
            4
        ) as insurance_acceptance_rate,

        -- 6-month retention rate for the cohort
        round(
            sum(case when active_6m then 1 else 0 end)::numeric
                / nullif(count(*), 0),
            4
        ) as retention_rate_6m,

        -- Among retained therapists, what % accept insurance?
        -- High value = channel delivers quality supply long-term
        round(
            sum(case when active_6m and insurance_accepted then 1 else 0 end)::numeric
                / nullif(sum(case when active_6m then 1 else 0 end), 0),
            4
        ) as retained_insurance_rate

    from cohorts
    group by 1, 2

)

select * from aggregated
order by cohort_month, channel
