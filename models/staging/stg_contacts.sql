with source as (
    select * from {{ source('alma_raw', 'contact_requests') }}
),

renamed as (
    select
        request_id,
        therapist_id,
        session_id,
        cast(request_date as date)       as request_date,
        cast(converted as boolean)       as converted
    from source
)

select * from renamed
