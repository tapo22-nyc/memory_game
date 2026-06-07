-- ============================================================
-- FILE: player_career_totals_query.sql
-- PURPOSE: Aggregate total career stats per player per format
--          (Test / ODI / T20) from raw match history rows.
--
-- SOURCE TABLE: cricapi_player_match_history
--   One row = one innings (batting OR bowling) for one player.
--   50s and 100s are computed on the fly from the runs column.
--   Bowling figures are from rows where overs > 0.
--
-- ⚠ IMPORTANT — READ THIS FIRST:
--   These queries only return meaningful numbers if your
--   cricapi_player_match_history table actually has rows for
--   the player. SL/WI players added recently likely have zero
--   rows unless you ran the backfill process.
--
--   Run SECTION 1 first to check whether data even exists
--   before trusting any totals in SECTION 2+.
--
-- TO GET THE DATA IF IT IS MISSING: see bottom of this file.
-- ============================================================


-- ============================================================
-- SECTION 1: DATA AVAILABILITY CHECK
-- Run this first. If every row shows 0 total_innings, the
-- history table has no data for that player and the career
-- totals queries below will return empty / zeros.
-- ============================================================

SELECT
  cpp.player_name,
  cpp.country,
  cpp.player_type,
  COUNT(h.source_match_id)                                         AS total_innings_rows,
  COUNT(DISTINCT CASE WHEN LOWER(h.match_type) = 'test'            THEN h.source_match_id END) AS test_matches,
  COUNT(DISTINCT CASE WHEN LOWER(h.match_type) = 'odi'             THEN h.source_match_id END) AS odi_matches,
  COUNT(DISTINCT CASE WHEN LOWER(h.match_type) IN ('t20','t20i')   THEN h.source_match_id END) AS t20_matches,
  CASE
    WHEN COUNT(h.source_match_id) = 0 THEN 'NO DATA — need to backfill'
    WHEN COUNT(h.source_match_id) < 10 THEN 'PARTIAL DATA — may be incomplete'
    ELSE 'OK'
  END AS data_status
FROM cricket_player_pool cpp
LEFT JOIN cricapi_player_match_history h
       ON LOWER(h.player_name) = LOWER(cpp.player_name)
WHERE cpp.country IN ('SL', 'WI')
  AND cpp.is_active = TRUE
GROUP BY cpp.player_name, cpp.country, cpp.player_type
ORDER BY cpp.country, total_innings_rows DESC, cpp.player_name;


-- ============================================================
-- SECTION 2: BATTING CAREER TOTALS — all SL + WI players
--            across all three formats in one result set
--
-- Columns explained:
--   matches       — distinct matches played (not innings)
--   innings       — number of innings batted
--   runs          — total runs scored
--   balls_faced   — total balls faced
--   batting_avg   — runs per dismissal (standard cricket avg)
--   strike_rate   — runs per 100 balls (averaged across innings)
--   fifties       — innings where 50 ≤ runs < 100
--   hundreds      — innings where runs ≥ 100
--   fours         — total boundary 4s
--   sixes         — total 6s
--   highest_score — single highest innings score
--   not_outs      — innings where player was not dismissed
-- ============================================================

SELECT
  player_name,
  country,
  match_type                                                       AS format,
  COUNT(DISTINCT source_match_id)                                  AS matches,
  COUNT(*)                                                         AS innings,
  SUM(runs)                                                        AS runs,
  SUM(balls)                                                       AS balls_faced,
  ROUND(
    SUM(runs)::numeric
    / NULLIF(SUM(CASE WHEN is_out = TRUE THEN 1 ELSE 0 END), 0),
    2
  )                                                                AS batting_avg,
  ROUND(
    (SUM(runs)::numeric / NULLIF(SUM(balls), 0)) * 100,
    1
  )                                                                AS strike_rate,
  SUM(CASE WHEN runs >= 50 AND runs < 100 THEN 1 ELSE 0 END)       AS fifties,
  SUM(CASE WHEN runs >= 100              THEN 1 ELSE 0 END)         AS hundreds,
  SUM(fours)                                                        AS fours,
  SUM(sixes)                                                        AS sixes,
  MAX(runs)                                                         AS highest_score,
  SUM(CASE WHEN is_out = FALSE THEN 1 ELSE 0 END)                  AS not_outs
FROM cricapi_player_match_history
WHERE balls > 0                          -- only genuine batting innings
  AND player_name IN (
    SELECT player_name FROM cricket_player_pool
    WHERE country IN ('SL', 'WI') AND is_active = TRUE
  )
