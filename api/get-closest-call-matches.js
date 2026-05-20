const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const matches = await sql`
      SELECT
        id,
        fantasy_match_id,
        ipl_match_id,
        match_title,
        team_1,
        team_2,
        match_date,
        status,
        created_at,
        updated_at
      FROM closest_call_matches
      WHERE status IN ('open', 'locked', 'closed')
      ORDER BY match_date DESC, id DESC
    `;

    return res.status(200).json({ matches });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
