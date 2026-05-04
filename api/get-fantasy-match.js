const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const { fantasy_match_id } = req.query;

    if (!fantasy_match_id) {
      return res.status(400).json({ error: 'fantasy_match_id is required.' });
    }

    const matches = await sql`
      SELECT *
      FROM fantasy_matches
      WHERE id = ${Number(fantasy_match_id)}
      LIMIT 1
    `;

    const players = await sql`
      SELECT *
      FROM fantasy_players
      WHERE fantasy_match_id = ${Number(fantasy_match_id)}
      ORDER BY team_name, player_name
    `;

    return res.status(200).json({
      match: matches[0],
      players
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