GROUP BY player_name, country, match_type
ORDER BY player_name, match_type;


-- ============================================================
-- SECTION 3: BOWLING CAREER TOTALS — all SL + WI players
--            across all three formats
--
-- Columns explained:
--   bowling_innings — number of innings where player bowled
--   wickets         — total wickets taken
--   runs_conceded   — total runs given away
--   bowling_avg     — runs conceded per wicket
--   economy         — average economy rate across innings
--   five_wicket_hauls — innings where wickets ≥ 5
--   best_figures    — most wickets in a single innings
-- ============================================================

SELECT
  player_name,
  country,
  match_type                                                       AS format,
  COUNT(DISTINCT source_match_id)                                  AS matches,
  COUNT(*)                                                         AS bowling_innings,
  SUM(wickets)                                                     AS wickets,
  SUM(runs_conceded)                                               AS runs_conceded,
  ROUND(
    SUM(runs_conceded)::numeric / NULLIF(SUM(wickets), 0),
    2
  )                                                                AS bowling_avg,
  ROUND(AVG(NULLIF(economy, 0))::numeric, 2)                       AS avg_economy,
  SUM(CASE WHEN wickets >= 5 THEN 1 ELSE 0 END)                   AS five_wicket_hauls,
  MAX(wickets)                                                      AS best_figures_wickets
FROM cricapi_player_match_history
WHERE overs > 0                          -- only genuine bowling innings
  AND player_name IN (
    SELECT player_name FROM cricket_player_pool
    WHERE country IN ('SL', 'WI') AND is_active = TRUE
  )
GROUP BY player_name, country, match_type
ORDER BY player_name, match_type;


-- ============================================================
-- SECTION 4: SINGLE PLAYER FULL CAREER CARD
-- Change 'Kusal Mendis' to any player name.
-- Returns one row per format with all batting + bowling totals
-- side by side — useful for a player profile card view.
-- ============================================================

SELECT
  match_type                                                        AS format,
  -- Batting
  COUNT(DISTINCT CASE WHEN balls > 0 THEN source_match_id END)      AS bat_matches,
  SUM(CASE WHEN balls > 0 THEN 1 ELSE 0 END)                        AS innings,
  SUM(CASE WHEN balls > 0 THEN runs ELSE 0 END)                     AS runs,
  MAX(CASE WHEN balls > 0 THEN runs END)                             AS highest,
  ROUND(
    SUM(CASE WHEN balls > 0 THEN runs ELSE 0 END)::numeric
    / NULLIF(SUM(CASE WHEN balls > 0 AND is_out THEN 1 ELSE 0 END), 0),
    2
  )                                                                  AS batting_avg,
  ROUND(
    (SUM(CASE WHEN balls > 0 THEN runs ELSE 0 END)::numeric
    / NULLIF(SUM(CASE WHEN balls > 0 THEN balls ELSE 0 END), 0)) * 100,
    1
  )                                                                  AS strike_rate,
  SUM(CASE WHEN balls > 0 AND runs >= 50 AND runs < 100 THEN 1 ELSE 0 END) AS fifties,
  SUM(CASE WHEN balls > 0 AND runs >= 100 THEN 1 ELSE 0 END)         AS hundreds,
  SUM(CASE WHEN balls > 0 THEN fours ELSE 0 END)                     AS fours,
  SUM(CASE WHEN balls > 0 THEN sixes ELSE 0 END)                     AS sixes,
  -- Bowling
  COUNT(DISTINCT CASE WHEN overs > 0 THEN source_match_id END)       AS bowl_matches,
  SUM(CASE WHEN overs > 0 THEN wickets ELSE 0 END)                   AS wickets,
  SUM(CASE WHEN overs > 0 THEN runs_conceded ELSE 0 END)             AS runs_conceded,
  ROUND(
    SUM(CASE WHEN overs > 0 THEN runs_conceded ELSE 0 END)::numeric
    / NULLIF(SUM(CASE WHEN overs > 0 THEN wickets ELSE 0 END), 0),
    2
  )                                                                   AS bowling_avg,
  ROUND(AVG(CASE WHEN overs > 0 THEN economy END)::numeric, 2)       AS avg_economy
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Kusal Mendis')    -- << change this
GROUP BY match_type
ORDER BY match_type;


