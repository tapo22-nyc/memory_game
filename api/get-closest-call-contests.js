const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Only GET requests allowed.' });
  }

  try {
    const contests = await sql`
      SELECT
        c.id,
        c.contest_name,
        c.contest_type,
        c.description,
        c.start_time,
        c.end_time,
        c.status,
        c.created_at,
        c.updated_at
      FROM closest_call_contests c
      ORDER BY c.id DESC
    `;

    // For each contest, fetch linked matches
    const contestIds = contests.map(function(c) { return c.id; });

    let matchesByContest = {};
    if (contestIds.length > 0) {
      const allMatches = await sql`
        SELECT
          id,
          match_title,
          team_1,
          team_2,
          match_date,
          status,
          contest_id
        FROM closest_call_matches
        WHERE contest_id = ANY(${contestIds})
        ORDER BY match_date ASC, id ASC
      `;
      for (const m of allMatches) {
        if (!matchesByContest[m.contest_id]) matchesByContest[m.contest_id] = [];
        matchesByContest[m.contest_id].push(m);
      }
    }

    const result = contests.map(function(c) {
      return Object.assign({}, c, { matches: matchesByContest[c.id] || [] });
    });

    return res.status(200).json({ contests: result });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
