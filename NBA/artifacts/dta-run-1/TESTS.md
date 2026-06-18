# Tests

Test results and coverage. Last full run: 2026-06-17 — `dbt build` → **PASS=61, WARN=1, ERROR=0, TOTAL=62**.

## Summary by layer
| Layer | Models | Tests | Result |
|-------|--------|-------|--------|
| Sources | 6 declared | 6 (not_null/unique on team.id, player.id, cpi.person_id) | ✅ |
| Staging | 6 | not_null, unique, relationships, accepted_values, positive_values | ✅ |
| Intermediate | 3 (ephemeral) | not_null, unique on keys | ✅ |
| Marts | 3 | not_null, unique, accepted_values, positive_values | ✅ |
| Singular | — | 3 (birthdate domain, marts_not_empty, team_info_common_not_empty=WARN) | ✅ / 1 WARN |

## Custom tests
- `positive_values` (generic, tests/generic/test_positive_values.sql): fails on value <= 0 (NULL ignored). Used on height_cm, weight_kg.
- `assert_player_info_birthdate_domain` (singular): no birthdate <= 1900-01-01 (CLEAN-006 guard).
- `assert_marts_not_empty` (singular): every mart has rows.
- `assert_team_info_common_not_empty` (singular, severity=warn): flags CLEAN-001 emptiness without failing build.

## The 1 expected WARN
- `assert_team_info_common_not_empty` — team_info_common source has 0 rows (CLEAN-001). Intentional warn; resolves automatically when source is repopulated.

## Verified business outcomes (post-build query)
- CLEAN-003: season_type ∈ {Regular Season, Playoffs, Pre Season, All-Star} — single All-Star value (72 distinct games; the 56 duplicate game_ids deduped were all All-Star).
- CLEAN-004: is_official_nba_matchup → 63,703 true / 1,939 false (exhibition/defunct excluded).
- CLEAN-005: height_cm/weight_kg numeric (e.g. 208.3 cm / 108.9 kg).
- CLEAN-006: 0 sentinel birthdates remain.
- CLEAN-007: position_group fully populated; 1,228 'Unknown'.
- CLEAN-008: coverage 3,632 detailed / 1,183 missing (of 4,815).
- CLEAN-009: franchises carry historical name counts (e.g. Wizards=5, Kings=5).
