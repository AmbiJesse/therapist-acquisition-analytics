with source as (
    select * from {{ source('alma_raw', 'therapist_signups') }}
),

renamed as (
    select
        therapist_id,
        cast(signup_date as date)        as signup_date,
        referral_source,
        state,
        cast(insurance_accepted as boolean) as insurance_accepted,
        cast(active_6m as boolean)          as active_6m
    from source
)

select * from renamed
