-- mart_funnel_conversion.sql
-- Stage-by-stage conversion through Alma's therapist acquisition funnel.
-- Granularity: channel x week.
-- Funnel: directory session → contact request → booked (converted) session.

with

sessions as (

    select
        channel,
        date_trunc('week', session_date) as session_week,
        count(*)                          as total_sessions

    from {{ ref('stg_sessions') }}
    group by 1, 2

),

contacts as (

    select
        s.channel,
        date_trunc('week', c.request_date) as request_week,
        count(*)                             as contact_requests,
        sum(case when c.converted then 1 else 0 end) as booked_sessions

    from {{ ref('stg_contacts') }} c
    inner join {{ ref('stg_sessions') }} s
        on c.session_id = s.session_id
    group by 1, 2

),

joined as (

    select
        ses.channel,
        ses.session_week,
        ses.total_sessions,
        coalesce(con.contact_requests, 0) as contact_requests,
        coalesce(con.booked_sessions,  0) as booked_sessions,

        -- Stage 1 → 2: session to contact request
        round(
            coalesce(con.contact_requests, 0)::numeric
                / nullif(ses.total_sessions, 0),
            4
        ) as session_to_contact_rate,

        -- Stage 2 → 3: contact request to booked session
        round(
            coalesce(con.booked_sessions, 0)::numeric
                / nullif(con.contact_requests, 0),
            4
        ) as contact_to_booked_rate,

        -- Full funnel: session to booked (end-to-end conversion)
        round(
            coalesce(con.booked_sessions, 0)::numeric
                / nullif(ses.total_sessions, 0),
            4
        ) as full_funnel_rate

    from sessions ses
    left join contacts con
        on  ses.channel      = con.channel
        and ses.session_week = con.request_week

)

select * from joined
order by channel, session_week
