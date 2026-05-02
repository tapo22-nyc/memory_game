const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const matches = await sql`
      SELECT 
        id,
        match_title,
        team_1,
        team_2,
        match_date,
        status
      FROM ipl_matches
      ORDER BY match_date ASC
    `;

    res.status(200).json({ matches });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
