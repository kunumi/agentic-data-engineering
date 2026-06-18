-- Singular test (CLEAN-006): no birthdate may be the 1900-01-01 sentinel or earlier.
-- After cleaning, sentinel values become NULL; this guards against regressions.
select player_id, birthdate
from "nba_dbt"."main"."stg_nba__player_info"
where birthdate is not null
  and birthdate <= date '1900-01-01'