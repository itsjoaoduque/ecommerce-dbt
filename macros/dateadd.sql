{#
    Cross-database macro to subtract N days from a date.
    Usage: {{ date_subtract_days(column, n) }}
#}

{% macro date_subtract_days(column, n) %}
    {{ adapter.dispatch('date_subtract_days', 'ecommerce_master')(column, n) }}
{% endmacro %}

{# DuckDB #}
{% macro duckdb__date_subtract_days(column, n) %}
    {{ column }} - INTERVAL '{{ n }} days'
{% endmacro %}

{# Snowflake #}
{% macro snowflake__date_subtract_days(column, n) %}
    DATEADD(day, -{{ n }}, {{ column }})
{% endmacro %}