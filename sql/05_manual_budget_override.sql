-- ============================================================
-- FILE: sql/05_manual_budget_override.sql
-- PURPOSE: Manually override a player's budget in a specific
--          match. Use this when the calculated budget doesn't
--          make sense and you want to set it yourself.
--
-- RUN ORDER:
--   Step 1 — Add update_note column (run once)
--   Step 2 — Override one player's budget (run as needed)
--   Step 3 — View all manual overrides (run to audit)
--   Step 4 — Undo an override (run to revert to calculated)
-- ============================================================


-- ============================================================
-- STEP 1: ADD update_note COLUMN (run once)
-- ============================================================

ALTER TABLE match_player_budgets
  ADD COLUMN IF NOT EXISTS update_note TEXT;


-- ============================================================
-- STEP 2: MANUALLY OVERRIDE A PLAYER'S BUDGET
--
-- Fill in:
--   your_match_id     → the fantasy_match_id (e.g. 12)
--   'Player Name'     → exact player name (case-insensitive)
--   your_budget       → new budget in dollars (e.g. 175000)
--   'your note here'  → why you changed it
-- ============================================================

UPDATE match_player_budgets
SET
  final_player_budget = 175000,                        -- ← new budget ($175K = 175000)
  budget_tier         = 'mid',                         -- ← premium / mid / value
  update_note         = 'Bumped up — strong recent form, auto-score undervalued him',
  updated_at          = NOW()
WHERE fantasy_match_id = 12                            -- ← your match ID
  AND LOWER(player_name) = LOWER('Kusal Mendis');      -- ← player name (case-insensitive)


-- ============================================================
-- STEP 3: VIEW ALL MANUAL OVERRIDES
-- Shows every player whose budget was manually changed.
-- ============================================================

SELECT
  mpb.fantasy_match_id,
  fm.match_title,
  mpb.player_name,
  mpb.team_name,
  mpb.role,
  mpb.budget_tier,
  mpb.final_player_budget,
  mpb.raw_budget_score,
  mpb.update_note,
  mpb.updated_at
FROM match_player_budgets mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
WHERE mpb.update_note IS NOT NULL
ORDER BY mpb.updated_at DESC;


-- ============================================================
-- STEP 4: UNDO AN OVERRIDE (revert to calculated value)
-- This clears the note and triggers a recalculation by
-- calling the refresh API again. Or set the value back
-- manually using Step 2.
-- ============================================================

UPDATE match_player_budgets
SET
  update_note = NULL,
  updated_at  = NOW()
WHERE fantasy_match_id = 12                            -- ← your match ID
  AND LOWER(player_name) = LOWER('Kusal Mendis');      -- ← player name

-- After running Step 4, visit this URL to recalculate:
-- https://www.playmtgames.com/api/refresh-match-player-budgets?fantasy_match_id=12
