# Cleaning Roadmap — Banco NBA (connection_id 87e6b067)

Roadmap prescritivo de qualidade de dados para o Agente de Engenharia de Dados.
Gerado em 2026-06-17 a partir da exploração interativa. Ordenado por severidade.

---

## CLEAN-001: Tabela `team_info_common` está completamente vazia ⚠️ (staging+teste warn criados; precisa de fonte externa — intervenção manual)
- **Table:** team_info_common
- **Severity:** critical
- **Problem:** É a ÚNICA tabela com informações de conferência (`team_conference`), divisão (`team_division`), ranking (`conf_rank`/`div_rank`) e standings por temporada (w, l, pct). Está com 0 linhas — torna impossível qualquer análise por conferência/divisão.
- **Evidence:**
  ```sql
  SELECT COUNT(*) AS n_rows FROM team_info_common;
  ```
- **Result:** 0 linhas.
- **Recommended action:** Repovoar a tabela a partir da fonte original (NBA stats / standings por temporada), ou remover do schema se não houver fonte. Sem isso, perguntas de conferência/divisão/classificação ficam sem resposta.

## CLEAN-002: Ausência de box score por jogador (estatística por jogador/partida) ⚠️ (sem tabela-fonte; impossível em dbt até ingestão de player_game_stats — intervenção manual)
- **Table:** game (e ausência de tabela dedicada)
- **Severity:** critical
- **Problem:** Todas as estatísticas de partida (pts, ast, reb, stl, blk, min, fg etc.) existem apenas **por time** (sufixos `_home`/`_away`) na tabela `game`. Não há nenhuma tabela ligando jogador → estatística de cada jogo. `play_by_play` registra eventos, sem totais agregados e sem minutos. Isso inviabiliza: pontos/assistências/rebotes por jogador, PPG, líderes estatísticos, consistência, partidas com >X minutos, rebotes por posição.
- **Evidence:**
  ```sql
  SELECT DISTINCT table_name FROM information_schema.columns
  WHERE LOWER(column_name) IN ('pts','ast','reb') OR LOWER(column_name) LIKE 'ast%';
  -- retorna apenas: game (nível time) e team_info_common (vazia)
  ```
- **Result:** Nenhuma tabela com stats por jogador. Só `game` (time) e `team_info_common` (vazia).
- **Recommended action:** Ingerir uma tabela de box score por jogador/partida (player_game_stats: game_id, player_id, team_id, min, pts, ast, reb, stl, blk, fg, ...). É o maior bloqueio analítico do banco.

## CLEAN-003: Valores inconsistentes em `game.season_type` ("All Star" vs "All-Star") ✅ (stg_nba__games + mart_nba__games; accepted_values)
- **Table:** game
- **Severity:** warning
- **Problem:** O mesmo tipo de jogo aparece com duas grafias diferentes, fragmentando agregações por tipo.
- **Evidence:**
  ```sql
  SELECT season_type, COUNT(*) n FROM game GROUP BY 1 ORDER BY n DESC;
  ```
- **Result:** Regular Season 60192, Playoffs 3842, Pre Season 1536, **All Star 65**, **All-Star 63** (mesma categoria, 2 grafias).
- **Recommended action:** Padronizar `season_type` para um valor canônico (ex.: 'All-Star'). `UPDATE game SET season_type='All-Star' WHERE season_type='All Star'`.

## CLEAN-004: Times de exibição/defuntos misturados na tabela `game` ✅ (int_nba__games_classified + flags is_official_nba_matchup)
- **Table:** game
- **Severity:** warning
- **Problem:** A tabela contém 122 entidades distintas de time, mas só 30 são franquias atuais. As outras 65 incluem times internacionais de exibição (ex.: "Unicaja Malaga"), All-Star teams e franquias extintas. Sem filtrar, distorcem métricas (ex.: aproveitamento dos "últimos N jogos" deu 1.0 para times com pouquíssimos jogos).
- **Evidence:**
  ```sql
  WITH ids AS (SELECT team_id_home tid FROM game UNION SELECT team_id_away FROM game)
  SELECT COUNT(*) times_distintos,
         COUNT(*) FILTER (WHERE tid NOT IN (SELECT CAST(id AS VARCHAR) FROM team)) fora_das_30
  FROM ids;
  ```
- **Result:** 122 times distintos; 65 fora das 30 franquias atuais.
- **Recommended action:** Adicionar flag/coluna que classifique o time (NBA atual / extinto / exibição / all-star), ou normalizar via dimensão de times. Para análises NBA, padronizar filtro por `team_id IN (SELECT id FROM team)` e/ou `season_type` apropriado.

