{# 
    Cross-database macro to parse a date string into a DATE type.
    Usage: {{ parse_date(column, format) }}

    Format tokens follow strptime/DuckDB convention (e.g. '%d-%m-%Y').
    The macro converts them automatically for Snowflake.
#}

{% macro parse_date(column, format) %}
    {{ adapter.dispatch('parse_date', 'ecommerce_master')(column, format) }}
{% endmacro %}

{# DuckDB: uses strptime natively #}
{% macro duckdb__parse_date(column, format) %}
    strptime({{ column }}, '{{ format }}')::date
{% endmacro %}

{# Snowflake: convert strptime tokens to Snowflake TO_DATE format #}
{% macro snowflake__parse_date(column, format) %}
    {%- set snowflake_format = format
        | replace('%d', 'DD')
        | replace('%m', 'MM')
        | replace('%Y', 'YYYY')
        | replace('%y', 'YY')
        | replace('%H', 'HH24')
        | replace('%M', 'MI')
        | replace('%S', 'SS')
    -%}
    TO_DATE({{ column }}, '{{ snowflake_format }}')
{% endmacro %}
