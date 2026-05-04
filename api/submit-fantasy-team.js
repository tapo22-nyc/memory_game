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

    if (!user_id || !fantasy_match_id || !Array.isArray(player_ids)) {
      return res.status(400).json({ error: 'user_id, fantasy_match_id, and player_ids are required.' });
    }

    if (player_ids.length !== 11) {
      return res.status(400).json({ error: 'You must select exactly 11 players.' });
    }

    if (!player_ids.includes(captain_player_id)) {
      return res.status(400).json({ error: 'Captain must be one of your selected players.' });
    }

    if (!player_ids.includes(vice_captain_player_id)) {
      return res.status(400).json({ error: 'Vice-captain must be one of your selected players.' });
    }

    if (captain_player_id === vice_captain_player_id) {
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
      return res.status(400).json({ error: 'This fantasy contest is not open.' });
    }

    const players = await sql`
      SELECT id, player_cost_coins
      FROM fantasy_players
      WHERE fantasy_match_id = ${Number(fantasy_match_id)}
      AND id = ANY(${player_ids.map(Number)})
    `;

    if (players.length !== 11) {
      return res.status(400).json({ error: 'Some selected players are invalid for this match.' });
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
        (${Number(user_id)}, ${Number(fantasy_match_id)}, ${Number(captain_player_id)}, ${Number(vice_captain_player_id)}, ${totalCoinsUsed})
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
