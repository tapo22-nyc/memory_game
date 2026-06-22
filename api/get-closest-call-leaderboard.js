const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  const { closest_call_match_id, match_ids } = req.query;

  try {
    let leaderboard;
    let closestCallsMap = {};

    if (closest_call_match_id) {
      /* ── Per-match leaderboard ── */
      const matchId = Number(closest_call_match_id);

      leaderboard = await sql`
        SELECT
          u.user_name,
          p.user_id,
          SUM(p.points_awarded)                              AS total_points,
          COUNT(CASE WHEN p.difference = 0 THEN 1 END)      AS exact_calls,
          COUNT(p.id)                                        AS questions_answered
        FROM closest_call_predictions p
        JOIN ipl_users u ON u.id = p.user_id
        JOIN closest_call_questions q ON q.id = p.question_id
        WHERE p.closest_call_match_id = ${matchId}
          AND q.status = 'scored'
        GROUP BY u.user_name, p.user_id
        ORDER BY SUM(p.points_awarded) DESC
      `;

      const closestRows = await sql`
        WITH min_diffs AS (
          SELECT question_id, MIN(difference) AS min_diff
          FROM closest_call_predictions
          WHERE closest_call_match_id = ${matchId}
            AND difference IS NOT NULL
          GROUP BY question_id
        )
        SELECT p.user_id, COUNT(*) AS closest_calls
        FROM closest_call_predictions p
        JOIN min_diffs md ON md.question_id = p.question_id AND md.min_diff = p.difference
        JOIN closest_call_questions q ON q.id = p.question_id AND q.status = 'scored'
        WHERE p.closest_call_match_id = ${matchId}
        GROUP BY p.user_id
      `;
      for (const r of closestRows) closestCallsMap[r.user_id] = Number(r.closest_calls);

    } else if (match_ids) {
      /* ── Tournament aggregate: filter by list of match IDs ──
         match_ids is a comma-separated string like "1,2,3"
         Parse and validate to prevent injection. */
      const idList = match_ids.split(',')
        .map(s => parseInt(s.trim(), 10))
        .filter(n => !isNaN(n) && n > 0);

      if (!idList.length) {
        return res.status(400).json({ error: 'No valid match IDs provided.' });
      }

      leaderboard = await sql`
        SELECT
          u.user_name,
          p.user_id,
          SUM(p.points_awarded)                              AS total_points,
          COUNT(CASE WHEN p.difference = 0 THEN 1 END)      AS exact_calls,
          COUNT(p.id)                                        AS questions_answered,
          COUNT(DISTINCT p.closest_call_match_id)            AS matches_played
        FROM closest_call_predictions p
        JOIN ipl_users u ON u.id = p.user_id
        JOIN closest_call_questions q ON q.id = p.question_id
        WHERE p.closest_call_match_id = ANY(${idList})
          AND q.status = 'scored'
        GROUP BY u.user_name, p.user_id
        ORDER BY SUM(p.points_awarded) DESC
      `;

      const closestRows = await sql`
        WITH min_diffs AS (
          SELECT question_id, MIN(difference) AS min_diff
          FROM closest_call_predictions
          WHERE closest_call_match_id = ANY(${idList})
            AND difference IS NOT NULL
          GROUP BY question_id
        )
        SELECT p.user_id, COUNT(*) AS closest_calls
        FROM closest_call_predictions p
        JOIN min_diffs md ON md.question_id = p.question_id AND md.min_diff = p.difference
        JOIN closest_call_questions q ON q.id = p.question_id AND q.status = 'scored'
        WHERE p.closest_call_match_id = ANY(${idList})
        GROUP BY p.user_id
      `;
      for (const r of closestRows) closestCallsMap[r.user_id] = Number(r.closest_calls);

    } else {
      /* ── Overall leaderboard ── */
      leaderboard = await sql`
        SELECT
          u.user_name,
          p.user_id,
          SUM(p.points_awarded)                              AS total_points,
          COUNT(CASE WHEN p.difference = 0 THEN 1 END)      AS exact_calls,
          COUNT(p.id)                                        AS questions_answered,
          COUNT(DISTINCT p.closest_call_match_id)            AS matches_played
        FROM closest_call_predictions p
        JOIN ipl_users u ON u.id = p.user_id
        JOIN closest_call_questions q ON q.id = p.question_id
        WHERE q.status = 'scored'
        GROUP BY u.user_name, p.user_id
        ORDER BY SUM(p.points_awarded) DESC
      `;

      const closestRows = await sql`
        WITH min_diffs AS (
          SELECT question_id, MIN(difference) AS min_diff
          FROM closest_call_predictions
          WHERE difference IS NOT NULL
          GROUP BY question_id
        )
        SELECT p.user_id, COUNT(*) AS closest_calls
        FROM closest_call_predictions p
        JOIN min_diffs md ON md.question_id = p.question_id AND md.min_diff = p.difference
        JOIN closest_call_questions q ON q.id = p.question_id AND q.status = 'scored'
        GROUP BY p.user_id
      `;
      for (const r of closestRows) closestCallsMap[r.user_id] = Number(r.closest_calls);
    }

    const ranked = leaderboard.map((row, i) => ({
      rank:               i + 1,
      user_name:          row.user_name,
      user_id:            row.user_id,
      total_points:       Number(row.total_points || 0),
      exact_calls:        Number(row.exact_calls || 0),
      closest_calls:      closestCallsMap[row.user_id] || 0,
      questions_answered: Number(row.questions_answered || 0),
      matches_played:     row.matches_played ? Number(row.matches_played) : undefined,
    }));

    return res.status(200).json({ leaderboard: ranked });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
