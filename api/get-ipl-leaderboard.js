const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const leaderboard = await sql`
      SELECT * FROM ipl_leaderboard;
    `;

    res.status(200).json({ leaderboard });
  } catch (error) {
    console.error('leaderboard error:', error);
    res.status(500).json({ error: error.message });
  }
};
