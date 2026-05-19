-- ============================================================
-- Cricket Spelling Bee — Table Creation
-- Run these in your Neon DB console (once)
-- ============================================================

CREATE TABLE spelling_bee_puzzles (
  id            SERIAL PRIMARY KEY,
  puzzle_number INT           NOT NULL,
  puzzle_date   DATE          NOT NULL,
  center_letter CHAR(1)       NOT NULL,
  outer_letters VARCHAR(30)   NOT NULL,  -- comma-separated e.g. 'A,C,E,I,S,T'
  pangram_word  VARCHAR(50),
  is_active     BOOLEAN       NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE spelling_bee_words (
  id        SERIAL PRIMARY KEY,
  puzzle_id INT         NOT NULL REFERENCES spelling_bee_puzzles(id) ON DELETE CASCADE,
  word      VARCHAR(50) NOT NULL,
  is_pangram BOOLEAN    NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE spelling_bee_user_guesses (
  id           SERIAL PRIMARY KEY,
  puzzle_id    INT         NOT NULL REFERENCES spelling_bee_puzzles(id) ON DELETE CASCADE,
  user_id      INT         REFERENCES ipl_users(id) ON DELETE SET NULL,
  user_name    VARCHAR(50),
  guessed_word VARCHAR(50) NOT NULL,
  is_correct   BOOLEAN     NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX idx_sbug_puzzle_user     ON spelling_bee_user_guesses(puzzle_id, user_id);
CREATE INDEX idx_sbug_puzzle_username ON spelling_bee_user_guesses(puzzle_id, user_name);
CREATE INDEX idx_sbug_correct         ON spelling_bee_user_guesses(puzzle_id, is_correct);
CREATE INDEX idx_sbw_puzzle           ON spelling_bee_words(puzzle_id);
CREATE INDEX idx_sbp_active           ON spelling_bee_puzzles(is_active);


-- ============================================================
-- Sample Puzzle #1  (Puzzle Date: 2026-05-18)
-- Center letter : R
-- Outer letters : A, C, E, I, S, T
-- Pangram       : RACIEST  (uses all 7 letters: R A C I E S T)
-- ============================================================

INSERT INTO spelling_bee_puzzles
  (puzzle_number, puzzle_date, center_letter, outer_letters, pangram_word, is_active)
VALUES
  (1, '2026-05-18', 'R', 'A,C,E,I,S,T', 'RACIEST', true);

-- Store puzzle id in a variable for convenience
-- (In Neon console you can run the words insert right after the puzzle insert)
-- Replace puzzle_id = 1 below if your SERIAL starts differently.

INSERT INTO spelling_bee_words (puzzle_id, word, is_pangram) VALUES
  (1, 'acre',    false),
  (1, 'arcs',    false),
  (1, 'aster',   false),
  (1, 'care',    false),
  (1, 'caret',   false),
  (1, 'carets',  false),
  (1, 'cares',   false),
  (1, 'cars',    false),
  (1, 'cart',    false),
  (1, 'carts',   false),
  (1, 'caster',  false),
  (1, 'caters',  false),
  (1, 'crate',   false),
  (1, 'crates',  false),
  (1, 'crest',   false),
  (1, 'cries',   false),
  (1, 'irate',   false),
  (1, 'ires',    false),
  (1, 'race',    false),
  (1, 'races',   false),
  (1, 'rate',    false),
  (1, 'rates',   false),
  (1, 'recast',  false),
  (1, 'rice',    false),
  (1, 'rices',   false),
  (1, 'rise',    false),
  (1, 'satire',  false),
  (1, 'scar',    false),
  (1, 'scare',   false),
  (1, 'scares',  false),
  (1, 'sire',    false),
  (1, 'sitar',   false),
  (1, 'stair',   false),
  (1, 'stairs',  false),
  (1, 'star',    false),
  (1, 'stars',   false),
  (1, 'stir',    false),
  (1, 'tears',   false),
  (1, 'tier',    false),
  (1, 'tiers',   false),
  (1, 'tire',    false),
  (1, 'tires',   false),
  (1, 'trace',   false),
  (1, 'traces',  false),
  (1, 'trice',   false),
  (1, 'tsar',    false),
  (1, 'raciest', true);


-- ============================================================
-- How to add a new puzzle each day
-- ============================================================
-- 1. Set previous puzzle inactive:
--    UPDATE spelling_bee_puzzles SET is_active = false WHERE is_active = true;
--
-- 2. Insert new puzzle:
--    INSERT INTO spelling_bee_puzzles
--      (puzzle_number, puzzle_date, center_letter, outer_letters, pangram_word, is_active)
--    VALUES
--      (2, '2026-05-19', 'E', 'A,B,C,D,F,G', 'SOMEWORD', true);
--
-- 3. Insert words for that puzzle_id (same pattern as above).
-- ============================================================
