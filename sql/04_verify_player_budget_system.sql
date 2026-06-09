-- ============================================================
-- FILE: sql/04_verify_player_budget_system.sql
-- PURPOSE: Verification queries to check all 3 layers of the
--          player valuation system after running files 01–03.
--
-- RUN ORDER: run each section independently as needed.
-- ============================================================


-- ============================================================
-- SECTION A: MASTER CAREER STATS (Layer 1)
-- ============================================================

-- A1: Total row count
SELECT COUNT(*) AS total_players
FROM player_career_stats_master;

-- A2: Count by country and source
SELECT country, player_pool_source, COUNT(*) AS players
FROM player_career_stats_master
GROUP BY country, player_pool_source
ORDER BY players DESC;

-- A3: Players with missing role (should be 0 after FILE 1 Step 3)
SELECT player_name, country, player_pool_source
FROM player_career_stats_master
WHERE player_role IS NULL OR player_role = 'unknown'
ORDER BY country, player_name;

-- A4: Role distribution
SELECT player_role, COUNT(*) AS player_count
FROM player_career_stats_master
GROUP BY player_role
ORDER BY player_count DESC;

-- A5: Players with no stats in any format (might indicate sync issue)
SELECT player_name, country, player_role
FROM player_career_stats_master
WHERE t20_bat_runs   = 0
  AND odi_bat_runs   = 0
  AND test_bat_runs  = 0
  AND t20_bowl_wickets  = 0
  AND odi_bowl_wickets  = 0
  AND test_bowl_wickets = 0
ORDER BY country, player_name;


-- ============================================================
-- SECTION B: PLAYER FORMAT SCORES (Layer 2)
-- ============================================================

-- B1: Row count by format (should be 3x master player count)
SELECT format, COUNT(*) AS rows
FROM player_format_scores
GROUP BY format
ORDER BY format;

-- B2: Missing or null scores (indicates calculation issue)
SELECT format, COUNT(*) AS rows_with_null_impact
FROM player_format_scores
WHERE final_impact_score IS NULL
   OR raw_budget_score IS NULL
GROUP BY format;

-- B3: Score distribution by format and role
SELECT
  format,
  role,
  COUNT(*)                                                                              AS players,
  MIN(final_impact_score)                                                               AS impact_min,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY final_impact_score)::numeric, 1)  AS impact_median,
  MAX(final_impact_score)                                                               AS impact_max,
  MIN(raw_budget_score)                                                                 AS budget_min,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY raw_budget_score)::numeric, 1)    AS budget_median,
  MAX(raw_budget_score)                                                                 AS budget_max
FROM player_format_scores
GROUP BY format, role
ORDER BY format, role;

-- B4: Top 15 players by impact score for T20
SELECT player_name, country, role, final_impact_score, raw_budget_score
FROM player_format_scores
WHERE format = 't20'
ORDER BY final_impact_score DESC
LIMIT 15;

-- B5: Players with score = 0 in all dimensions (data gaps)
SELECT player_name, country, role, format,
  final_impact_score, raw_budget_score
FROM player_format_scores
WHERE final_impact_score = 0 AND raw_budget_score = 0
ORDER BY format, country, player_name;


-- ============================================================
-- SECTION C: MATCH PLAYER BUDGETS (Layer 3)
-- ============================================================

-- C1: Summary per match — player counts and tier distribution
SELECT
  mpb.fantasy_match_id,
  fm.match_title,
  fm.match_format,
  fm.status,
  COUNT(*)                                            AS total_players,
  COUNT(*) FILTER (WHERE mpb.budget_tier='premium')  AS premium,
  COUNT(*) FILTER (WHERE mpb.budget_tier='mid')      AS mid,
  COUNT(*) FILTER (WHERE mpb.budget_tier='value')    AS value_count,
  MIN(mpb.final_player_budget)                       AS cheapest,
  MAX(mpb.final_player_budget)                       AS most_expensive,
  SUM(mpb.final_player_budget)                       AS total_pool_value
FROM match_player_budgets mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
GROUP BY mpb.fantasy_match_id, fm.match_title, fm.match_format, fm.status
ORDER BY mpb.fantasy_match_id;

-- C2: Matches that do NOT have exactly 4 premium players
--     (indicates a side with < 2 players — review that match manually)
SELECT
  fantasy_match_id,
  COUNT(*) FILTER (WHERE budget_tier='premium') AS premium_count
FROM match_player_budgets
GROUP BY fantasy_match_id
HAVING COUNT(*) FILTER (WHERE budget_tier='premium') != 4
ORDER BY fantasy_match_id;

-- C3: Matches that do NOT have exactly 8 mid players
SELECT
  fantasy_match_id,
  COUNT(*) FILTER (WHERE budget_tier='mid') AS mid_count
