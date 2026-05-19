-- ============================================================
-- Migration: Add difficulty support to Spelling Bee
-- Run in Neon DB console (once, in order)
-- ============================================================

-- STEP 1: Add difficulty column to spelling_bee_puzzles
ALTER TABLE spelling_bee_puzzles
  ADD COLUMN difficulty VARCHAR(10) NOT NULL DEFAULT 'easy'
    CHECK (difficulty IN ('easy', 'medium', 'hard'));

-- STEP 2: Tag existing puzzle #1 as 'easy'
UPDATE spelling_bee_puzzles SET difficulty = 'easy' WHERE puzzle_number = 1;

-- STEP 3: Add index for fast difficulty lookups
CREATE INDEX idx_sbp_active_diff ON spelling_bee_puzzles(is_active, difficulty);


-- ============================================================
-- STEP 4: Insert Medium puzzle (#2)
-- Center: N  |  Outer: A, I, L, T, E, S
-- Pangram: ENTAILS  (E-N-T-A-I-L-S — all 7 letters)
-- ============================================================

INSERT INTO spelling_bee_puzzles
  (puzzle_number, puzzle_date, center_letter, outer_letters, pangram_word, is_active, difficulty)
VALUES
  (2, '2026-05-18', 'N', 'A,I,L,T,E,S', 'ENTAILS', true, 'medium');

-- Replace puzzle_id = 2 below with the actual id returned by the INSERT above
-- (run: SELECT id FROM spelling_bee_puzzles WHERE puzzle_number = 2)

INSERT INTO spelling_bee_words (puzzle_id, word, is_pangram) VALUES
  (2, 'nail',     false),
  (2, 'nails',    false),
  (2, 'neat',     false),
  (2, 'nets',     false),
  (2, 'anti',     false),
  (2, 'ante',     false),
  (2, 'ants',     false),
  (2, 'nest',     false),
  (2, 'lane',     false),
  (2, 'lanes',    false),
  (2, 'lean',     false),
  (2, 'leans',    false),
  (2, 'lent',     false),
  (2, 'line',     false),
  (2, 'lines',    false),
  (2, 'lint',     false),
  (2, 'lints',    false),
  (2, 'snit',     false),
  (2, 'snail',    false),
  (2, 'saint',    false),
  (2, 'satin',    false),
  (2, 'slain',    false),
  (2, 'stain',    false),
  (2, 'inlet',    false),
  (2, 'inlets',   false),
  (2, 'alien',    false),
  (2, 'aliens',   false),
  (2, 'listen',   false),
  (2, 'tinsel',   false),
  (2, 'latins',   false),
  (2, 'entail',   false),
  (2, 'entails',  true);


-- ============================================================
-- STEP 5: Insert Hard puzzle (#3)
-- Center: G  |  Outer: A, E, I, L, N, R
-- Pangram: REALIGN  (R-E-A-L-I-G-N — all 7 letters)
-- ============================================================

INSERT INTO spelling_bee_puzzles
  (puzzle_number, puzzle_date, center_letter, outer_letters, pangram_word, is_active, difficulty)
VALUES
  (3, '2026-05-18', 'G', 'A,E,I,L,N,R', 'REALIGN', true, 'hard');

-- Replace puzzle_id = 3 below with the actual id returned by the INSERT above
-- (run: SELECT id FROM spelling_bee_puzzles WHERE puzzle_number = 3)

INSERT INTO spelling_bee_words (puzzle_id, word, is_pangram) VALUES
  (3, 'gale',     false),
  (3, 'gales',    false),
  (3, 'gain',     false),
  (3, 'gains',    false),
  (3, 'glair',    false),
  (3, 'glare',    false),
  (3, 'glean',    false),
  (3, 'grain',    false),
  (3, 'grail',    false),
  (3, 'reign',    false),
  (3, 'regal',    false),
  (3, 'ring',     false),
  (3, 'rings',    false),
  (3, 'rile',     false),
  (3, 'girl',     false),
  (3, 'girls',    false),
  (3, 'angel',    false),
  (3, 'angle',    false),
  (3, 'angler',   false),
  (3, 'linger',   false),
  (3, 'aligner',  false),
  (3, 'realign',  true);


-- ============================================================
-- VERIFICATION — run these to confirm setup
-- ============================================================
-- SELECT id, puzzle_number, difficulty, is_active, center_letter
-- FROM spelling_bee_puzzles ORDER BY id;
--
-- SELECT p.difficulty, COUNT(*) AS word_count
-- FROM spelling_bee_words w
-- JOIN spelling_bee_puzzles p ON p.id = w.puzzle_id
-- GROUP BY p.difficulty;
-- ============================================================
