-- Asserts that each product_source_id has exactly one active (current) record
-- in the snapshot at any point in time (dbt_valid_to IS NULL = current).
-- If this returns rows, multiple "current" versions exist for the same product.

select
    product_source_id,
    count(*) as current_record_count
from {{ ref('products_snapshot') }}
where dbt_valid_to is null
group by product_source_id
having count(*) > 1