FROM match_player_budgets
GROUP BY fantasy_match_id
HAVING COUNT(*) FILTER (WHERE budget_tier='mid') != 8
ORDER BY fantasy_match_id;

-- C4: Matches that do NOT have exactly 12 value players
SELECT
  fantasy_match_id,
  COUNT(*) FILTER (WHERE budget_tier='value') AS value_count
FROM match_player_budgets
GROUP BY fantasy_match_id
HAVING COUNT(*) FILTER (WHERE budget_tier='value') != 12
ORDER BY fantasy_match_id;

-- C5: Any player budget below $50,000 (should return 0 rows)
SELECT fantasy_match_id, player_name, budget_tier, final_player_budget
FROM match_player_budgets
WHERE final_player_budget < 50000
ORDER BY fantasy_match_id, final_player_budget;

-- C6: Any player budget above $250,000 (should return 0 rows)
SELECT fantasy_match_id, player_name, budget_tier, final_player_budget
FROM match_player_budgets
WHERE final_player_budget > 250000
ORDER BY fantasy_match_id, final_player_budget DESC;

-- C7: Any budget NOT rounded to nearest $5,000 (should return 0 rows)
SELECT fantasy_match_id, player_name, budget_tier, final_player_budget
FROM match_player_budgets
WHERE MOD(final_player_budget, 5000) != 0
ORDER BY fantasy_match_id;

-- C8: Budget values in wrong tier range
--     Premium: $200K–$250K, Mid: $120K–$190K, Value: $50K–$120K
SELECT fantasy_match_id, player_name, budget_tier, final_player_budget
FROM match_player_budgets
WHERE (budget_tier='premium' AND (final_player_budget < 200000 OR final_player_budget > 250000))
   OR (budget_tier='mid'     AND (final_player_budget < 120000 OR final_player_budget > 190000))
   OR (budget_tier='value'   AND (final_player_budget < 50000  OR final_player_budget > 120000))
ORDER BY fantasy_match_id, budget_tier;

-- C9: Fantasy matches that have NO budget rows at all
--     (means FILE 3 Step 2 was not run or no active players)
SELECT fm.id, fm.match_title, fm.status
FROM fantasy_matches fm
WHERE fm.status = 'open'
  AND NOT EXISTS (
    SELECT 1 FROM match_player_budgets mpb
    WHERE mpb.fantasy_match_id = fm.id
  );

-- C10: Matches where total active players != 24
--      (24 is expected — investigate if different)
SELECT
  fmp.fantasy_match_id,
  fm.match_title,
  COUNT(*) FILTER (WHERE COALESCE(fmp.is_active, TRUE) = TRUE) AS active_players
FROM fantasy_match_players fmp
JOIN fantasy_matches fm ON fm.id = fmp.fantasy_match_id
WHERE fm.status = 'open'
GROUP BY fmp.fantasy_match_id, fm.match_title
HAVING COUNT(*) FILTER (WHERE COALESCE(fmp.is_active, TRUE) = TRUE) != 24
ORDER BY fmp.fantasy_match_id;

-- C11: Top 10 most expensive players in a match
--      Replace fantasy_match_id = 1 with your actual match ID
SELECT player_name, team_name, role, budget_tier, final_player_budget, final_impact_score
FROM match_player_budgets
WHERE fantasy_match_id = 1                           -- ← change to your match ID
ORDER BY final_player_budget DESC
LIMIT 10;

-- C12: 10 cheapest players in a match
SELECT player_name, team_name, role, budget_tier, final_player_budget, final_impact_score
FROM match_player_budgets
WHERE fantasy_match_id = 1                           -- ← change to your match ID
ORDER BY final_player_budget ASC
LIMIT 10;

-- C13: Sanity check — can a user actually build a valid team?
--      Shows minimum possible 11-player team cost using cheapest players
--      Ideally should be well under $1,000,000
SELECT
  mpb.fantasy_match_id,
  fm.match_title,
  SUM(mpb.final_player_budget) AS min_11_player_cost
FROM (
  SELECT fantasy_match_id, final_player_budget,
    ROW_NUMBER() OVER (PARTITION BY fantasy_match_id ORDER BY final_player_budget ASC) AS rn
  FROM match_player_budgets
) mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
WHERE rn <= 11
GROUP BY mpb.fantasy_match_id, fm.match_title
ORDER BY mpb.fantasy_match_id;

-- C14: Players in match_player_budgets but NOT in player_format_scores
--      (means they defaulted to score=50 — check their names in master stats)
SELECT
  mpb.fantasy_match_id,
  mpb.player_name,
  mpb.team_name,
  mpb.role,
  mpb.raw_budget_score
FROM match_player_budgets mpb
WHERE mpb.raw_budget_score = 50.0       -- 50 is the COALESCE fallback default
ORDER BY mpb.fantasy_match_id, mpb.player_name;
