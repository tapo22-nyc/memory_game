const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  const { closest_call_match_id, user_name } = req.query;

  if (!closest_call_match_id) {
    return res.status(400).json({ error: 'closest_call_match_id is required.' });
  }

  const matchId = Number(closest_call_match_id);
  if (isNaN(matchId)) {
    return res.status(400).json({ error: 'closest_call_match_id must be a number.' });
  }

  try {
    // Get match details
    const matches = await sql`
      SELECT * FROM closest_call_matches WHERE id = ${matchId} LIMIT 1
    `;
    if (!matches.length) {
      return res.status(404).json({ error: 'Match not found.' });
    }
    const match = matches[0];

    // Get or create user if user_name provided
    let user = null;
    if (user_name) {
      const cleanName = String(user_name).trim().toLowerCase().replace(/[^a-z0-9_]/g, '');
      if (cleanName.length >= 3) {
        const users = await sql`
          INSERT INTO ipl_users (user_name, total_points)
          VALUES (${cleanName}, 100)
          ON CONFLICT (user_name)
          DO UPDATE SET user_name = EXCLUDED.user_name
          RETURNING id, user_name, total_points
        `;
        user = users[0] || null;
      }
    }

    // Get questions
    const questions = await sql`
      SELECT * FROM closest_call_questions
      WHERE closest_call_match_id = ${matchId}
      ORDER BY phase, id ASC
    `;

    // Get user predictions if user is known
    let predictions = [];
    if (user) {
      predictions = await sql`
        SELECT * FROM closest_call_predictions
        WHERE user_id = ${user.id}
          AND closest_call_match_id = ${matchId}
      `;
    }

    const predMap = {};
    for (const p of predictions) {
      predMap[p.question_id] = p;
    }

    const now = new Date();

    // Annotate each question with editability and user prediction
    const annotated = questions.map(q => {
      const openTime  = q.open_time  ? new Date(q.open_time)  : null;
      const lockTime  = q.lock_time  ? new Date(q.lock_time)  : null;

      const is_visible = true;

      // A question is open now if:
      //  - question status is 'open'
      //  - current time is after open_time (if set)
      //  - current time is before lock_time (if set)
      const afterOpen   = !openTime  || now >= openTime;
      const beforeLock  = !lockTime  || now < lockTime;
      const is_open_now = q.status === 'open' && afterOpen && beforeLock;

      // Editable = question is open AND match is not closed/locked
      const matchEditable = match.status === 'open' || match.status === 'locked';
      const is_editable   = is_open_now && matchEditable;

      // Lock reason
      let lock_reason = null;
      if (q.status === 'scored') {
        lock_reason = 'Question scored';
      } else if (q.status === 'locked') {
        lock_reason = 'Question locked';
      } else if (q.status === 'void') {
        lock_reason = 'Question void';
      } else if (match.status === 'locked' || match.status === 'closed') {
        lock_reason = 'Match locked';
      } else if (lockTime && now >= lockTime) {
        lock_reason = 'Prediction window closed';
      } else if (openTime && now < openTime) {
        const phaseLabels = {
          powerplay:   'Opens after match starts',
          mid_innings: 'Opens after Powerplay',
          final:       'Opens after 12 overs',
        };
        lock_reason = phaseLabels[q.phase] || 'Opens during match';
      }

      const pred = predMap[q.id] || null;

      return {
        id:                  q.id,
        closest_call_match_id: q.closest_call_match_id,
        question_text:       q.question_text,
        question_type:       q.question_type,
        phase:               q.phase,
        team_code:           q.team_code,
        player_name:         q.player_name,
        innings_number:      q.innings_number,
        max_points:          q.max_points,
        scoring_rule_code:   q.scoring_rule_code,
        open_time:           q.open_time,
        lock_time:           q.lock_time,
        status:              q.status,
        actual_value:        q.actual_value,
        is_visible,
        is_open_now,
        is_editable,
        lock_reason,
        // User's prediction for this question
        user_prediction:     pred ? pred.predicted_value   : null,
        user_difference:     pred ? pred.difference         : null,
        user_points:         pred ? pred.points_awarded     : null,
        prediction_id:       pred ? pred.id                 : null,
      };
    });

    return res.status(200).json({
      match,
      user,
      questions: annotated,
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
