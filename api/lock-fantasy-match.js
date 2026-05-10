import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const matchId = 54; // change this if needed

    const result = await sql`
      UPDATE fantasy_matches
      SET 
        status = 'locked',
        score_update_note = 'Match locked automatically by scheduled job'
      WHERE id = ${matchId}
      RETURNING id, match_title, status, score_update_note;
    `;

    return res.status(200).json({
      success: true,
      updated: result
    });

  } catch (error) {
    console.error('Lock cron error:', error);
    return res.status(500).json({ error: 'Failed to lock match' });
  }
}
