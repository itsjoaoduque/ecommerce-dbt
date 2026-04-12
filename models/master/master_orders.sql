{{
    config(
        materialized = 'incremental',
        unique_key = 'order_master_id',
        on_schema_change = 'sync_all_columns'
    )
}}

with orders as (

    select
        user_id,
        product_id,
        purchase_date,
        price_usd,
        discount_pct,
        final_price_usd,
        payment_method,
        row_number() over (
            partition by user_id, product_id, purchase_date
            order by purchase_date
        ) as rn

    from {{ ref('stg_ecommerce') }}

    {% if is_incremental() %}
        where purchase_date >= (
            select {{ date_subtract_days('max(purchase_date)', 3) }}
            from {{ this }}
        )
    {% endif %}

),

deduped as (

    select
        user_id,
        product_id,
        purchase_date,
        price_usd,
        discount_pct,
        final_price_usd,
        payment_method

    from orders
    where rn = 1

),

with_keys as (

    select
        {{ generate_surrogate_key(['user_id', 'product_id', 'cast(purchase_date as varchar)']) }}
                                    as order_master_id,
        {{ generate_surrogate_key(['user_id']) }}    as user_master_id,
        {{ generate_surrogate_key(['product_id']) }} as product_master_id,
        purchase_date,
        price_usd,
        discount_pct,
        final_price_usd,
        round(price_usd * 0.75, 2)          as price_gbp,
        round(final_price_usd * 0.75, 2)    as final_price_gbp,
        payment_method

    from deduped

),

final as (

    select
        order_master_id,
        user_master_id,
        product_master_id,
        purchase_date,
        payment_method,
        price_usd,
        final_price_usd,
        price_gbp,
        final_price_gbp,
        discount_pct,
        current_timestamp           as record_updated_at

    from with_keys

)

select * from final