

select height_cm
from "nba_dbt"."main"."mart_nba__player_profiles"
where height_cm is not null
  and height_cm <= 0

