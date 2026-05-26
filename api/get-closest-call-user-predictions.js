const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  const { user_id, closest_call_match_id } = req.query;

  if (!user_id) {
    return res.status(400).json({ error: 'user_id is required.' });
  }

  const userId = Number(user_id);
  if (isNaN(userId)) {
    return res.status(400).json({ error: 'user_id must be a number.' });
  }

  try {
    const users = await sql`SELECT id, user_name FROM ipl_users WHERE id = ${userId} LIMIT 1`;
    if (!users.length) return res.status(404).json({ error: 'User not found.' });
    const user = users[0];

    let matches, predictions;

    if (closest_call_match_id) {
      const matchId = Number(closest_call_match_id);
      if (isNaN(matchId)) return res.status(400).json({ error: 'closest_call_match_id must be a number.' });

      const matchRows = await sql`
        SELECT id, match_title, team_1, team_2, match_date, status
        FROM closest_call_matches WHERE id = ${matchId} LIMIT 1
      `;
      if (!matchRows.length) return res.status(404).json({ error: 'Match not found.' });
      matches = [matchRows[0]];

      const matchStatus = matchRows[0].status;

      // For open/locked matches: only return predictions where question is scored
      if (matchStatus === 'open' || matchStatus === 'locked') {
        predictions = await sql`
          SELECT
            p.question_id,
            p.predicted_value,
            p.predicted_runs,
            p.predicted_wickets,
            p.predicted_choice,
            p.difference,
            p.points_awarded,
            p.closest_call_match_id AS match_id,
            q.question_text,
            q.phase,
            q.status AS question_status,
            q.max_points,
            q.actual_value,
            q.actual_runs,
            q.actual_wickets
          FROM closest_call_predictions p
          JOIN closest_call_questions q ON q.id = p.question_id
          WHERE p.user_id = ${userId}
            AND p.closest_call_match_id = ${matchId}
            AND q.status = 'scored'
          ORDER BY q.phase, q.id
        `;
      } else {
        predictions = await sql`
          SELECT
            p.question_id,
            p.predicted_value,
            p.predicted_runs,
            p.predicted_wickets,
            p.predicted_choice,
            p.difference,
            p.points_awarded,
            p.closest_call_match_id AS match_id,
            q.question_text,
            q.phase,
            q.status AS question_status,
            q.max_points,
            q.actual_value,
            q.actual_runs,
            q.actual_wickets
          FROM closest_call_predictions p
          JOIN closest_call_questions q ON q.id = p.question_id
          WHERE p.user_id = ${userId}
            AND p.closest_call_match_id = ${matchId}
          ORDER BY q.phase, q.id
        `;
      }
    } else {
      const matchIdRows = await sql`
        SELECT DISTINCT closest_call_match_id AS id
        FROM closest_call_predictions
        WHERE user_id = ${userId}
      `;
      const ids = matchIdRows.map(r => r.id);

      if (!ids.length) {
        return res.status(200).json({ user, matches: [], predictions: [], total_points: 0, exact_calls: 0, questions_answered: 0 });
      }

      matches = await sql`
        SELECT id, match_title, team_1, team_2, match_date, status
        FROM closest_call_matches
        WHERE id = ANY(${ids})
        ORDER BY match_date DESC
      `;

      // Build a map of match statuses
      const matchStatusMap = {};
      for (const m of matches) { matchStatusMap[m.id] = m.status; }

      // Fetch all predictions; filter per-match based on status
      const allPreds = await sql`
        SELECT
          p.question_id,
          p.predicted_value,
          p.predicted_runs,
          p.predicted_wickets,
          p.predicted_choice,
          p.difference,
          p.points_awarded,
          p.closest_call_match_id AS match_id,
          q.question_text,
          q.phase,
          q.status AS question_status,
          q.max_points,
          q.actual_value,
          q.actual_runs,
          q.actual_wickets
        FROM closest_call_predictions p
        JOIN closest_call_questions q ON q.id = p.question_id
        WHERE p.user_id = ${userId}
        ORDER BY p.closest_call_match_id DESC, q.phase, q.id
      `;

      // For open/locked matches, only include scored questions
      predictions = allPreds.filter(function(p) {
        const ms = matchStatusMap[p.match_id];
        if (ms === 'open' || ms === 'locked') {
          return p.question_status === 'scored';
        }
        return true;
      });
    }

    const scored = predictions.filter(p => p.question_status === 'scored');
    const total_points = Math.round(scored.reduce((s, p) => s + Number(p.points_awarded || 0), 0));
    const exact_calls  = scored.filter(p => Number(p.difference) === 0).length;

    return res.status(200).json({
      user,
      matches,
      predictions: predictions.map(p => ({
        question_id:        p.question_id,
        match_id:           p.match_id,
        question_text:      p.question_text,
        phase:              p.phase,
        question_status:    p.question_status,
        max_points:         Number(p.max_points || 0),
        predicted_value:    p.predicted_value,
        predicted_runs:     p.predicted_runs    !== undefined ? p.predicted_runs    : null,
        predicted_wickets:  p.predicted_wickets !== undefined ? p.predicted_wickets : null,
        predicted_choice:   p.predicted_choice  !== undefined ? p.predicted_choice  : null,
        actual_value:       p.actual_value,
        actual_runs:        p.actual_runs        !== undefined ? p.actual_runs        : null,
        actual_wickets:     p.actual_wickets     !== undefined ? p.actual_wickets     : null,
        difference:         p.difference,
        points_awarded:     p.points_awarded !== null ? Number(p.points_awarded) : null,
      })),
      total_points,
      exact_calls,
      questions_answered: predictions.length,
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
