with users as (

    select distinct
        user_id,
        count(*)                over (partition by user_id) as order_count,
        min(purchase_date)      over (partition by user_id) as first_order_date,
        max(purchase_date)      over (partition by user_id) as last_order_date

    from {{ ref('stg_ecommerce') }}

),

final as (

    select
        {{ generate_surrogate_key(['user_id']) }}   as user_master_id,
        user_id             as user_source_id,
        order_count,
        first_order_date,
        last_order_date,
        current_timestamp   as record_updated_at

    from users

)

select * from final