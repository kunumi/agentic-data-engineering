# SQL Recipes

Receitas de SQL validadas neste banco. O agente registra automaticamente.

## RCP-001: Listar nome e cidade de todos os times
- Contexto: tabela `team` (NBA, connection_id 87e6b067). Colunas full_name, city.
- Query:
  ```sql
  SELECT full_name, city FROM [TEAM_TABLE] ORDER BY full_name
  ```
- Testada em: team (2026-06-17) → 30 linhas.

## RCP-002: Listar nome, posição e altura dos jogadores
- Contexto: `common_player_info` (NBA, 87e6b067). nome=display_first_last, posicao=position, altura=height ("pés-polegadas", ex 6-10).
- Query:
  ```sql
  SELECT display_first_last AS nome, position AS posicao, height AS altura
  FROM [CPI_TABLE]
  WHERE position IS NOT NULL AND position <> ''
  ORDER BY display_first_last
  ```
- Testada em: common_player_info (2026-06-17) → 3587 linhas (com posição preenchida).
- Gotcha: posição/altura NÃO existem na tabela `player` (4815 linhas). Só em common_player_info (3632 linhas).

## RCP-003: Converter altura "pés-polegadas" para metros e filtrar
- Contexto: `common_player_info.height` é texto tipo "7-2". Conversão: (pés*12 + pol)*0.0254 m.
- Query:
  ```sql
  WITH h AS (
    SELECT display_first_last AS nome, position AS posicao, height AS altura_ft,
           (CAST(SPLIT_PART(height,'-',1) AS INT)*12 + CAST(SPLIT_PART(height,'-',2) AS INT)) * 0.0254 AS altura_m
    FROM [CPI_TABLE]
    WHERE height IS NOT NULL AND height LIKE '%-%'
  )
  SELECT nome, posicao, altura_ft, ROUND(altura_m,3) AS altura_m
  FROM h WHERE altura_m > [LIMITE_M] ORDER BY altura_m DESC, nome
  ```
- Testada em: common_player_info (2026-06-17) → 986 jogadores acima de 2,05 m.
- Combina com: RCP-002.
- Nota: 2,05 m ≈ 80,7 pol → inclui 6-9 (2,057 m) e acima.

## RCP-004: Altura média e peso médio dos jogadores
- Contexto: common_player_info. weight em libras (texto), height "pés-pol". Usar TRY_CAST (há vazios). 1 lb=0.453592 kg.
- Query:
  ```sql
  SELECT
    ROUND(AVG((TRY_CAST(SPLIT_PART(height,'-',1) AS INT)*12 + TRY_CAST(SPLIT_PART(height,'-',2) AS INT))*0.0254),3) AS altura_media_m,
    ROUND(AVG(TRY_CAST(weight AS DOUBLE)*0.453592),1) AS peso_medio_kg,
    ROUND(AVG(TRY_CAST(weight AS DOUBLE)),1) AS peso_medio_lbs
  FROM [CPI_TABLE]
  ```
- Testada em: common_player_info (2026-06-17) → 1.983 m / 95.8 kg (211.2 lbs); n=3558 altura, 3555 peso.
- Combina com: RCP-003. Ver ERR-001 (use TRY_CAST).

## RCP-005: Jogadores por posição (Pivô/Ala/Armador)
- Contexto: common_player_info.position em INGLÊS. Pivô=Center, Ala=Forward, Armador=Guard.
  - Valores: Guard(1416), Forward(1306), Center(497), Guard-Forward(134), Forward-Center(112), Center-Forward(68), Forward-Guard(54), ''(45).
  - "Pivô" inclui híbridos → usar `position LIKE '%Center%'` (677). Só puro = `position = 'Center'` (497).
- Query:
  ```sql
  SELECT display_first_last AS nome, position AS posicao, height AS altura
  FROM [CPI_TABLE] WHERE position LIKE '%Center%' ORDER BY display_first_last
  ```
