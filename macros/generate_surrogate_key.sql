{#
    Generates a deterministic surrogate key by hashing one or more column values.

    Usage:
        {{ generate_surrogate_key(['col1', 'col2', 'col3']) }}

    How it works:
        1. Each column is cast to VARCHAR and coalesced to '' to handle NULLs
           (a NULL in any column would otherwise make the whole hash NULL)
        2. The values are joined with the separator '|' to prevent collisions
           (e.g. ('ab', 'c') vs ('a', 'bc') would produce the same hash without it)
        3. The concatenated string is hashed with MD5

    To change the hashing strategy (e.g. SHA-256), update only this macro —
    all models that call it will be updated automatically.
#}

{% macro generate_surrogate_key(field_list) %}
    {{ adapter.dispatch('generate_surrogate_key', 'ecommerce_master')(field_list) }}
{% endmacro %}

{% macro default__generate_surrogate_key(field_list) %}
    {%- set fields = [] -%}
    {%- for field in field_list -%}
        {%- do fields.append("coalesce(cast(" ~ field ~ " as varchar), '')") -%}
    {%- endfor -%}
    md5({{ fields | join(" || '|' || ") }})
{% endmacro %}
