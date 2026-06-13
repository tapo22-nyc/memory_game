-- ============================================================
-- FILE: sql/15_fix_ind_afg_player_name_mapping.sql
-- PURPOSE: Diagnose and confirm the fix for the wrong player
--          names appearing in the IND vs AFG 1st ODI (match 84).
--
-- THE BUG:
--   api/get-user-team.js and api/get-fantasy-results.js both do:
--     JOIN ipl_player_master pm ON pm.id = futp.player_id
--   But match 84 players come from cricket_player_pool
--   (player_source = 'cricket'), NOT ipl_player_master.
--   Because the numeric IDs happen to exist in ipl_player_master
--   too, you get IPL player names shown against cricket scores.
--
--   api/get-fantasy-match.js (the pick screen) is CORRECT — it
--   uses a dual LEFT JOIN on both tables driven by player_source.
--   The two read-back APIs were never updated to match.
--
-- THE FIX:
--   Two JS files need to be updated (see comments at the bottom).
--   This SQL file lets you verify the problem, confirm your
--   player IDs are correct, and check everything after the fix.
--
-- RUN ORDER (top to bottom in Neon SQL editor):
--   STEP 1 — Confirm match 84 player_source is 'cricket'
--   STEP 2 — Show the wrong names (what users see right now)
--   STEP 3 — Show the correct names (what they should see)
--   STEP 4 — Spot any cricapi_player_mapping mismatches
--   STEP 5 — Confirm fantasy_player_match_stats has real scores
--   STEP 6 — Post-fix verification (run after JS deploy)
-- ============================================================


-- ============================================================
-- STEP 1: CONFIRM ALL MATCH 84 PLAYERS USE player_source='cricket'
-- ============================================================
-- Every row should show player_source = 'cricket'.
-- If any row shows 'ipl' or NULL, stop here and investigate —
-- that player was linked to the wrong pool table.
-- Expected result: 28 rows, all player_source = 'cricket'
-- ============================================================

SELECT
  fmp.player_id,
  fmp.player_source,
  cpp.player_name   AS cricket_pool_name,
  cpp.country       AS cricket_pool_country,
  ipm.player_name   AS ipl_master_name,
  ipm.team_code     AS ipl_team_code
FROM fantasy_match_players fmp
LEFT JOIN cricket_player_pool cpp
  ON cpp.id = fmp.player_id
LEFT JOIN ipl_player_master ipm
  ON ipm.id = fmp.player_id
WHERE fmp.fantasy_match_id = 84
ORDER BY cpp.country, cpp.player_name;

-- ── What to look for ───────────────────────────────────────
-- cricket_pool_name  → the CORRECT name (IND/AFG player)
-- ipl_master_name    → the WRONG name being shown to users
-- If cricket_pool_name ≠ ipl_master_name → confirmed bug


-- ============================================================
-- STEP 2: SHOW THE WRONG NAMES USERS ARE SEEING RIGHT NOW
-- ============================================================
-- This reproduces exactly what get-user-team.js and
-- get-fantasy-results.js return before the JS fix.
-- The wrong join: fantasy_user_team_players → ipl_player_master
-- ============================================================

SELECT
  fut.user_id,
  futp.player_id,
  ipm.player_name   AS WRONG_NAME_shown_to_user,
  ipm.team_code     AS WRONG_TEAM_shown_to_user,
  cpp.player_name   AS CORRECT_NAME,
  cpp.country       AS CORRECT_TEAM,
  fpms.fantasy_points
FROM fantasy_user_teams fut
JOIN fantasy_user_team_players futp
  ON fut.id = futp.fantasy_user_team_id
LEFT JOIN ipl_player_master ipm
  ON ipm.id = futp.player_id
LEFT JOIN cricket_player_pool cpp
  ON cpp.id = futp.player_id
LEFT JOIN fantasy_player_match_stats fpms
  ON fpms.player_id = futp.player_id
 AND fpms.fantasy_match_id = fut.fantasy_match_id
WHERE fut.fantasy_match_id = 84
  AND futp.is_active = TRUE
ORDER BY fut.user_id, fpms.fantasy_points DESC NULLS LAST;

-- ── What to look for ───────────────────────────────────────
-- WRONG_NAME_shown_to_user  → IPL player name (the bug)
-- CORRECT_NAME              → actual IND/AFG player
-- If WRONG_NAME ≠ CORRECT_NAME → the bug is confirmed here


