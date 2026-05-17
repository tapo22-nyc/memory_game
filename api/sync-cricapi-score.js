import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const fantasyMatchId = Number(req.query.fantasy_match_id);

    if (!fantasyMatchId) {
      return res.status(400).json({ error: 'Missing fantasy_match_id' });
    }

    const mapping = await sql`
      SELECT cricapi_match_id
      FROM cricapi_match_mapping
      WHERE fantasy_match_id = ${fantasyMatchId}
    `;

    if (!mapping.length) {
      return res.status(404).json({
        error: 'No CricAPI match mapping found for this fantasy_match_id'
      });
    }

    const cricapiMatchId = mapping[0].cricapi_match_id;

    const apiUrl =
      `https://api.cricapi.com/v1/match_scorecard?apikey=${process.env.CRICAPI_KEY}&id=${cricapiMatchId}`;

    const response = await fetch(apiUrl);
    const data = await response.json();

    return res.status(200).json({
      message: 'CricAPI connected successfully',
      fantasy_match_id: fantasyMatchId,
      cricapi_match_id: cricapiMatchId,
      cricapi_response: data
    });

  } catch (error) {
    console.error('sync-cricapi-score error:', error);
    return res.status(500).json({ error: error.message });
  }
}
