
const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

const SUBSTITUTE_BOOSTER_COST  = 100;
const CAPTAIN_BOOSTER_COST     = 300;
const VC_BOOSTER_COST          = 200;

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests allowed.' });
  }

  try {
    const {
      user_id,
      fantasy_match_id,

      // legacy frontend field — kept for backward compatibility
      player_ids,

      // primary player fields
      active_player_ids,
      substitute_player_id,
      use_substitute_booster,

      captain_player_id,
      vice_captain_player_id,

      // NEW booster fields (sent from booster step in the UI)
      use_captain_booster,
      use_vc_booster
    } = req.body;

    // ── Basic presence checks ────────────────────────────────
    if (!user_id || !fantasy_match_id) {
      return res.status(400).json({
        error: 'user_id and fantasy_match_id are required.'
      });
    }

    const userId           = Number(user_id);
    const fantasyMatchId   = Number(fantasy_match_id);
    const captainId        = Number(captain_player_id);
    const viceCaptainId    = Number(vice_captain_player_id);
    const subBoosterOn     = use_substitute_booster === true;
    const captainBoosterOn = use_captain_booster    === true;
    const vcBoosterOn      = use_vc_booster          === true;

    const cleanActivePlayerIds = Array.isArray(active_player_ids)
      ? active_player_ids.map(Number)
      : Array.isArray(player_ids)
        ? player_ids.map(Number)
        : [];

    const substitutePlayerId = substitute_player_id
      ? Number(substitute_player_id)
      : null;

    // ── Player count / duplicate / captain checks ─────────────
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

    // ── Substitute booster basic checks ──────────────────────
    if (subBoosterOn) {
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

    // ── Load and validate the match ───────────────────────────
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

    // ── Load player costs and team codes from DB ──────────────
    const allSelectedPlayerIds = subBoosterOn
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

    const activePlayers = players.filter(p =>
      cleanActivePlayerIds.includes(Number(p.id))
    );

    const substitutePlayer = subBoosterOn
      ? players.find(p => Number(p.id) === substitutePlayerId)
      : null;

    if (activePlayers.length !== 11) {
      return res.status(400).json({
        error: 'Could not validate your 11 active players.'
      });
    }

    if (subBoosterOn && !substitutePlayer) {
      return res.status(400).json({
        error: 'Could not validate substitute player.'
      });
    }

    // ── Max 7 players per team rule ───────────────────────────
    const teamCounts = activePlayers.reduce((acc, p) => {
      acc[p.team_code] = (acc[p.team_code] || 0) + 1;
      return acc;
    }, {});

    if (Object.values(teamCounts).some(count => count > 7)) {
      return res.status(400).json({
        error: 'You can select a maximum of 7 active players from one team.'
      });
    }

    // ── Budget checks ─────────────────────────────────────────
    const totalCoinsUsed = activePlayers.reduce(
      (sum, p) => sum + Number(p.player_cost_coins),
      0
    );

    const totalRosterCoinsUsed = players.reduce(
      (sum, p) => sum + Number(p.player_cost_coins),
      0
    );

    if (totalCoinsUsed > Number(match.budget_coins)) {
      return res.status(400).json({
        error: `Budget exceeded. Used ${totalCoinsUsed.toFixed(2)} of ${Number(match.budget_coins).toFixed(2)} Cr.`
      });
    }

    if (subBoosterOn && totalRosterCoinsUsed > Number(match.budget_coins)) {
      return res.status(400).json({
        error: `Budget exceeded including substitute. Used ${totalRosterCoinsUsed.toFixed(2)} of ${Number(match.budget_coins).toFixed(2)} Cr.`
      });
    }

    // ── Coin balance check for all boosters at once ───────────
    //
    //   We fetch the balance once from the DB and validate the
    //   combined cost of every booster the user selected.
    //   The balance query is the same CTE used by
    //   get-user-coin-balance.js — always trust the DB, never
    //   the value sent by the client.
    //
    const totalBoosterCoinCost =
      (subBoosterOn      ? SUBSTITUTE_BOOSTER_COST : 0) +
      (captainBoosterOn  ? CAPTAIN_BOOSTER_COST    : 0) +
      (vcBoosterOn       ? VC_BOOSTER_COST         : 0);

    if (totalBoosterCoinCost > 0) {
      const balanceRows = await sql`
        WITH earned AS (
          SELECT COALESCE(SUM(total_points), 0) AS total_points_earned
          FROM fantasy_user_match_scores
          WHERE user_id = ${userId}
        ),
        spent AS (
          SELECT COALESCE(SUM(ABS(coins)), 0) AS total_coins_spent
          FROM fantasy_user_coin_ledger
          WHERE user_id          = ${userId}
            AND transaction_type = 'debit'
        )
        SELECT
          earned.total_points_earned - spent.total_coins_spent AS available_coins
        FROM earned, spent
      `;

      const availableCoins = Number(balanceRows[0]?.available_coins || 0);

      if (availableCoins < totalBoosterCoinCost) {
        return res.status(400).json({
          error: `Insufficient coins. You need ${totalBoosterCoinCost} coins for your selected boosters but only have ${availableCoins}.`
        });
      }

      // Granular checks so the error message names the specific booster
      if (subBoosterOn && availableCoins < SUBSTITUTE_BOOSTER_COST) {
        return res.status(400).json({
          error: `You need ${SUBSTITUTE_BOOSTER_COST} coins to use the Substitute Booster.`
        });
      }
      if (captainBoosterOn && availableCoins < CAPTAIN_BOOSTER_COST) {
        return res.status(400).json({
          error: `You need ${CAPTAIN_BOOSTER_COST} coins to use the 3X Captain Booster.`
        });
      }
      if (vcBoosterOn && availableCoins < VC_BOOSTER_COST) {
        return res.status(400).json({
          error: `You need ${VC_BOOSTER_COST} coins to use the 2X Vice-Captain Booster.`
        });
      }
    }

    // ── Upsert the user's team record ────────────────────────
    //   Includes the four new booster columns.
    const teamRows = await sql`
      INSERT INTO fantasy_user_teams
        (
          user_id,
          fantasy_match_id,
          captain_player_id,
          vice_captain_player_id,
          total_coins_used,
          use_captain_booster,
          use_vc_booster,
          captain_booster_cost,
          vc_booster_cost
        )
      VALUES
        (
          ${userId},
          ${fantasyMatchId},
          ${captainId},
          ${viceCaptainId},
          ${totalCoinsUsed},
          ${captainBoosterOn},
          ${vcBoosterOn},
          ${captainBoosterOn ? CAPTAIN_BOOSTER_COST : 0},
          ${vcBoosterOn      ? VC_BOOSTER_COST      : 0}
        )
      ON CONFLICT (user_id, fantasy_match_id)
      DO UPDATE SET
        captain_player_id       = EXCLUDED.captain_player_id,
        vice_captain_player_id  = EXCLUDED.vice_captain_player_id,
        total_coins_used        = EXCLUDED.total_coins_used,
        use_captain_booster     = EXCLUDED.use_captain_booster,
        use_vc_booster          = EXCLUDED.use_vc_booster,
        captain_booster_cost    = EXCLUDED.captain_booster_cost,
        vc_booster_cost         = EXCLUDED.vc_booster_cost,
        submitted_at            = NOW()
      RETURNING id
    `;

    const fantasyUserTeamId = teamRows[0].id;

    // ── Replace player rows ───────────────────────────────────
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

    // ── Substitute player row ─────────────────────────────────
    if (subBoosterOn && substitutePlayer) {
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
    }

    // ── Coin ledger debits and booster records ────────────────
    //
    //   Each purchased booster gets:
    //     1. A row in fantasy_user_coin_ledger  (the debit)
    //     2. A row in fantasy_user_boosters     (the booster record)
    //
    //   Coin debits are written AFTER all DB inserts succeed,
    //   so a mid-flight error never loses coins silently.

    if (subBoosterOn) {
      await sql`
        INSERT INTO fantasy_user_coin_ledger
          (user_id, transaction_type, coins, reason, fantasy_match_id)
        VALUES
          (${userId}, 'debit', ${-SUBSTITUTE_BOOSTER_COST},
           'Substitute Booster activated', ${fantasyMatchId})
      `;
      await sql`
        INSERT INTO fantasy_user_boosters
          (user_id, booster_type, fantasy_match_id, coins_spent, status)
        VALUES
          (${userId}, 'substitute', ${fantasyMatchId},
           ${SUBSTITUTE_BOOSTER_COST}, 'reserved')
        ON CONFLICT DO NOTHING
      `;
    }

    if (captainBoosterOn) {
      await sql`
        INSERT INTO fantasy_user_coin_ledger
          (user_id, transaction_type, coins, reason, fantasy_match_id)
        VALUES
          (${userId}, 'debit', ${-CAPTAIN_BOOSTER_COST},
           '3X Captain Booster activated', ${fantasyMatchId})
      `;
      await sql`
        INSERT INTO fantasy_user_boosters
          (user_id, booster_type, fantasy_match_id, coins_spent, status)
        VALUES
          (${userId}, 'captain_3x', ${fantasyMatchId},
           ${CAPTAIN_BOOSTER_COST}, 'active')
        ON CONFLICT DO NOTHING
      `;
    }

    if (vcBoosterOn) {
      await sql`
        INSERT INTO fantasy_user_coin_ledger
          (user_id, transaction_type, coins, reason, fantasy_match_id)
        VALUES
          (${userId}, 'debit', ${-VC_BOOSTER_COST},
           '2X Vice-Captain Booster activated', ${fantasyMatchId})
      `;
      await sql`
        INSERT INTO fantasy_user_boosters
          (user_id, booster_type, fantasy_match_id, coins_spent, status)
        VALUES
          (${userId}, 'vc_2x', ${fantasyMatchId},
           ${VC_BOOSTER_COST}, 'active')
        ON CONFLICT DO NOTHING
      `;
    }

    // ── Success response ──────────────────────────────────────
    return res.status(200).json({
      success:                   true,
      fantasy_user_team_id:      fantasyUserTeamId,
      selected_players:          subBoosterOn ? 12 : 11,
      active_players:            11,
      substitute_player_id:      subBoosterOn ? substitutePlayerId : null,
      substitute_booster_used:   subBoosterOn,
      captain_booster_used:      captainBoosterOn,
      vc_booster_used:           vcBoosterOn,
      total_booster_coins_spent: totalBoosterCoinCost,
      total_coins_used:          totalCoinsUsed,
      coins_remaining:           Number(match.budget_coins) - totalCoinsUsed
    });

  } catch (error) {
    console.error('submit-fantasy-team-v2 error:', error);
    return res.status(500).json({ error: error.message });
  }
};
