{% snapshot products_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_source_id',
        strategy='check',
        check_cols=['price_usd', 'discount_pct', 'category'],
        invalidate_hard_deletes=True
    )
}}

select
    product_master_id,
    product_source_id,
    category,
    price_usd,
    discount_pct,
    final_price_usd,
    record_updated_at

from {{ ref('master_products') }}

{% endsnapshot %}