- Testada em: common_player_info (2026-06-17) → 677 (Pivô c/ híbridos).

## RCP-006: Vitórias/derrotas por franquia (casa + visitante)
- Contexto: tabela `game`, wl_home/wl_away = 'W'/'L'. Agrupar por team_id (franquia).
- Query:
  ```sql
  WITH g AS (
    SELECT team_id_home AS tid, team_name_home AS nome, wl_home AS wl FROM [GAME]
    UNION ALL
    SELECT team_id_away, team_name_away, wl_away FROM [GAME]
  )
  SELECT ANY_VALUE(nome) AS time,
         COUNT(*) FILTER (WHERE wl='W') AS vitorias,
         COUNT(*) FILTER (WHERE wl='L') AS derrotas
  FROM g GROUP BY tid ORDER BY vitorias DESC
  ```
- Para "só visitante": `COUNT(*) FILTER (WHERE wl_away='W') ... GROUP BY team_id_away`.
- Testada em: game (2026-06-17).

## RCP-007: Maior goleada (diferença de pontos) entre times
- Contexto: tabela `game`, pts_home/pts_away.
- Query:
  ```sql
  SELECT CAST(game_date AS DATE) AS data, season_id, team_name_home, pts_home,
         team_name_away, pts_away, ABS(pts_home-pts_away) AS diferenca
  FROM [GAME] WHERE pts_home IS NOT NULL AND pts_away IS NOT NULL
  ORDER BY diferenca DESC LIMIT [N]
  ```
- Testada em: game (2026-06-17) → maior all-time: Memphis 152 x 79 OKC (2021-12-02), dif 73.
- Nota: filtrar por season_id para limitar a uma temporada específica.

## RCP-008: Maior sequência de vitórias consecutivas por time (gaps & islands)
- Contexto: tabela `game`. Combinar home+away por franquia, ordenar por data, ilhas de wl='W'.
- Query:
  ```sql
  WITH res AS (
    SELECT team_id_home tid, team_name_home nome, game_date, wl_home wl FROM [GAME] WHERE season_id='[SID]'
    UNION ALL SELECT team_id_away, team_name_away, game_date, wl_away FROM [GAME] WHERE season_id='[SID]'),
  seq AS (SELECT tid, nome, wl,
    ROW_NUMBER() OVER (PARTITION BY tid ORDER BY game_date)
    - ROW_NUMBER() OVER (PARTITION BY tid, wl ORDER BY game_date) grp FROM res)
  SELECT ANY_VALUE(nome) time, MAX(cnt) maior_seq FROM
    (SELECT tid, grp, COUNT(*) cnt FROM seq WHERE wl='W' GROUP BY tid, grp) GROUP BY tid ORDER BY maior_seq DESC
  ```
- Testada em: game season 22022 (2022-23) → Milwaukee 16. Troque wl='W'→sinal de delta p/ sequências de melhora (Q9).
- Combina com: RCP-006.

## RCP-009: Acumulado / saldo / aproveitamento por time (window)
- Contexto: tabela `game`. Padrão "explodir" home+away por franquia e aplicar window.
- Padrões testados em game (2026-06-17):
  - Acumulado de pontos: `SUM(pts) OVER (PARTITION BY tid ORDER BY game_date)`.
  - Saldo médio (Q11): `AVG(pf-pa)` com res(tid, pf=pts próprios, pa=pts adversário). Top 2022-23: BOS +6.52.
  - Aproveitamento últimos N: `ROW_NUMBER() OVER (PARTITION BY tid ORDER BY game_date DESC)`, filtrar rn<=N. **Filtrar tid IN (SELECT id FROM team) e season_type='Regular Season'** p/ excluir times de exibição (Unicaja, Waterloo etc.) com poucos jogos.
  - Confrontos entre pares (Q6): `LEAST/GREATEST(team_id_home,team_id_away)` + JOIN team. Top: Celtics x Knicks 515.
- Combina com: RCP-006, RCP-008.
