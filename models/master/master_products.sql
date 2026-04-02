with products as (

    select
        product_id,
        category,
        price_usd,
        discount_pct,
        final_price_usd,
        row_number() over (
            partition by product_id
            order by purchase_date desc
        ) as rn

    from {{ ref('stg_ecommerce') }}

),

deduped as (

    select
        product_id,
        category,
        price_usd,
        discount_pct,
        final_price_usd

    from products
    where rn = 1

),

normalized as (

    select
        product_id,
        lower(trim(category))   as category,
        price_usd,
        discount_pct,
        final_price_usd

    from deduped

),

final as (

    select
        md5(product_id)         as product_master_id,
        product_id              as product_source_id,
        category,
        price_usd,
        discount_pct,
        final_price_usd,
        current_timestamp       as dbt_updated_at

    from normalized

)

select * from final