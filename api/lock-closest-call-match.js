import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const closestCallMatchId = 7;

    const before = await sql`
      SELECT id, match_title, status
      FROM closest_call_matches
      WHERE id = ${closestCallMatchId}
    `;

    const updated = await sql`
      UPDATE closest_call_matches
      SET status = 'locked'
      WHERE id = ${closestCallMatchId}
      RETURNING id, match_title, status;
    `;

    const after = await sql`
      SELECT id, match_title, status
      FROM closest_call_matches
      WHERE id = ${closestCallMatchId}
    `;

    return res.status(200).json({
      success: true,
      message: 'Closest call lock endpoint reached',
      before,
      updated,
      after
    });

  } catch (error) {
    return res.status(500).json({
      error: 'Failed to lock closest call match',
      details: error.message
    });
  }
}
