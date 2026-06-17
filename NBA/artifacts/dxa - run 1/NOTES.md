# Notes

Metadados do banco: schema, relações, regras de negócio, limitações.

## Conexão / Setup (IMPORTANTE)
- O `connection_id` fixo nas instruções (`5ee606d7`) **NÃO existe** neste ambiente.
- O processador inicia sem conexões registradas (`GET /connections` => vazio). É preciso
  registrar via `POST /connections` com `{"type","path"}`. O `connection_id` é determinístico por arquivo.
- Bancos disponíveis (`GET /databases` e `/connections/files`):
  - `nba.sqlite` (/data/databases/nba.sqlite) => connection_id **87e6b067**
  - `crime_database.db` => c907483f
  - `dtsulv5.sqlite` (~10GB) => 7e459ffb
  - `mimic4_demo.db` => 67c9a274
  - `quikr_car.csv` => d4ead505 (type=csv)
- Para perguntas sobre "times"/"teams" → banco **NBA** (connection_id 87e6b067).

## Banco NBA (87e6b067)
- Tabelas: game, game_summary, other_stats, officials, inactive_players, game_info,
  line_score, play_by_play, player, team, common_player_info, team_details,
  team_history, draft_combine_stats, draft_history, team_info_common.
- **team**: id (BIGINT, ex 1610612737), full_name, abbreviation, nickname, city, state, year_founded (FLOAT).
  - 30 times (franquias NBA atuais). `full_name` = nome completo; `city` = cidade/região.
  - Gotcha: `city` às vezes é região, não cidade literal (ex.: "Golden State", "Indiana", "Utah", "Minnesota").
  - LA aparece 2x (Clippers e Lakers) com city "Los Angeles".
- **player**: id, full_name, first_name, last_name, is_active. 4815 linhas. Lista canônica de jogadores, mas SEM posição/altura.
- **common_player_info**: 3632 linhas. Tem position, height ("6-10" = pés-polegadas), weight, birthdate, team_*, draft_* etc.
  - person_id = FK para player.id (display_first_last = nome).
  - Gotcha: 45 posição vazia/NULL, 74 altura vazia/NULL. Cobre só ~75% dos 4815 da tabela player.
  - Para "nome+posição+altura" use common_player_info (não dá pra obter da player).
  - Regra de negócio (confirmada pelo usuário 2026-06-17): "Pivô"=Center e INCLUI híbridos (Forward-Center, Center-Forward) → `position LIKE '%Center%'`. Traduções: Armador=Guard, Ala=Forward, Pivô=Center.
- **game**: 55+ colunas (stats _home/_away). game_date é TIMESTAMP. game_id VARCHAR. Colunas team_id/abbreviation/name _home e _away, pts_home/away, wl_home/away, season_id, season_type, matchup_*.
  - **LIMITE TEMPORAL: dados vão de 1946-11-01 até 2023-06-12.** NÃO há jogos após jun/2023 (ex.: jan/2025 retorna 0). Snapshot histórico encerrado na temporada 2022-23.
- **team_info_common**: TABELA VAZIA (0 linhas). É a ÚNICA com colunas team_conference/team_division/conf_rank → portanto NÃO há dados de conferência/divisão utilizáveis no banco. Para perguntas de "conferência Leste/Oeste" não há fonte.
- **team_details**: team_id, abbreviation, nickname, yearfounded, city, arena, arenacapacity, owner, generalmanager, headcoach, dleagueaffiliation, redes sociais. (sem conferência; headcoach = nome do técnico, SEM data de contratação)
- **LIMITAÇÃO CRÍTICA — sem box score por jogador**: pts/ast/reb/min/stl/blk etc. só existem POR TIME na tabela `game` (sufixos _home/_away) e em team_info_common (vazia). NÃO há estatística por jogador por partida. play_by_play é eventual (eventos), sem totais agregados e sem minutos. Logo, NÃO dá pra responder: pontos/assistências/rebotes/minutos por jogador, PPG por jogador, partidas com >X min, rebotes por posição. Tudo isso exigiria uma tabela de box score que não existe.
- **game.season_id**: VARCHAR tipo "22021" (prefixo: 1=pré-temporada, 2=temporada regular, 4=playoffs; sufixo=ano). season_type também disponível.
- Vitórias/derrotas: wl_home / wl_away = 'W'/'L'. Agrupar por team_id_home/away (franquia). ANY_VALUE(team_name) traz UM nome histórico da franquia (ex.: Lakers aparece como "Minneapolis Lakers").
- **common_player_info.birthdate**: TIMESTAMP. NÃO comparar com '' (erro de conversão); filtrar só IS NOT NULL. Gotcha: há 1 registro sentinela '1900-01-01' (Bill Laimbeer) — data inválida/placeholder. Demais válidas começam em 1905.
