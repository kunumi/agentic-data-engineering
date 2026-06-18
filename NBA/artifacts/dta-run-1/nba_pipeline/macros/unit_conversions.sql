{#
    Convert an NBA-style height string "ft-in" (e.g. "6-10") into centimeters.
    Empty strings and NULLs return NULL. TRY_CAST is used because the source
    column contains empty strings (see ERR-001) that would break a hard CAST.
#}
{% macro height_ftin_to_cm(col) %}
    case
        when {{ col }} is null or trim({{ col }}) = '' then null
        else round(
            try_cast(split_part({{ col }}, '-', 1) as integer) * 30.48
            + try_cast(split_part({{ col }}, '-', 2) as integer) * 2.54
        , 1)
    end
{% endmacro %}

{#
    Convert a weight string in pounds into kilograms.
    Empty strings and NULLs return NULL (TRY_CAST, see ERR-001).
#}
{% macro lbs_to_kg(col) %}
    case
        when {{ col }} is null or trim({{ col }}) = '' then null
        else round(try_cast({{ col }} as double) * 0.453592, 1)
    end
{% endmacro %}
