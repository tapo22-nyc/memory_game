const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
const matches = await sql`
  SELECT 
    m.id,
    m.match_title,
    m.team_1,
    m.team_2,
    m.match_date,
    m.status,
    w.contest_open_time,
    w.contest_lock_time
  FROM ipl_matches m
  LEFT JOIN ipl_match_windows w
    ON m.id = w.match_id
  ORDER BY m.match_date ASC
`;
    res.status(200).json({ matches });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
