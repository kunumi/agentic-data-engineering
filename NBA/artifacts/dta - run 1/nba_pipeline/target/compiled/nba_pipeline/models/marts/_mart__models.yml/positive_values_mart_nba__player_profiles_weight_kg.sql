

select weight_kg
from "nba_dbt"."main"."mart_nba__player_profiles"
where weight_kg is not null
  and weight_kg <= 0

