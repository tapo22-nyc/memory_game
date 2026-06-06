-- ============================================================
-- MT Games — International Matches Migration
-- Run this in your Neon PostgreSQL console
-- Safe to re-run (uses IF NOT EXISTS / ON CONFLICT)
-- ============================================================


-- ============================================================
-- STEP 1: Add match_format to fantasy_matches
-- ============================================================
ALTER TABLE fantasy_matches
  ADD COLUMN IF NOT EXISTS match_format TEXT NOT NULL DEFAULT 'ipl';

-- ============================================================
-- STEP 2: Create cricket_player_pool
-- Generic player table for non-IPL / international matches
-- ============================================================
CREATE TABLE IF NOT EXISTS cricket_player_pool (
  id                SERIAL PRIMARY KEY,
  player_name       TEXT    NOT NULL,
  country           TEXT    NOT NULL,
  player_type       TEXT,
  player_tag        TEXT,
  player_cost_coins NUMERIC(10,2) NOT NULL DEFAULT 5,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- STEP 3: Add player_source to fantasy_match_players
-- Tells the API which pool to join for each player row
-- ============================================================
ALTER TABLE fantasy_match_players
  ADD COLUMN IF NOT EXISTS player_source TEXT NOT NULL DEFAULT 'ipl';

-- Drop FK constraint on player_id so cricket_player_pool IDs
-- can coexist alongside ipl_player_master IDs in the same column.
ALTER TABLE fantasy_match_players
  DROP CONSTRAINT IF EXISTS fantasy_match_players_player_id_fkey;


-- ============================================================
-- STEP 4: Insert England players (ENG vs NZ 2nd Test)
-- All cost 5 coins. IDs will be auto-assigned (SERIAL).
-- ============================================================
INSERT INTO cricket_player_pool (player_name, country, player_type, player_tag, player_cost_coins)
VALUES
  ('Zak Crawley',    'ENG', 'BAT', 'batsman',       5),
  ('Ben Duckett',    'ENG', 'BAT', 'batsman',       5),
  ('Ollie Pope',     'ENG', 'BAT', 'batsman',       5),
  ('Joe Root',       'ENG', 'BAT', 'batsman',       5),
  ('Harry Brook',    'ENG', 'BAT', 'batsman',       5),
  ('Ben Stokes',     'ENG', 'AR',  'all-rounder',   5),
  ('Jamie Smith',    'ENG', 'WK',  'wicket-keeper', 5),
  ('Chris Woakes',   'ENG', 'AR',  'all-rounder',   5),
  ('Gus Atkinson',   'ENG', 'BOWL','bowler',        5),
  ('Ollie Robinson', 'ENG', 'BOWL','bowler',        5),
  ('Mark Wood',      'ENG', 'BOWL','bowler',        5),
  ('Jacob Bethell',  'ENG', 'BAT', 'batsman',       5),
  ('Brydon Carse',   'ENG', 'BOWL','bowler',        5)
ON CONFLICT DO NOTHING;

-- ============================================================
-- STEP 5: Insert New Zealand players (ENG vs NZ 2nd Test)
-- ============================================================
INSERT INTO cricket_player_pool (player_name, country, player_type, player_tag, player_cost_coins)
VALUES
  ('Tom Latham',        'NZL', 'WK',  'wicket-keeper', 5),
  ('Devon Conway',      'NZL', 'BAT', 'batsman',       5),
  ('Kane Williamson',   'NZL', 'BAT', 'batsman',       5),
  ('Rachin Ravindra',   'NZL', 'AR',  'all-rounder',   5),
  ('Daryl Mitchell',    'NZL', 'AR',  'all-rounder',   5),
  ('Tom Blundell',      'NZL', 'BAT', 'batsman',       5),
  ('Glenn Phillips',    'NZL', 'BAT', 'batsman',       5),
  ('Matt Henry',        'NZL', 'BOWL','bowler',        5),
  ('Tim Southee',       'NZL', 'BOWL','bowler',        5),
  ('Kyle Jamieson',     'NZL', 'BOWL','bowler',        5),
  ('William O''Rourke', 'NZL', 'BOWL','bowler',        5),
  ('Neil Wagner',       'NZL', 'BOWL','bowler',        5)
ON CONFLICT DO NOTHING;

-- ============================================================
-- STEP 6: Insert Sri Lanka players (SL vs WI ODI)
-- ============================================================
INSERT INTO cricket_player_pool (player_name, country, player_type, player_tag, player_cost_coins)
VALUES
  ('Pathum Nissanka',     'SL', 'BAT', 'batsman',       5),
  ('Avishka Fernando',    'SL', 'BAT', 'batsman',       5),
  ('Kusal Mendis',        'SL', 'WK',  'wicket-keeper', 5),
  ('Charith Asalanka',    'SL', 'BAT', 'batsman',       5),
  ('Dhananjaya de Silva', 'SL', 'AR',  'all-rounder',   5),
  ('Dasun Shanaka',       'SL', 'AR',  'all-rounder',   5),
  ('Wanindu Hasaranga',   'SL', 'AR',  'all-rounder',   5),
  ('Dushmantha Chameera', 'SL', 'BOWL','bowler',        5),
  ('Maheesh Theekshana',  'SL', 'BOWL','bowler',        5),
  ('Matheesha Pathirana', 'SL', 'BOWL','bowler',        5),
  ('Chamika Karunaratne', 'SL', 'AR',  'all-rounder',   5),
  ('Lahiru Kumara',       'SL', 'BOWL','bowler',        5)
ON CONFLICT DO NOTHING;

-- ============================================================
-- STEP 7: Insert West Indies players (SL vs WI ODI)
-- ============================================================
INSERT INTO cricket_player_pool (player_name, country, player_type, player_tag, player_cost_coins)
VALUES
  ('Kraigg Brathwaite', 'WI', 'BAT', 'batsman',       5),
  ('Shai Hope',         'WI', 'WK',  'wicket-keeper', 5),
  ('Brandon King',      'WI', 'BAT', 'batsman',       5),
  ('Nicholas Pooran',   'WI', 'WK',  'wicket-keeper', 5),
  ('Rovman Powell',     'WI', 'BAT', 'batsman',       5),
  ('Justin Greaves',    'WI', 'AR',  'all-rounder',   5),
  ('Keacy Carty',       'WI', 'BAT', 'batsman',       5),
  ('Jason Holder',      'WI', 'AR',  'all-rounder',   5),
  ('Alzarri Joseph',    'WI', 'BOWL','bowler',        5),
  ('Gudakesh Motie',    'WI', 'BOWL','bowler',        5),
  ('Jayden Seales',     'WI', 'BOWL','bowler',        5),
  ('Akeal Hosein',      'WI', 'BOWL','bowler',        5)
ON CONFLICT DO NOTHING;


-- ============================================================
-- STEP 8: Create fantasy_matches for ENG vs NZ 2nd Test
-- Replace match_date with the actual match date before running.
-- ============================================================
INSERT INTO fantasy_matches
  (match_title, team_1, team_2, status, budget_coins, match_format)
VALUES
  ('ENG vs NZ — 2nd Test', 'ENG', 'NZL', 'open', 75, 'test')
RETURNING id;

-- NOTE: Copy the id returned above.
-- Then run the fantasy_match_players inserts below,
-- replacing <ENG_NZ_MATCH_ID> with that id.


-- ============================================================
-- STEP 9: Create fantasy_matches for SL vs WI ODI
-- Replace match_date with the actual match date before running.
-- ============================================================
INSERT INTO fantasy_matches
  (match_title, team_1, team_2, status, budget_coins, match_format)
VALUES
  ('SL vs WI — ODI', 'SL', 'WI', 'open', 75, 'odi')
RETURNING id;

-- NOTE: Copy the id returned above.
-- Then run the fantasy_match_players inserts below,
-- replacing <SL_WI_MATCH_ID> with that id.


-- ============================================================
-- STEP 10: Link ENG + NZL players to ENG vs NZ match
-- Replace <ENG_NZ_MATCH_ID> with the actual fantasy_match id
-- ============================================================

-- Run this query first to get the cricket_player_pool IDs:
-- SELECT id, player_name, country FROM cricket_player_pool
-- WHERE country IN ('ENG','NZL') ORDER BY country, player_name;

-- Then insert using:
/*
INSERT INTO fantasy_match_players (fantasy_match_id, player_id, player_source)
SELECT <ENG_NZ_MATCH_ID>, id, 'cricket'
FROM cricket_player_pool
WHERE country IN ('ENG', 'NZL')
  AND is_active = TRUE
ON CONFLICT DO NOTHING;
*/

-- SHORTCUT: After both INSERTs above succeed (steps 8 + 9),
-- you can use this single query (fills both matches at once).
-- First run step 8 and 9 above to get the match IDs, then:

-- For ENG vs NZ Test — replace ??? with the match id from step 8:
-- INSERT INTO fantasy_match_players (fantasy_match_id, player_id, player_source)
-- SELECT ???, id, 'cricket'
-- FROM cricket_player_pool
-- WHERE country IN ('ENG','NZL') AND is_active = TRUE
-- ON CONFLICT DO NOTHING;

-- For SL vs WI ODI — replace ??? with the match id from step 9:
-- INSERT INTO fantasy_match_players (fantasy_match_id, player_id, player_source)
-- SELECT ???, id, 'cricket'
-- FROM cricket_player_pool
-- WHERE country IN ('SL','WI') AND is_active = TRUE
-- ON CONFLICT DO NOTHING;


-- ============================================================
-- VERIFICATION QUERIES
-- Run these after completing all steps to verify setup.
-- ============================================================

-- Check cricket_player_pool entries:
-- SELECT country, COUNT(*) as player_count FROM cricket_player_pool GROUP BY country ORDER BY country;

-- Check fantasy_matches:
-- SELECT id, match_title, team_1, team_2, status, budget_coins, match_format FROM fantasy_matches ORDER BY id DESC LIMIT 10;

-- Check linked players for a match (replace ??? with match id):
-- SELECT cpp.player_name, cpp.country, cpp.player_type, cpp.player_cost_coins
-- FROM fantasy_match_players fmp
-- JOIN cricket_player_pool cpp ON cpp.id = fmp.player_id
-- WHERE fmp.fantasy_match_id = ??? AND fmp.player_source = 'cricket'
-- ORDER BY cpp.country, cpp.player_name;