-- ============================================================
-- STEP 3: SHOW THE CORRECT NAMES (what users SHOULD see)
-- ============================================================
-- This is the correct query that the fixed JS will run.
-- Joins through fantasy_match_players to get player_source,
-- then LEFT JOINs both tables and takes the right one.
-- ============================================================

SELECT
  fut.user_id,
  futp.player_id,
  fmp.player_source,
  COALESCE(ipm.player_name, cpp.player_name)  AS correct_player_name,
  COALESCE(ipm.team_code,   cpp.country)      AS correct_team,
  COALESCE(ipm.player_type, cpp.player_tag)   AS player_type,
  fpms.fantasy_points
FROM fantasy_user_teams fut
JOIN fantasy_user_team_players futp
  ON fut.id = futp.fantasy_user_team_id
LEFT JOIN fantasy_match_players fmp
  ON fmp.player_id        = futp.player_id
 AND fmp.fantasy_match_id = fut.fantasy_match_id
LEFT JOIN ipl_player_master ipm
  ON ipm.id = futp.player_id
 AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
LEFT JOIN cricket_player_pool cpp
  ON cpp.id = futp.player_id
 AND fmp.player_source = 'cricket'
LEFT JOIN fantasy_player_match_stats fpms
  ON fpms.player_id        = futp.player_id
 AND fpms.fantasy_match_id = fut.fantasy_match_id
WHERE fut.fantasy_match_id = 84
  AND futp.is_active = TRUE
ORDER BY fut.user_id, fpms.fantasy_points DESC NULLS LAST;

-- ── What to look for ───────────────────────────────────────
-- correct_player_name should now show IND/AFG player names.
-- player_source = 'cricket' for all match 84 players.
-- If correct_player_name still looks wrong → check Step 4.


-- ============================================================
-- STEP 4: VERIFY cricapi_player_mapping FOR MATCH 84
-- ============================================================
-- The sync API (sync-cricapi-score.js) maps CricAPI scorecard
-- names → cricket_player_pool IDs using this table.
-- A mismatch here means a player gets 0 fantasy points even
-- though they played.
-- ============================================================

SELECT
  cpm.player_id,
  cpp.player_name   AS db_name,
  cpp.country,
  cpm.cricapi_player_name  AS cricapi_scorecard_name,
  CASE
    WHEN LOWER(cpp.player_name) = LOWER(cpm.cricapi_player_name)
      THEN 'EXACT MATCH'
    ELSE 'DIFFERENT — check scorecard'
  END AS name_match_status
FROM cricapi_player_mapping cpm
JOIN cricket_player_pool cpp ON cpp.id = cpm.player_id
WHERE cpm.fantasy_match_id = 84
ORDER BY cpp.country, cpp.player_name;

-- ── Known name difference to watch for ─────────────────────
-- DB name:        'Hashmatullah Shahid'
-- CricAPI name:   'Hashmatullah Shahidi'  (trailing 'i')
-- This is already handled in file 12 — just confirm it's there.


-- ============================================================
-- STEP 5: CONFIRM fantasy_player_match_stats HAS REAL SCORES
-- ============================================================
-- If sync-cricapi-score has been run (or manual scoring from
-- file 13), this shows the raw stats per player for match 84.
-- Players with runs/wickets but fantasy_points = 0 → scoring
-- formula didn't run. Re-run Section B of file 13.
-- ============================================================

SELECT
  cpp.player_name,
  cpp.country,
  fpms.runs,
  fpms.balls_faced,
  fpms.fours,
  fpms.sixes,
  fpms.wickets,
  fpms.overs_bowled,
  fpms.economy_rate,
  fpms.catches,
  fpms.stumpings,
  fpms.runouts,
  fpms.fantasy_points
FROM fantasy_player_match_stats fpms
JOIN cricket_player_pool cpp ON cpp.id = fpms.player_id
WHERE fpms.fantasy_match_id = 84
ORDER BY fpms.fantasy_points DESC NULLS LAST;

-- ── What to look for ───────────────────────────────────────
-- fantasy_points IS NULL or 0 for players with real stats
--   → re-run Section B of sql/13_ind_afg_1st_odi_manual_scoring.sql
--     OR re-run: /api/sync-cricapi-score?fantasy_match_id=84
-- player_name looks wrong (IPL name) → shouldn't happen here
--   because this join is on cricket_player_pool directly.


-- ============================================================
-- STEP 6: POST-FIX VERIFICATION
-- ============================================================
-- Run these AFTER you deploy the JS fixes described below.
-- They confirm users now see the right names and points.
-- ============================================================

