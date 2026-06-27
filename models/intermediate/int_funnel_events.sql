-- Joins sessions to their contact requests (left join preserves
-- sessions that never converted). Used by mart_funnel_conversion.

with sessions as (
    select * from {{ ref('stg_sessions') }}
),

contacts as (
    select * from {{ ref('stg_contacts') }}
),

joined as (
    select
        s.session_id,
        s.therapist_id,
        s.session_date,
        s.channel,
        s.page_views,
        c.request_id,
        c.request_date,
        c.converted,
        case when c.request_id is not null then true else false end as has_contact_request
    from sessions s
    left join contacts c on s.session_id = c.session_id
)

select * from joined
