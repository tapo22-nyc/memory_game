const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const matches = await sql`
      SELECT
        m.id,
        m.fantasy_match_id,
        m.ipl_match_id,
        m.match_title,
        m.team_1,
        m.team_2,
        m.match_date,
        EXTRACT(EPOCH FROM m.match_date)::bigint * 1000 AS match_date_ms,
        m.status,
        m.created_at,
        m.updated_at,
        m.contest_id,
        c.contest_name,
        c.contest_type
      FROM closest_call_matches m
      LEFT JOIN closest_call_contests c ON c.id = m.contest_id
      WHERE m.status IN ('open', 'locked', 'closed')
      ORDER BY m.match_date DESC, m.id DESC
    `;

    return res.status(200).json({ matches });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