-- ============================================================
-- SECTION 5: CHECK PRE-AGGREGATED CAREER STATS (CricAPI JSON)
-- The cricapi_player_career_stats table stores career totals
-- pulled directly from CricAPI — it already has 50s, 100s, etc.
-- BUT it is only populated for IPL players (cricapi_player_master),
-- NOT for SL/WI players from cricket_player_pool.
-- Run this to confirm if your SL/WI players have any data here.
-- ============================================================

SELECT
  player_name,
  country,
  batting_t20  AS t20_batting_career_json,
  batting_odi  AS odi_batting_career_json,
  batting_test AS test_batting_career_json,
  bowling_t20  AS t20_bowling_career_json,
  bowling_odi  AS odi_bowling_career_json,
  bowling_test AS test_bowling_career_json,
  updated_at
FROM cricapi_player_career_stats
WHERE player_name IN (
  SELECT player_name FROM cricket_player_pool
  WHERE country IN ('SL', 'WI') AND is_active = TRUE
)
ORDER BY country, player_name;
-- If this returns 0 rows, SL/WI career stats have never been synced.
-- See the guide below on how to fetch them.


-- ============================================================
-- ============================================================
-- HOW TO GET THE MISSING DATA
-- ============================================================
-- ============================================================
--
-- ── OPTION A: CricAPI (recommended — fast, pre-aggregated) ──
--
-- CricAPI's /v1/players_info endpoint returns a stats[] array
-- that already has matches, innings, runs, avg, SR, 50s, 100s,
-- wickets, economy — split by Test / ODI / T20.
-- This is the same source your sync-selected-player-career-stats.js
-- API uses for IPL players.
--
-- STEP 1: Find each SL/WI player's CricAPI player ID.
--         Check cricsheet_player_mapping:
--
--   SELECT player_name, country, cricapi_player_id, cricsheet_player_id, mapping_status
--   FROM cricsheet_player_mapping
--   WHERE player_name IN (
--     SELECT player_name FROM cricket_player_pool WHERE country IN ('SL','WI')
--   );
--
-- STEP 2: For players that have a cricapi_player_id, call:
--   https://api.cricapi.com/v1/players_info?apikey=YOUR_KEY&id=PLAYER_ID
--
--   The response contains:
--   { stats: [ { fn: 'batting', matchtype: 't20', stat: 'runs', value: '2847' }, ... ] }
--
--   Keys you will see in fn='batting': mat, inns, no, runs, hs, avg, bf, sr, 100, 50, 4s, 6s
--   Keys you will see in fn='bowling': mat, inns, balls, runs, wkts, avg, econ, sr, 5w, 10
--
-- STEP 3: Your sync-selected-player-career-stats.js already handles
--         this format. Modify it to also query cricket_player_pool
--         (joined to cricsheet_player_mapping for the cricapi_player_id)
--         instead of only cricapi_player_master.
--
-- Example modified query in that API file:
--   SELECT cpm.cricapi_player_id, cpp.player_name, cpp.country
--   FROM cricket_player_pool cpp
--   JOIN cricsheet_player_mapping cpm
--     ON LOWER(cpm.player_name) = LOWER(cpp.player_name)
--   WHERE cpp.country IN ('SL','WI')
--     AND cpm.cricapi_player_id IS NOT NULL
--
-- ── OPTION B: Cricsheet (most complete, match-by-match) ──
--
-- Cricsheet has ball-by-ball JSON for every international match.
-- Your backfill-player-history-from-cricsheet.js API already
-- processes this format and inserts rows into
-- cricapi_player_match_history.
--
-- Once rows are in cricapi_player_match_history, all the SQL
-- queries in SECTIONS 2–4 above will return real numbers.
--
-- To trigger it for SL/WI players:
--   POST /api/backfill-player-history-from-cricsheet
--   with the player's cricsheet_player_id
--
-- Find the cricsheet IDs with:
--   SELECT player_name, cricsheet_player_id
--   FROM cricsheet_player_mapping
--   WHERE player_name IN (
--     SELECT player_name FROM cricket_player_pool WHERE country IN ('SL','WI')
--   )
--   AND cricsheet_player_id IS NOT NULL;
--
-- ── WHICH ONE TO CHOOSE ──
--
--   CricAPI  → best for career totals (50s, 100s already counted)
--              one API call per player, fast
--              costs API credits
--
--   Cricsheet → best for last-N-games detail (ball-by-ball source)
--               free, no API credits
--               more setup, data computed from raw rows
--
-- ============================================================
