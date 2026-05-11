const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

const SUBSTITUTE_BOOSTER_COST = 100;

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests allowed.' });
  }

  try {
    const {
      user_id,
      fantasy_match_id,

      // old frontend support
      player_ids,

      // new substitute frontend support
      active_player_ids,
      substitute_player_id,
      use_substitute_booster,

      captain_player_id,
      vice_captain_player_id
    } = req.body;

    if (!user_id || !fantasy_match_id) {
      return res.status(400).json({
        error: 'user_id and fantasy_match_id are required.'
      });
    }

    const userId = Number(user_id);
    const fantasyMatchId = Number(fantasy_match_id);
    const captainId = Number(captain_player_id);
    const viceCaptainId = Number(vice_captain_player_id);
    const boosterEnabled = use_substitute_booster === true;

    const cleanActivePlayerIds = Array.isArray(active_player_ids)
      ? active_player_ids.map(Number)
      : Array.isArray(player_ids)
        ? player_ids.map(Number)
        : [];

    const substitutePlayerId = substitute_player_id
      ? Number(substitute_player_id)
      : null;

    if (cleanActivePlayerIds.length !== 11) {
      return res.status(400).json({
        error: 'You must select exactly 11 active players.'
      });
    }

    if (new Set(cleanActivePlayerIds).size !== 11) {
      return res.status(400).json({
        error: 'Duplicate active players are not allowed.'
      });
    }

    if (!cleanActivePlayerIds.includes(captainId)) {
      return res.status(400).json({
        error: 'Captain must be one of your 11 active players.'
      });
    }

    if (!cleanActivePlayerIds.includes(viceCaptainId)) {
      return res.status(400).json({
        error: 'Vice-captain must be one of your 11 active players.'
      });
    }

    if (captainId === viceCaptainId) {
      return res.status(400).json({
        error: 'Captain and vice-captain cannot be the same player.'
      });
    }

    if (boosterEnabled) {
      if (!substitutePlayerId) {
        return res.status(400).json({
          error: 'Substitute player is required when Substitute Booster is active.'
        });
      }

      if (cleanActivePlayerIds.includes(substitutePlayerId)) {
        return res.status(400).json({
          error: 'Substitute player cannot already be in your active 11.'
        });
      }
    }

    const matchRows = await sql`
      SELECT *
      FROM fantasy_matches
      WHERE id = ${fantasyMatchId}
      LIMIT 1
    `;

    const match = matchRows[0];

    if (!match) {
      return res.status(404).json({ error: 'Fantasy match not found.' });
    }

    if (String(match.status).toLowerCase() !== 'open') {
      return res.status(400).json({
        error: 'Team selection is locked for this match.'
      });
    }

    const allSelectedPlayerIds = boosterEnabled
      ? [...cleanActivePlayerIds, substitutePlayerId]
      : cleanActivePlayerIds;

    const players = await sql`
      SELECT
        pm.id,
        pm.player_cost_coins,
        pm.team_code
      FROM fantasy_match_players fmp
      JOIN ipl_player_master pm
        ON pm.id = fmp.player_id
      WHERE fmp.fantasy_match_id = ${fantasyMatchId}
        AND pm.id = ANY(${allSelectedPlayerIds})
    `;

    if (players.length !== allSelectedPlayerIds.length) {
      return res.status(400).json({
        error: 'Some selected players are invalid for this match.'
      });
    }

    const activePlayers = players.filter(player =>
      cleanActivePlayerIds.includes(Number(player.id))
    );

    const substitutePlayer = boosterEnabled
      ? players.find(player => Number(player.id) === substitutePlayerId)
      : null;

    if (activePlayers.length !== 11) {
      return res.status(400).json({
        error: 'Could not validate your 11 active players.'
      });
    }

    if (boosterEnabled && !substitutePlayer) {
      return res.status(400).json({
        error: 'Could not validate substitute player.'
      });
    }

    const teamCounts = activePlayers.reduce((acc, player) => {
      acc[player.team_code] = (acc[player.team_code] || 0) + 1;
      return acc;
    }, {});

    if (Object.values(teamCounts).some(count => count > 7)) {
      return res.status(400).json({
        error: 'You can select a maximum of 7 active players from one team.'
      });
    }

    const totalCoinsUsed = activePlayers.reduce(
      (sum, player) => sum + Number(player.player_cost_coins),
      0
    );

    if (totalCoinsUsed > Number(match.budget_coins)) {
      return res.status(400).json({
        error: `Budget exceeded. You used ${totalCoinsUsed.toFixed(2)} coins out of ${Number(match.budget_coins).toFixed(2)}.`
      });
    }

    if (boosterEnabled) {
      const balanceRows = await sql`
        WITH earned AS (
          SELECT COALESCE(SUM(total_points), 0) AS total_points_earned
          FROM fantasy_user_match_scores
          WHERE user_id = ${userId}
        ),
        spent AS (
          SELECT COALESCE(SUM(ABS(coins)), 0) AS total_coins_spent
          FROM fantasy_user_coin_ledger
          WHERE user_id = ${userId}
            AND transaction_type = 'debit'
        )
        SELECT
          earned.total_points_earned - spent.total_coins_spent AS available_coins
        FROM earned, spent
      `;

      const availableCoins = Number(balanceRows[0]?.available_coins || 0);

      if (availableCoins < SUBSTITUTE_BOOSTER_COST) {
        return res.status(400).json({
          error: `You need ${SUBSTITUTE_BOOSTER_COST} coins to use Substitute Booster.`
        });
      }
    }

    const teamRows = await sql`
      INSERT INTO fantasy_user_teams
        (
          user_id,
          fantasy_match_id,
          captain_player_id,
          vice_captain_player_id,
          total_coins_used
        )
      VALUES
        (
          ${userId},
          ${fantasyMatchId},
          ${captainId},
          ${viceCaptainId},
          ${totalCoinsUsed}
        )
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

    for (const player of activePlayers) {
      await sql`
        INSERT INTO fantasy_user_team_players
          (
            fantasy_user_team_id,
            player_id,
            player_cost_coins,
            player_slot,
            is_active,
            activated_at,
            deactivated_at
          )
        VALUES
          (
            ${fantasyUserTeamId},
            ${Number(player.id)},
            ${Number(player.player_cost_coins)},
            'active',
            TRUE,
            CURRENT_TIMESTAMP,
            NULL
          )
      `;
    }

    if (boosterEnabled && substitutePlayer) {
      await sql`
        INSERT INTO fantasy_user_team_players
          (
            fantasy_user_team_id,
            player_id,
            player_cost_coins,
            player_slot,
            is_active,
            activated_at,
            deactivated_at
          )
        VALUES
          (
            ${fantasyUserTeamId},
            ${Number(substitutePlayer.id)},
            ${Number(substitutePlayer.player_cost_coins)},
            'substitute',
            FALSE,
            NULL,
            NULL
          )
      `;

      await sql`
        INSERT INTO fantasy_user_coin_ledger
          (
            user_id,
            transaction_type,
            coins,
            reason,
            fantasy_match_id
          )
        VALUES
          (
            ${userId},
            'debit',
            ${-SUBSTITUTE_BOOSTER_COST},
            'Substitute Booster activated',
            ${fantasyMatchId}
          )
      `;

      await sql`
        INSERT INTO fantasy_user_boosters
          (
            user_id,
            booster_type,
            fantasy_match_id,
            coins_spent,
            status
          )
        VALUES
          (
            ${userId},
            'substitute',
            ${fantasyMatchId},
            ${SUBSTITUTE_BOOSTER_COST},
            'reserved'
          )
      `;
    }

    return res.status(200).json({
      success: true,
      fantasy_user_team_id: fantasyUserTeamId,
      selected_players: boosterEnabled ? 12 : 11,
      active_players: 11,
      substitute_player_id: boosterEnabled ? substitutePlayerId : null,
      substitute_booster_used: boosterEnabled,
      booster_cost: boosterEnabled ? SUBSTITUTE_BOOSTER_COST : 0,
      total_coins_used: totalCoinsUsed,
      coins_remaining: Number(match.budget_coins) - totalCoinsUsed
    });

  } catch (error) {
    console.error('submit-fantasy-team error:', error);
    return res.status(500).json({ error: error.message });
  }
};
