import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const matchId = 84; // replace if different

    await sql`
      UPDATE fantasy_matches
      SET
        status = 'locked',
        score_update_note = 'Game automatically locked'
      WHERE id = ${matchId}
    `;

    return res.status(200).json({
      success: true
    });

  } catch (err) {
    console.error(err);

    return res.status(500).json({
      error: 'Cron failed'
    });
  }
}
