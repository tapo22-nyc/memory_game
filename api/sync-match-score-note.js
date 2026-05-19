import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  try {
    const fantasyMatchId = Number(req.query.fantasy_match_id);

    if (!fantasyMatchId) {
      return res.status(400).json({ error: 'Missing fantasy_match_id' });
    }

    const matchMapping = await sql`
      SELECT cricapi_match_id
      FROM cricapi_match_mapping
      WHERE fantasy_match_id = ${fantasyMatchId}
    `;

    if (!matchMapping.length) {
      return res.status(404).json({ error: 'No CricAPI match mapping found' });
    }

    const cricapiMatchId = matchMapping[0].cricapi_match_id;

    const apiUrl =
      `https://api.cricapi.com/v1/cricScore?apikey=${process.env.CRICAPI_KEY}`;

    const response = await fetch(apiUrl);
    const cricData = await response.json();

    const match = cricData.data?.find(m => m.id === cricapiMatchId);

    if (!match) {
      return res.status(404).json({
        error: 'Match not found in CricAPI live score response',
        cricapi_match_id: cricapiMatchId
      });
    }

    const t1Short = match.t1?.match(/\[(.*?)\]/)?.[1] || match.t1;
    const t2Short = match.t2?.match(/\[(.*?)\]/)?.[1] || match.t2;

    const t1Score = match.t1s || 'Yet to bat';
    const t2Score = match.t2s || 'Yet to bat';

    const scoreUpdateNote =
      `Updated when ${t1Short} ${t1Score} | ${t2Short} ${t2Score} - ${match.status}`;

    await sql`
      UPDATE fantasy_matches
      SET score_update_note = ${scoreUpdateNote}
      WHERE id = ${fantasyMatchId}
    `;

    return res.status(200).json({
      message: 'Match score note updated successfully',
      fantasy_match_id: fantasyMatchId,
      cricapi_match_id: cricapiMatchId,
      score_update_note: scoreUpdateNote
    });

  } catch (error) {
    console.error('sync-match-score-note error:', error);
    return res.status(500).json({ error: error.message });
  }
}