-- 6A: Each user's team with correct player names + points
SELECT
  u.user_name,
  COALESCE(ipm.player_name, cpp.player_name) AS player_name,
  COALESCE(ipm.team_code, cpp.country)       AS team,
  fpms.fantasy_points,
  CASE
    WHEN fut.captain_player_id = futp.player_id      THEN 'C'
    WHEN fut.vice_captain_player_id = futp.player_id THEN 'VC'
    ELSE ''
  END AS role_badge
FROM fantasy_user_teams fut
JOIN fantasy_user_team_players futp
  ON fut.id = futp.fantasy_user_team_id
JOIN ipl_users u
  ON u.id = fut.user_id
LEFT JOIN fantasy_match_players fmp
  ON fmp.player_id        = futp.player_id
 AND fmp.fantasy_match_id = fut.fantasy_match_id
LEFT JOIN ipl_player_master ipm
  ON ipm.id = futp.player_id
 AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
LEFT JOIN cricket_player_pool cpp
  ON cpp.id = futp.player_id
 AND fmp.player_source = 'cricket'
LEFT JOIN fantasy_player_match_stats fpms
  ON fpms.player_id        = futp.player_id
 AND fpms.fantasy_match_id = fut.fantasy_match_id
WHERE fut.fantasy_match_id = 84
  AND futp.is_active = TRUE
ORDER BY u.user_name, fpms.fantasy_points DESC NULLS LAST;

-- 6B: Final leaderboard with total scores (sanity check)
SELECT
  u.user_name,
  fums.base_points,
  fums.captain_bonus,
  fums.vice_captain_bonus,
  fums.total_points
FROM fantasy_user_match_scores fums
JOIN ipl_users u ON u.id = fums.user_id
WHERE fums.fantasy_match_id = 84
ORDER BY fums.total_points DESC;

-- 6C: Any player with stats but still 0 points after the fix?
--     Should return 0 rows.
SELECT
  cpp.player_name,
  cpp.country,
  fpms.runs,
  fpms.wickets,
  fpms.catches,
  fpms.fantasy_points
FROM fantasy_player_match_stats fpms
JOIN cricket_player_pool cpp ON cpp.id = fpms.player_id
WHERE fpms.fantasy_match_id = 84
  AND fpms.fantasy_points = 0
  AND (fpms.runs > 0 OR fpms.wickets > 0 OR fpms.catches > 0)
ORDER BY cpp.player_name;


