with users as (

    select distinct
        user_id,
        count(*)                over (partition by user_id) as order_count,
        min(purchase_date)      over (partition by user_id) as first_order_date,
        max(purchase_date)      over (partition by user_id) as last_order_date

    from {{ ref('stg_ecommerce') }}

),

deduped as (

    select distinct
        user_id,
        order_count,
        first_order_date,
        last_order_date

    from users

),

final as (

    select
        md5(user_id)        as user_master_id,
        user_id             as user_source_id,
        order_count,
        first_order_date,
        last_order_date,
        current_timestamp   as dbt_updated_at

    from deduped

)

select * from final