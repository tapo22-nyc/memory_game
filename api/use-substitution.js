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
      player_out_id,
      player_in_id
    } = req.body;

    if (!user_id || !fantasy_match_id || !player_out_id || !player_in_id) {
      return res.status(400).json({
        error: 'user_id, fantasy_match_id, player_out_id, and player_in_id are required.'
      });
    }

    const userId = Number(user_id);
    const fantasyMatchId = Number(fantasy_match_id);
    const playerOutId = Number(player_out_id);
    const playerInId = Number(player_in_id);

    if (playerOutId === playerInId) {
      return res.status(400).json({
        error: 'Player out and player in cannot be the same.'
      });
    }

    const matchRows = await sql`
      SELECT id, status
      FROM fantasy_matches
      WHERE id = ${fantasyMatchId}
      LIMIT 1
    `;

    const match = matchRows[0];

    if (!match) {
      return res.status(404).json({ error: 'Fantasy match not found.' });
    }

    const status = String(match.status || '').toLowerCase();

    if (!['open', 'locked'].includes(status)) {
      return res.status(400).json({
        error: 'Substitution is not allowed after the match is closed.'
      });
    }

    const teamRows = await sql`
      SELECT *
      FROM fantasy_user_teams
      WHERE user_id = ${userId}
        AND fantasy_match_id = ${fantasyMatchId}
      LIMIT 1
    `;

    const team = teamRows[0];

    if (!team) {
      return res.status(404).json({
        error: 'No fantasy team found for this user and match.'
      });
    }

    if (
      Number(team.captain_player_id) === playerOutId ||
      Number(team.vice_captain_player_id) === playerOutId
    ) {
      return res.status(400).json({
        error: 'Captain or vice-captain cannot be substituted out in this version.'
      });
    }

    const boosterRows = await sql`
      SELECT *
      FROM fantasy_user_boosters
      WHERE user_id = ${userId}
        AND fantasy_match_id = ${fantasyMatchId}
        AND booster_type = 'substitute'
        AND status = 'reserved'
      ORDER BY created_at DESC
      LIMIT 1
    `;

    const booster = boosterRows[0];

    if (!booster) {
      return res.status(400).json({
        error: 'No active Substitute Booster found for this match.'
      });
    }

    const existingSubRows = await sql`
      SELECT *
      FROM fantasy_user_substitutions
      WHERE user_id = ${userId}
        AND fantasy_match_id = ${fantasyMatchId}
      LIMIT 1
    `;

    if (existingSubRows.length) {
      return res.status(400).json({
        error: 'You have already used your substitution for this match.'
      });
    }

    const playerOutRows = await sql`
      SELECT *
      FROM fantasy_user_team_players
      WHERE fantasy_user_team_id = ${Number(team.id)}
        AND player_id = ${playerOutId}
        AND player_slot = 'active'
        AND is_active = TRUE
      LIMIT 1
    `;

    if (!playerOutRows.length) {
      return res.status(400).json({
        error: 'Selected player out is not currently active in your team.'
      });
    }

    const playerInRows = await sql`
      SELECT *
      FROM fantasy_user_team_players
      WHERE fantasy_user_team_id = ${Number(team.id)}
        AND player_id = ${playerInId}
        AND player_slot = 'substitute'
        AND is_active = FALSE
      LIMIT 1
    `;

    if (!playerInRows.length) {
      return res.status(400).json({
        error: 'Selected player in is not your saved substitute.'
      });
    }

    const frozenRows = await sql`
      SELECT COALESCE(fantasy_points, 0) AS frozen_points
      FROM fantasy_player_match_stats
      WHERE fantasy_match_id = ${fantasyMatchId}
        AND player_id = ${playerOutId}
      LIMIT 1
    `;

    const frozenPoints = Number(frozenRows[0]?.frozen_points || 0);

    await sql`
      INSERT INTO fantasy_user_substitutions
        (
          user_id,
          fantasy_match_id,
          fantasy_user_team_id,
          player_out_id,
          player_in_id,
          player_out_frozen_points,
          substituted_at
        )
      VALUES
        (
          ${userId},
          ${fantasyMatchId},
          ${Number(team.id)},
          ${playerOutId},
          ${playerInId},
          ${frozenPoints},
          CURRENT_TIMESTAMP
        )
    `;

    await sql`
      UPDATE fantasy_user_team_players
      SET
        is_active = FALSE,
        deactivated_at = CURRENT_TIMESTAMP
      WHERE fantasy_user_team_id = ${Number(team.id)}
        AND player_id = ${playerOutId}
    `;

    await sql`
      UPDATE fantasy_user_team_players
      SET
        is_active = TRUE,
        player_slot = 'active',
        activated_at = CURRENT_TIMESTAMP,
        deactivated_at = NULL
      WHERE fantasy_user_team_id = ${Number(team.id)}
        AND player_id = ${playerInId}
    `;

    await sql`
      UPDATE fantasy_user_boosters
      SET
        status = 'used',
        used_at = CURRENT_TIMESTAMP
      WHERE id = ${Number(booster.id)}
    `;

    return res.status(200).json({
      success: true,
      message: 'Substitution completed successfully.',
      fantasy_user_team_id: Number(team.id),
      player_out_id: playerOutId,
      player_in_id: playerInId,
      player_out_frozen_points: frozenPoints
    });

  } catch (error) {
    console.error('use-substitution error:', error);
    return res.status(500).json({
      error: error.message || 'Could not complete substitution.'
    });
  }
};
