
    
    



select is_official_nba_matchup
from "nba_dbt"."main"."mart_nba__games"
where is_official_nba_matchup is null


