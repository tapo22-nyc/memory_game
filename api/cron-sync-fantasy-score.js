import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const activeMatches = await sql`
      SELECT fantasy_match_id, max_total_points_jump
      FROM fantasy_score_sync_control
      WHERE is_auto_sync_enabled = TRUE
      ORDER BY fantasy_match_id
    `;

    if (!activeMatches.length) {
      return res.status(200).json({
        skipped: true,
        message: 'No active matches for auto sync'
      });
    }

    const baseUrl = 'https://www.playmtgames.com';
    const finalResults = [];

    for (const match of activeMatches) {
      const fantasyMatchId = match.fantasy_match_id;

      const beforeScores = await sql`
        SELECT COALESCE(MAX(total_points), 0) AS max_total_points
        FROM fantasy_user_match_scores
        WHERE fantasy_match_id = ${fantasyMatchId}
      `;

      const beforeMaxPoints = Number(beforeScores[0].max_total_points || 0);

      const urls = [
        `${baseUrl}/api/sync-match-score-note?fantasy_match_id=${fantasyMatchId}&source=auto`,
        `${baseUrl}/api/sync-cricapi-score?fantasy_match_id=${fantasyMatchId}&source=auto`,
        `${baseUrl}/api/recalculate-fantasy-user-scores?fantasy_match_id=${fantasyMatchId}&source=auto`
      ];

      const stepResults = [];

      for (const url of urls) {
        const response = await fetch(url, {
          headers: {
            Authorization: `Bearer ${process.env.CRON_SECRET}`
          }
        });

        const data = await response.json();

        stepResults.push({
          url,
          status: response.status,
          data
        });

        if (!response.ok) {
          throw new Error(`Failed for match ${fantasyMatchId}: ${JSON.stringify(data)}`);
        }

        if (
          url.includes('/api/sync-cricapi-score') &&
          data.unmapped_players &&
          data.unmapped_players.length > 0
        ) {
          await sql`
            UPDATE fantasy_score_sync_control
            SET
              is_auto_sync_enabled = FALSE,
              sync_status = 'manual',
              stop_reason = ${`Stopped because unmapped players found: ${data.unmapped_players.join(', ')}`},
              updated_at = CURRENT_TIMESTAMP
            WHERE fantasy_match_id = ${fantasyMatchId}
          `;

          finalResults.push({
            fantasy_match_id: fantasyMatchId,
            stopped: true,
            reason: 'Unmapped players found',
            unmapped_players: data.unmapped_players
          });

          continue;
        }
      }

      const afterScores = await sql`
        SELECT COALESCE(MAX(total_points), 0) AS max_total_points
        FROM fantasy_user_match_scores
        WHERE fantasy_match_id = ${fantasyMatchId}
      `;

      const afterMaxPoints = Number(afterScores[0].max_total_points || 0);
      const pointsJump = afterMaxPoints - beforeMaxPoints;
      const allowedJump = Number(match.max_total_points_jump || 150);

      if (pointsJump > allowedJump) {
        await sql`
          UPDATE fantasy_score_sync_control
          SET
            is_auto_sync_enabled = FALSE,
            sync_status = 'manual',
            stop_reason = ${`Stopped because points jumped by ${pointsJump}, above allowed limit ${allowedJump}`},
            updated_at = CURRENT_TIMESTAMP
          WHERE fantasy_match_id = ${fantasyMatchId}
        `;
      }

      finalResults.push({
        fantasy_match_id: fantasyMatchId,
        beforeMaxPoints,
        afterMaxPoints,
        pointsJump,
        allowedJump,
        stepResults
      });
    }

    return res.status(200).json({
      success: true,
      results: finalResults
    });

  } catch (error) {
    console.error('cron-sync-fantasy-score error:', error);
    return res.status(500).json({ error: error.message });
  }
}
