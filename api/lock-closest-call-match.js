import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const authHeader = req.headers.authorization;
    const cronHeader = req.headers['x-vercel-cron'];

    const isAuthorized =
      authHeader === `Bearer ${process.env.CRON_SECRET}` ||
      cronHeader === '1';

    if (!isAuthorized) {
      return res.status(401).json({
        error: 'Unauthorized',
        hasAuthHeader: !!authHeader,
        hasVercelCronHeader: !!cronHeader
      });
    }

    const closestCallMatchId = 7; // MI vs RR closest call game

    const before = await sql`
      SELECT id, match_title, status
      FROM closest_call_matches
      WHERE id = ${closestCallMatchId}
    `;

    const updated = await sql`
      UPDATE closest_call_matches
      SET status = 'locked'
      WHERE id = ${closestCallMatchId}
        AND status = 'open'
      RETURNING id, match_title, status;
    `;

    const after = await sql`
      SELECT id, match_title, status
      FROM closest_call_matches
      WHERE id = ${closestCallMatchId}
    `;

    return res.status(200).json({
      success: updated.length > 0,
      message: updated.length
        ? 'Closest call match locked successfully'
        : 'No update made. Match may already be locked, closed, or ID may be wrong.',
      closestCallMatchId,
      before,
      updated,
      after
    });

  } catch (error) {
    console.error('Lock closest call error:', error);

    return res.status(500).json({
      error: 'Failed to lock closest call match',
      details: error.message
    });
  }
}
