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
    const cricapiMatchId = req.query.cricapi_match_id;

    if (!cricapiMatchId) {
      return res.status(400).json({ error: 'Missing cricapi_match_id' });
    }

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

    const matchName = cricData.data?.name || null;
    const matchDate = cricData.data?.date || null;
    const scorecards = cricData.data?.scorecard || [];

    const playerStats = {};

    function getPlayer(player, teamName) {
      const playerId = player?.id;
      const playerName = player?.name;

      if (!playerId || !playerName) return null;

      if (!playerStats[playerId]) {
        playerStats[playerId] = {
          cricapi_match_id: cricapiMatchId,
          match_name: matchName,
          match_date: matchDate,
          team_name: teamName,
          player_cricapi_id: playerId,
          player_name: playerName,
          ...emptyStats()
        };
      }

      return playerStats[playerId];
    }

    for (const innings of scorecards) {
      const inningsName = innings.inning || '';
      const teamName =
        cricData.data?.teams?.find(team =>
          inningsName.toLowerCase().includes(team.toLowerCase().split(' ')[0])
        ) || inningsName;

      for (const bat of innings.batting || []) {
        const stats = getPlayer(bat.batsman, teamName);
        if (!stats) continue;

        stats.runs = Number(bat.r || 0);
        stats.balls_faced = Number(bat.b || 0);
        stats.fours = Number(bat['4s'] || 0);
        stats.sixes = Number(bat['6s'] || 0);
        stats.strike_rate = Number(bat.sr || 0);
      }

      for (const bowl of innings.bowling || []) {
        const bowlingTeam =
          cricData.data?.teams?.find(team => team !== teamName) || null;

        const stats = getPlayer(bowl.bowler, bowlingTeam);
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
        const fieldingTeam =
          cricData.data?.teams?.find(team => team !== teamName) || null;

        const stats = getPlayer(field.catcher, fieldingTeam);
        if (!stats) continue;

        stats.catches += Number(field.catch || 0);
        stats.stumpings += Number(field.stumped || 0);
        stats.runouts += Number(field.runout || 0);
      }
    }

    const rows = Object.values(playerStats);

    for (const p of rows) {
      await sql`
        INSERT INTO player_match_history
        (
          cricapi_match_id,
          match_name,
          match_date,
          team_name,
          player_cricapi_id,
          player_name,
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
          ${p.cricapi_match_id},
          ${p.match_name},
          ${p.match_date},
          ${p.team_name},
          ${p.player_cricapi_id},
          ${p.player_name},
          ${p.runs},
          ${p.balls_faced},
          ${p.fours},
          ${p.sixes},
          ${p.strike_rate},
          ${p.overs_bowled},
          ${p.maidens},
          ${p.runs_conceded},
          ${p.wickets},
          ${p.no_balls},
          ${p.wides},
          ${p.economy_rate},
          ${p.catches},
          ${p.stumpings},
          ${p.runouts}
        )
        ON CONFLICT (cricapi_match_id, player_cricapi_id)
        DO UPDATE SET
          match_name = EXCLUDED.match_name,
          match_date = EXCLUDED.match_date,
          team_name = EXCLUDED.team_name,
          player_name = EXCLUDED.player_name,
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
          updated_at = NOW()
      `;
    }

    return res.status(200).json({
      success: true,
      cricapi_match_id: cricapiMatchId,
      match_name: matchName,
      inserted_rows: rows.length
    });

  } catch (error) {
    console.error('sync-match-history error:', error);
    return res.status(500).json({ error: error.message });
  }
}
