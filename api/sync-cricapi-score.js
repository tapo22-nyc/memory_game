import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

function emptyStats() {
  return {
    runs: 0,
    balls_faced: 0,
    fours: 0,
    sixes: 0,
    strike_rate: 0,
    overs_bowled: 0,
    maidens: 0,
    runs_conceded: 0,
    wickets: 0,
    no_balls: 0,
    wides: 0,
    economy_rate: 0,
    catches: 0,
    stumpings: 0,
    runouts: 0
  };
}

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
      `https://api.cricapi.com/v1/match_scorecard?apikey=${process.env.CRICAPI_KEY}&id=${cricapiMatchId}`;

    const response = await fetch(apiUrl);
    const cricData = await response.json();

    if (cricData.status !== 'success') {
      return res.status(500).json({
        error: 'CricAPI did not return success',
        cric_response: cricData
      });
    }

    const playerMappings = await sql`
      SELECT player_id, cricapi_player_name
      FROM cricapi_player_mapping
      WHERE fantasy_match_id = ${fantasyMatchId}
    `;

    const nameToPlayerId = {};
    playerMappings.forEach(p => {
      nameToPlayerId[p.cricapi_player_name.trim().toLowerCase()] = p.player_id;
    });

    const playerStats = {};

    function getPlayer(name) {
      const cleanName = name?.trim();
      if (!cleanName) return null;

      if (!playerStats[cleanName]) {
        playerStats[cleanName] = emptyStats();
      }

      return playerStats[cleanName];
    }

    const scorecards = cricData.data?.scorecard || [];

    for (const innings of scorecards) {
      for (const bat of innings.batting || []) {
        const name = bat.batsman?.name;
        const stats = getPlayer(name);
        if (!stats) continue;

        stats.runs = Number(bat.r || 0);
        stats.balls_faced = Number(bat.b || 0);
        stats.fours = Number(bat['4s'] || 0);
        stats.sixes = Number(bat['6s'] || 0);
        stats.strike_rate = Number(bat.sr || 0);
      }

      for (const bowl of innings.bowling || []) {
        const name = bowl.bowler?.name;
        const stats = getPlayer(name);
        if (!stats) continue;

        stats.overs_bowled = Number(bowl.o || 0);
        stats.maidens = Number(bowl.m || 0);
        stats.runs_conceded = Number(bowl.r || 0);
        stats.wickets = Number(bowl.w || 0);
        stats.no_balls = Number(bowl.nb || 0);
        stats.wides = Number(bowl.wd || 0);
        stats.economy_rate = Number(bowl.eco || 0);
      }

      for (const field of innings.catching || []) {
        const name = field.catcher?.name;
        const stats = getPlayer(name);
        if (!stats) continue;

        stats.catches += Number(field.catch || 0);
        stats.stumpings += Number(field.stumped || 0);
        stats.runouts += Number(field.runout || 0);
      }
    }

    const insertedPlayers = [];
    const unmappedPlayers = [];

    for (const [playerName, stats] of Object.entries(playerStats)) {
      const playerId = nameToPlayerId[playerName.trim().toLowerCase()];

      if (!playerId) {
        unmappedPlayers.push(playerName);
        continue;
      }

      await sql`
        INSERT INTO fantasy_player_match_stats
        (
          fantasy_match_id,
          player_id,
          runs,
          balls_faced,
          fours,
          sixes,
          strike_rate,
          overs_bowled,
          maidens,
          runs_conceded,
          wickets,
          no_balls,
          wides,
          economy_rate,
          catches,
          stumpings,
          runouts
        )
        VALUES
        (
          ${fantasyMatchId},
          ${playerId},
          ${stats.runs},
          ${stats.balls_faced},
          ${stats.fours},
          ${stats.sixes},
          ${stats.strike_rate},
          ${stats.overs_bowled},
          ${stats.maidens},
          ${stats.runs_conceded},
          ${stats.wickets},
          ${stats.no_balls},
          ${stats.wides},
          ${stats.economy_rate},
          ${stats.catches},
          ${stats.stumpings},
          ${stats.runouts}
        )
        ON CONFLICT (fantasy_match_id, player_id)
        DO UPDATE SET
          runs = EXCLUDED.runs,
          balls_faced = EXCLUDED.balls_faced,
          fours = EXCLUDED.fours,
          sixes = EXCLUDED.sixes,
          strike_rate = EXCLUDED.strike_rate,
          overs_bowled = EXCLUDED.overs_bowled,
          maidens = EXCLUDED.maidens,
          runs_conceded = EXCLUDED.runs_conceded,
          wickets = EXCLUDED.wickets,
          no_balls = EXCLUDED.no_balls,
          wides = EXCLUDED.wides,
          economy_rate = EXCLUDED.economy_rate,
          catches = EXCLUDED.catches,
          stumpings = EXCLUDED.stumpings,
          runouts = EXCLUDED.runouts,
          updated_at = CURRENT_TIMESTAMP
      `;

      insertedPlayers.push(playerName);
    }

    await sql`
      UPDATE fantasy_player_match_stats s
      SET fantasy_points =
          s.runs * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'RUN' AND is_active = TRUE), 1)
        + s.fours * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'FOUR' AND is_active = TRUE), 4)
        + s.sixes * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'SIX' AND is_active = TRUE), 6)

        + CASE
            WHEN s.balls_faced >= 10 AND s.strike_rate > 200
              THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'SR_ABOVE_200' AND is_active = TRUE), 20)
            WHEN s.balls_faced >= 10 AND s.strike_rate >= 150 AND s.strike_rate <= 200
              THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'SR_150_200' AND is_active = TRUE), 10)
            ELSE 0
          END

        + s.wickets * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'WICKET' AND is_active = TRUE), 25)
        + s.maidens * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'MAIDEN' AND is_active = TRUE), 15)

        + CASE
            WHEN s.overs_bowled >= 2 AND s.economy_rate <= 5
              THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_LE_5' AND is_active = TRUE), 20)
            WHEN s.overs_bowled >= 2 AND s.economy_rate > 5 AND s.economy_rate <= 7
              THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_5_7' AND is_active = TRUE), 10)
            WHEN s.overs_bowled >= 2 AND s.economy_rate > 7 AND s.economy_rate <= 9
              THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_7_9' AND is_active = TRUE), 5)
            WHEN s.overs_bowled >= 2 AND s.economy_rate > 9 AND s.economy_rate < 11
              THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_9_11' AND is_active = TRUE), -5)
            WHEN s.overs_bowled >= 2 AND s.economy_rate >= 11
              THEN COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'ECON_GE_11' AND is_active = TRUE), -10)
            ELSE 0
          END

        + s.catches * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'CATCH' AND is_active = TRUE), 8)
        + s.stumpings * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'STUMPING' AND is_active = TRUE), 12)
        + s.runouts * COALESCE((SELECT points FROM fantasy_scoring_rules WHERE rule_code = 'RUNOUT' AND is_active = TRUE), 12)
      WHERE s.fantasy_match_id = ${fantasyMatchId}
    `;

    return res.status(200).json({
      message: 'Live CricAPI stats synced successfully',
      fantasy_match_id: fantasyMatchId,
      inserted_count: insertedPlayers.length,
      inserted_players: insertedPlayers,
      unmapped_players: unmappedPlayers
    });

  } catch (error) {
    console.error('sync-cricapi-score error:', error);
    return res.status(500).json({ error: error.message });
  }
}
