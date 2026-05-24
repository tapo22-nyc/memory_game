import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const closestCallMatchId = 7; // RR vs MI closest call game ID

    const result = await sql`
      UPDATE ipl_matches
      SET status = 'locked'
      WHERE id = ${closestCallMatchId}
        AND status = 'open'
      RETURNING id, match_title, status;
    `;

    if (!result.length) {
      return res.status(200).json({
        skipped: true,
        message: 'Match was not open or ID was wrong',
        closestCallMatchId
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Closest Call match locked',
      match: result[0]
    });

  } catch (error) {
    console.error('Lock closest call error:', error);
    return res.status(500).json({
      error: 'Failed to lock closest call match',
      details: error.message
    });
  }
}
