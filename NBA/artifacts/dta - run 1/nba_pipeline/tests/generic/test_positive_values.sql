{#
    Generic test: fails if the column contains any value <= 0 (NULLs are ignored).
    Used for physical measures that must be strictly positive (height_cm, weight_kg).
#}
{% test positive_values(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} <= 0

{% endtest %}
