with source as (
    select * from {{ source('alma_raw', 'marketing_spend') }}
),

renamed as (
    select
        spend_id,
        channel,
        cast(spend_date as date)          as spend_date,
        cast(spend_usd as numeric(12, 2)) as spend_usd,
        campaign
    from source
)

select * from renamed
