const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests allowed.' });
  }

  try {
    const {
      user_id,
      fantasy_match_id,
      player_ids,
      captain_player_id,
      vice_captain_player_id
    } = req.body;

    const cleanPlayerIds = Array.isArray(player_ids)
      ? player_ids.map(Number)
      : [];

    const captainId = Number(captain_player_id);
    const viceCaptainId = Number(vice_captain_player_id);

    if (!user_id || !fantasy_match_id || !Array.isArray(player_ids)) {
      return res.status(400).json({
        error: 'user_id, fantasy_match_id, and player_ids are required.'
      });
    }

    if (cleanPlayerIds.length !== 11) {
      return res.status(400).json({ error: 'You must select exactly 11 players.' });
    }

    if (!cleanPlayerIds.includes(captainId)) {
      return res.status(400).json({ error: 'Captain must be one of your selected players.' });
    }

    if (!cleanPlayerIds.includes(viceCaptainId)) {
      return res.status(400).json({ error: 'Vice-captain must be one of your selected players.' });
    }

    if (captainId === viceCaptainId) {
      return res.status(400).json({ error: 'Captain and vice-captain cannot be the same player.' });
    }

    const matchRows = await sql`
      SELECT *
      FROM fantasy_matches
      WHERE id = ${Number(fantasy_match_id)}
      LIMIT 1
    `;

    const match = matchRows[0];

    if (!match) {
      return res.status(404).json({ error: 'Fantasy match not found.' });
    }

    if (String(match.status).toLowerCase() !== 'open') {
      return res.status(400).json({ error: 'Team selection is locked for this match.' });
    }

    const players = await sql`
      SELECT
        pm.id,
        pm.player_cost_coins,
        pm.team_code
      FROM fantasy_match_players fmp
      JOIN ipl_player_master pm
        ON pm.id = fmp.player_id
      WHERE fmp.fantasy_match_id = ${Number(fantasy_match_id)}
        AND pm.id = ANY(${cleanPlayerIds})
    `;

    if (players.length !== 11) {
      return res.status(400).json({
        error: 'Some selected players are invalid for this match.'
      });
    }

    const teamCounts = players.reduce((acc, player) => {
      acc[player.team_code] = (acc[player.team_code] || 0) + 1;
      return acc;
    }, {});

    if (Object.values(teamCounts).some(count => count > 7)) {
      return res.status(400).json({
        error: 'You can select a maximum of 7 players from one team.'
      });
    }

    const totalCoinsUsed = players.reduce(
      (sum, player) => sum + Number(player.player_cost_coins),
      0
    );

    if (totalCoinsUsed > Number(match.budget_coins)) {
      return res.status(400).json({
        error: `Budget exceeded. You used ${totalCoinsUsed.toFixed(2)} coins out of ${Number(match.budget_coins).toFixed(2)}.`
      });
    }

    const teamRows = await sql`
      INSERT INTO fantasy_user_teams
        (user_id, fantasy_match_id, captain_player_id, vice_captain_player_id, total_coins_used)
      VALUES
        (${Number(user_id)}, ${Number(fantasy_match_id)}, ${captainId}, ${viceCaptainId}, ${totalCoinsUsed})
      ON CONFLICT (user_id, fantasy_match_id)
      DO UPDATE SET
        captain_player_id = EXCLUDED.captain_player_id,
        vice_captain_player_id = EXCLUDED.vice_captain_player_id,
        total_coins_used = EXCLUDED.total_coins_used,
        submitted_at = NOW()
      RETURNING id
    `;

    const fantasyUserTeamId = teamRows[0].id;

    await sql`
      DELETE FROM fantasy_user_team_players
      WHERE fantasy_user_team_id = ${fantasyUserTeamId}
    `;

    for (const player of players) {
      await sql`
        INSERT INTO fantasy_user_team_players
          (fantasy_user_team_id, player_id, player_cost_coins)
        VALUES
          (${fantasyUserTeamId}, ${Number(player.id)}, ${Number(player.player_cost_coins)})
      `;
    }

    return res.status(200).json({
      success: true,
      fantasy_user_team_id: fantasyUserTeamId,
      selected_players: 11,
      total_coins_used: totalCoinsUsed,
      coins_remaining: Number(match.budget_coins) - totalCoinsUsed
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
