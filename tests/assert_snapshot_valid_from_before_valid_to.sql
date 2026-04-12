-- Asserts that dbt_valid_from is strictly earlier than dbt_valid_to
-- for all closed (non-current) snapshot records.
-- If this returns rows, a record's validity window is inverted or zero-length.

select *
from {{ ref('products_snapshot') }}
where dbt_valid_to is not null
  and dbt_valid_from >= dbt_valid_to