## CLEAN-005: `height` e `weight` armazenados como texto (não numérico) com strings vazias ✅ (stg_nba__player_info height_cm/weight_kg via TRY_CAST)
- **Table:** common_player_info
- **Severity:** warning
- **Problem:** `height` é texto no formato "6-10" (pés-polegadas) e `weight` é texto em libras; ambos contêm strings vazias `''`. Isso quebra CAST direto (exige TRY_CAST) e impede cálculos sem parsing.
- **Evidence:**
  ```sql
  SELECT COUNT(*) total,
         COUNT(*) FILTER (WHERE height IS NULL OR height='') alt_vazia,
         COUNT(*) FILTER (WHERE weight IS NULL OR weight='') peso_vazio
  FROM common_player_info;
  ```
- **Result:** total 3632; altura vazia 74; peso vazio 77.
- **Recommended action:** Criar colunas numéricas derivadas: `height_cm` (parse "ft-in" → cm) e `weight_kg` (lbs → kg), com NULL para vazios. Manter original ou descontinuar o texto.

## CLEAN-006: Data de nascimento sentinela inválida (1900-01-01) ✅ (1900-01-01 → NULL; teste de domínio)
- **Table:** common_player_info
- **Severity:** warning
- **Problem:** Registro com `birthdate` = 1900-01-01, claramente um placeholder (ex.: Bill Laimbeer, que nasceu em 1957). Distorce rankings por idade ("mais velhos").
- **Evidence:**
  ```sql
  SELECT display_first_last, CAST(birthdate AS DATE) FROM common_player_info
  WHERE CAST(birthdate AS DATE) = DATE '1900-01-01';
  ```
- **Result:** 1 linha (Bill Laimbeer, 1900-01-01).
- **Recommended action:** Substituir por NULL ou corrigir com a data real. Adicionar checagem de domínio (birthdate > 1900-01-01) na ingestão.

## CLEAN-007: Valores ausentes em `position` (e altura/peso) em common_player_info ✅ ('' → NULL; position_group 'Unknown'; accepted_values)
- **Table:** common_player_info
- **Severity:** warning
- **Problem:** Campos-chave para análise por posição vêm vazios/NULL em parte dos registros.
- **Evidence:**
  ```sql
  SELECT COUNT(*) FILTER (WHERE position IS NULL OR position='') pos_vazia FROM common_player_info;
  ```
- **Result:** 45 jogadores sem posição (de 3632).
- **Recommended action:** Imputar a partir de fonte externa ou marcar explicitamente como 'Unknown'. Padronizar vazio → NULL.

## CLEAN-008: Lacuna de cobertura entre `player` e `common_player_info` ✅ (int_nba__player_coverage + flag has_detailed_info; relationships FK)
- **Table:** player / common_player_info
- **Severity:** info
- **Problem:** `player` tem 4815 jogadores (lista canônica), mas `common_player_info` (única com posição/altura/peso) cobre só 3632 — ~1183 jogadores sem ficha detalhada.
- **Evidence:**
  ```sql
  SELECT (SELECT COUNT(*) FROM player) n_player, (SELECT COUNT(*) FROM common_player_info) n_cpi;
  ```
- **Result:** player 4815; common_player_info 3632 (~75% de cobertura).
- **Recommended action:** Completar `common_player_info` para os jogadores faltantes ou documentar a lacuna. Garantir FK person_id → player.id.

## CLEAN-009: Nome de franquia inconsistente ao longo do histórico ✅ (mart_nba__teams: nome canônico + nomes históricos)
- **Table:** game
- **Severity:** info
- **Problem:** O mesmo `team_id` aparece com nomes diferentes em épocas distintas (relocações: ex. "Minneapolis Lakers" = L.A. Lakers). Agregar por `team_name` fragmenta a franquia; agregar por `team_id` mistura nomes históricos.
- **Evidence:**
  ```sql
  SELECT team_id_home, COUNT(DISTINCT team_name_home) nomes FROM game
  GROUP BY 1 HAVING COUNT(DISTINCT team_name_home) > 1 ORDER BY nomes DESC LIMIT 5;
  ```
- **Result:** Vários team_id com múltiplos nomes históricos.
- **Recommended action:** Criar dimensão de time com `team_id` + nome atual canônico (join com `team`) e tabela de nomes históricos. Padronizar relatórios pelo nome atual.

## CLEAN-010: `team_details` sem data de contratação do técnico ⚠️ (placeholder head_coach_hire_date criado; precisa de fonte — intervenção manual)
- **Table:** team_details
- **Severity:** info
- **Problem:** Há `headcoach` (nome), mas nenhuma coluna de data de contratação/início, impossibilitando análises temporais de comissão técnica.
- **Evidence:**
  ```sql
  SELECT table_name, column_name FROM information_schema.columns
  WHERE LOWER(column_name) LIKE '%coach%' OR LOWER(column_name) LIKE '%hire%';
  -- só team_details.headcoach
  ```
- **Result:** Apenas `team_details.headcoach`; sem coluna de data.
- **Recommended action:** Adicionar `headcoach_hire_date` (e idealmente histórico de técnicos) se houver fonte.

===CLEANING_ROADMAP===