-- ============================================================
-- THE ACTUAL FIX — TWO JS FILES TO UPDATE
-- ============================================================
--
-- Both files need the same change: replace the hard JOIN on
-- ipl_player_master with the dual LEFT JOIN pattern that
-- already works correctly in api/get-fantasy-match.js.
--
-- ── FILE 1: api/get-user-team.js ─────────────────────────
--
-- FIND this block (lines ~29-51):
--
--   const players = await sql`
--     SELECT
--       pm.id,
--       pm.player_name,
--       pm.team_code AS team_name,
--       pm.player_tag AS role,
--       pm.player_type,
--       pm.auction_price_cr,
--       pm.player_cost_coins,
--       futp.player_slot,
--       futp.is_active,
--       futp.activated_at,
--       futp.deactivated_at
--     FROM fantasy_user_team_players futp
--     JOIN ipl_player_master pm
--       ON pm.id = futp.player_id
--     WHERE futp.fantasy_user_team_id = ${team[0].id}
--     ORDER BY
--       futp.is_active DESC,
--       futp.player_slot,
--       pm.team_code,
--       pm.player_name
--   `;
--
-- REPLACE with:
--
--   const players = await sql`
--     SELECT
--       futp.player_id                                         AS id,
--       COALESCE(ipm.player_name, cpp.player_name)            AS player_name,
--       COALESCE(ipm.team_code, cpp.country)                  AS team_name,
--       COALESCE(ipm.player_tag, cpp.player_tag)              AS role,
--       COALESCE(ipm.player_type, cpp.player_tag)             AS player_type,
--       COALESCE(ipm.auction_price_cr, cpp.player_cost_coins) AS auction_price_cr,
--       COALESCE(ipm.player_cost_coins, cpp.player_cost_coins) AS player_cost_coins,
--       futp.player_slot,
--       futp.is_active,
--       futp.activated_at,
--       futp.deactivated_at
--     FROM fantasy_user_team_players futp
--     LEFT JOIN fantasy_match_players fmp
--       ON fmp.player_id        = futp.player_id
--      AND fmp.fantasy_match_id = ${team[0].fantasy_match_id}
--     LEFT JOIN ipl_player_master ipm
--       ON ipm.id = futp.player_id
--      AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
--     LEFT JOIN cricket_player_pool cpp
--       ON cpp.id = futp.player_id
--      AND fmp.player_source = 'cricket'
--     WHERE futp.fantasy_user_team_id = ${team[0].id}
--     ORDER BY
--       futp.is_active DESC,
--       futp.player_slot,
--       COALESCE(ipm.team_code, cpp.country),
--       COALESCE(ipm.player_name, cpp.player_name)
--   `;
--
--
-- ── FILE 2: api/get-fantasy-results.js ───────────────────
--
-- FIND this block (lines ~19-65):
--
--   const players = await sql`
--     SELECT
--       pm.id,
--       pm.player_name,
--       pm.team_code,
--       pm.player_tag,
--       pm.player_type,
--       fpms.runs, ...
--       CASE
--         WHEN fut.captain_player_id = pm.id THEN 'C'
--         WHEN fut.vice_captain_player_id = pm.id THEN 'VC'
--         ELSE ''
--       END AS captain_role
--     FROM fantasy_user_teams fut
--     JOIN fantasy_user_team_players futp
--       ON fut.id = futp.fantasy_user_team_id
--     JOIN fantasy_player_match_stats fpms
--       ON fpms.player_id = futp.player_id
--      AND fpms.fantasy_match_id = fut.fantasy_match_id
--     JOIN ipl_player_master pm
--       ON pm.id = futp.player_id
--     WHERE ...
--   `;
--
-- REPLACE with:
--
--   const players = await sql`
--     SELECT
--       futp.player_id                                        AS id,
--       COALESCE(ipm.player_name, cpp.player_name)           AS player_name,
--       COALESCE(ipm.team_code, cpp.country)                 AS team_code,
--       COALESCE(ipm.player_tag, cpp.player_tag)             AS player_tag,
--       COALESCE(ipm.player_type, cpp.player_tag)            AS player_type,
--       fpms.runs,
--       fpms.balls_faced,
--       fpms.fours,
--       fpms.sixes,
--       fpms.strike_rate,
--       fpms.overs_bowled,
--       fpms.maidens,
--       fpms.runs_conceded,
--       fpms.wickets,
--       fpms.economy_rate,
--       fpms.catches,
--       fpms.stumpings,
--       fpms.runouts,
--       fpms.fantasy_points,
--       CASE
--         WHEN fut.captain_player_id      = futp.player_id THEN 'C'
--         WHEN fut.vice_captain_player_id = futp.player_id THEN 'VC'
--         ELSE ''
--       END AS captain_role
--     FROM fantasy_user_teams fut
--     JOIN fantasy_user_team_players futp
--       ON fut.id = futp.fantasy_user_team_id
--     JOIN fantasy_player_match_stats fpms
--       ON fpms.player_id        = futp.player_id
--      AND fpms.fantasy_match_id = fut.fantasy_match_id
--     LEFT JOIN fantasy_match_players fmp
--       ON fmp.player_id        = futp.player_id
--      AND fmp.fantasy_match_id = fut.fantasy_match_id
--     LEFT JOIN ipl_player_master ipm
--       ON ipm.id = futp.player_id
--      AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
--     LEFT JOIN cricket_player_pool cpp
--       ON cpp.id = futp.player_id
--      AND fmp.player_source = 'cricket'
--     WHERE fut.user_id = ${Number(user_id)}
--       AND fut.fantasy_match_id = ${Number(fantasy_match_id)}
--       AND futp.is_active = TRUE
--     ORDER BY fpms.fantasy_points DESC
--   `;
--
--
-- ── WHY THE FIX WORKS ─────────────────────────────────────
--
--   fantasy_match_players.player_source = 'cricket' for all
--   match 84 players. The LEFT JOIN condition
--   "AND fmp.player_source = 'cricket'" ensures that
--   cricket_player_pool is used for the name lookup.
--   ipl_player_master is LEFT JOINed but its condition
--   "AND COALESCE(fmp.player_source,'ipl') = 'ipl'" is FALSE
--   for cricket players, so it contributes NULL — and
--   COALESCE picks up the correct name from cricket_player_pool.
--
--   This is the exact same logic already used in:
--     api/get-fantasy-match.js (the player picker — always worked)
--     sql/player_selection_active.sql
-- ============================================================
