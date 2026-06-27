with source as (
    select * from {{ source('alma_raw', 'directory_sessions') }}
),

renamed as (
    select
        session_id,
        therapist_id,
        cast(session_date as date)  as session_date,
        channel,
        cast(page_views as integer) as page_views
    from source
)

select * from renamed
