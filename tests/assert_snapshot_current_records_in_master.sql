-- Asserts that every active snapshot record (dbt_valid_to IS NULL)
-- has a matching record in master_products.
-- If this returns rows, the snapshot has "ghost" current records with no
-- corresponding source — likely caused by hard deletes not being handled.

select s.*
from {{ ref('products_snapshot') }} s
left join {{ ref('master_products') }} p
    on s.product_source_id = p.product_source_id
where s.dbt_valid_to is null
  and p.product_source_id is null
