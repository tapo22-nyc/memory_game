import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

function normalize(text = '') {
  return text.toLowerCase().trim();
}

function matchContainsTeams(match, teamA, teamB) {
  const name = normalize(match.name || '');
  const teams = (match.teams || []).map(t => normalize(t)).join(' ');

  const combined = `${name} ${teams}`;

  return (
    combined.includes(normalize(teamA)) &&
    combined.includes(normalize(teamB))
  );
}

async function fetchCricApi(endpoint, offset = 0) {
  const url = `https://api.cricapi.com/v1/${endpoint}?apikey=${process.env.CRICAPI_KEY}&offset=${offset}`;
  const response = await fetch(url);
  return response.json();
}

export default async function handler(req, res) {
  try {
    const {
      fantasy_match_id,
      team_a,
      team_b,
      save = 'false'
    } = req.query;

    if (!team_a || !team_b) {
      return res.status(400).json({
        error: 'Missing team_a or team_b',
        example: '/api/get-upcoming-match-id?team_a=Chennai&team_b=Sunrisers'
      });
    }

    const endpointsToCheck = ['currentMatches', 'matches'];
    const offsetsToCheck = [0, 100, 200, 300, 400];

    let foundMatch = null;
    let searched = [];

    for (const endpoint of endpointsToCheck) {
      for (const offset of offsetsToCheck) {
        const data = await fetchCricApi(endpoint, offset);

        searched.push({
          endpoint,
          offset,
          status: data.status,
          result_count: data.data?.length || 0
        });

        const matches = data.data || [];

        foundMatch = matches.find(match =>
          matchContainsTeams(match, team_a, team_b)
        );

        if (foundMatch) {
          break;
        }
      }

      if (foundMatch) {
        break;
      }
    }

    if (!foundMatch) {
      return res.status(404).json({
        message: 'No matching CricAPI match found yet',
        searched_for: {
          team_a,
          team_b
        },
        searched
      });
    }

    let savedToDb = false;

    if (save === 'true') {
      if (!fantasy_match_id) {
        return res.status(400).json({
          error: 'fantasy_match_id is required when save=true'
        });
      }

      await sql`
        INSERT INTO cricapi_match_mapping
        (fantasy_match_id, cricapi_match_id)
        VALUES
        (${Number(fantasy_match_id)}, ${foundMatch.id})
        ON CONFLICT (fantasy_match_id)
        DO UPDATE SET cricapi_match_id = EXCLUDED.cricapi_match_id
      `;

      savedToDb = true;
    }

    return res.status(200).json({
      message: 'CricAPI match found',
      saved_to_db: savedToDb,
      fantasy_match_id: fantasy_match_id || null,
      cricapi_match_id: foundMatch.id,
      match_name: foundMatch.name,
      status: foundMatch.status,
      date: foundMatch.date,
      dateTimeGMT: foundMatch.dateTimeGMT,
      teams: foundMatch.teams,
      venue: foundMatch.venue,
      raw_match: foundMatch
    });

  } catch (error) {
    console.error('get-upcoming-match-id error:', error);
    return res.status(500).json({ error: error.message });
  }
}
