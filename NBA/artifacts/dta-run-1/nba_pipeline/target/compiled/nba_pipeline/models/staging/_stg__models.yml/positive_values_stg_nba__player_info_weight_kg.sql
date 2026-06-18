

select weight_kg
from "nba_dbt"."main"."stg_nba__player_info"
where weight_kg is not null
  and weight_kg <= 0

