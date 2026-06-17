

select height_cm
from "nba_dbt"."main"."stg_nba__player_info"
where height_cm is not null
  and height_cm <= 0

