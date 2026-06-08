
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

    // Unified join: handles both ipl_player_master and cricket_player_pool.
    const players = await sql`
      SELECT
        fmp.player_id                                           AS id,
        COALESCE(ipm.player_cost_coins, cpp.player_cost_coins) AS player_cost_coins,
        COALESCE(ipm.team_code,         cpp.country)           AS team_code
      FROM fantasy_match_players fmp
      LEFT JOIN ipl_player_master ipm
        ON ipm.id = fmp.player_id
        AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
      LEFT JOIN cricket_player_pool cpp
        ON cpp.id = fmp.player_id
        AND fmp.player_source = 'cricket'
      WHERE fmp.fantasy_match_id = ${fantasyMatchId}
        AND fmp.player_id = ANY(${allSelectedPlayerIds})
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
        error: `Budget exceeded. Used $${totalCoinsUsed.toLocaleString('en-US')} of $${Number(match.budget_coins).toLocaleString('en-US')}.`
      });
    }

    if (subBoosterOn && totalRosterCoinsUsed > Number(match.budget_coins)) {
      return res.status(400).json({
        error: `Budget exceeded including substitute. Used $${totalRosterCoinsUsed.toLocaleString('en-US')} of $${Number(match.budget_coins).toLocaleString('en-US')}.`
      });
    }

    // ── Check which boosters are already paid for this match ──
    //
    //   This prevents duplicate coin deductions when a user edits
    //   their team after already purchasing a booster.
    //
    const existingBoostersRows = await sql`
      SELECT booster_type, status, coins_spent
      FROM fantasy_user_boosters
      WHERE user_id          = ${userId}
        AND fantasy_match_id = ${fantasyMatchId}
        AND status IN ('active', 'reserved')
    `;

    const captainAlreadyPaid = existingBoostersRows.some(b => b.booster_type === 'captain_3x');
    const vcAlreadyPaid      = existingBoostersRows.some(b => b.booster_type === 'vc_2x');
    const subAlreadyPaid     = existingBoostersRows.some(b => b.booster_type === 'substitute');

    // Costs for newly added boosters only
    const newSubCost     = subBoosterOn     && !subAlreadyPaid     ? SUBSTITUTE_BOOSTER_COST : 0;
    const newCaptainCost = captainBoosterOn && !captainAlreadyPaid ? CAPTAIN_BOOSTER_COST    : 0;
    const newVCCost      = vcBoosterOn      && !vcAlreadyPaid      ? VC_BOOSTER_COST         : 0;
    const totalNewBoosterCost = newSubCost + newCaptainCost + newVCCost;

    // Refunds for removed boosters
    const subRefund     = !subBoosterOn     && subAlreadyPaid     ? SUBSTITUTE_BOOSTER_COST : 0;
    const captainRefund = !captainBoosterOn && captainAlreadyPaid ? CAPTAIN_BOOSTER_COST    : 0;
    const vcRefund      = !vcBoosterOn      && vcAlreadyPaid      ? VC_BOOSTER_COST         : 0;
    const totalRefund   = subRefund + captainRefund + vcRefund;

    // ── Coin balance check (only for net NEW purchases) ───────
    if (totalNewBoosterCost > 0) {
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
        ),
        refunded AS (
          SELECT COALESCE(SUM(coins), 0) AS total_coins_refunded
          FROM fantasy_user_coin_ledger
          WHERE user_id          = ${userId}
            AND transaction_type = 'credit'
        )
        SELECT
          earned.total_points_earned - spent.total_coins_spent + refunded.total_coins_refunded AS available_coins
        FROM earned, spent, refunded
      `;

      const availableCoins = Number(balanceRows[0]?.available_coins || 0);
      // Include pending refunds from boosters being removed in the same request
      const effectiveBalance = availableCoins + totalRefund;

      if (effectiveBalance < totalNewBoosterCost) {
        return res.status(400).json({
          error: `Insufficient coins. You need ${totalNewBoosterCost} coins for your selected boosters but only have ${availableCoins}.`
        });
      }

      if (newSubCost > 0 && effectiveBalance < SUBSTITUTE_BOOSTER_COST) {
        return res.status(400).json({
          error: `You need ${SUBSTITUTE_BOOSTER_COST} coins to use the Substitute Booster.`
        });
      }
      if (newCaptainCost > 0 && effectiveBalance < CAPTAIN_BOOSTER_COST) {
        return res.status(400).json({
          error: `You need ${CAPTAIN_BOOSTER_COST} coins to use the 3X Captain Booster.`
        });
      }
      if (newVCCost > 0 && effectiveBalance < VC_BOOSTER_COST) {
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

    // ── Coin ledger debits, refunds, and booster records ─────
    //
    //   Only NEW booster selections are charged.
    //   Previously paid boosters are skipped (idempotent).
    //   Removed boosters trigger a credit (refund) entry.
    //
    //   Coin writes happen AFTER all DB inserts succeed so a
    //   mid-flight error never silently loses coins.

    // Debit for new substitute booster
    if (newSubCost > 0) {
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

    // Refund for removed substitute booster
    if (subRefund > 0) {
      await sql`
        INSERT INTO fantasy_user_coin_ledger
          (user_id, transaction_type, coins, reason, fantasy_match_id)
        VALUES
          (${userId}, 'credit', ${SUBSTITUTE_BOOSTER_COST},
           'Substitute Booster removed', ${fantasyMatchId})
      `;
      await sql`
        UPDATE fantasy_user_boosters
        SET status = 'removed'
        WHERE user_id          = ${userId}
          AND fantasy_match_id = ${fantasyMatchId}
          AND booster_type     = 'substitute'
          AND status IN ('active', 'reserved')
      `;
    }

    // Debit for new captain booster
    if (newCaptainCost > 0) {
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

    // Refund for removed captain booster
    if (captainRefund > 0) {
      await sql`
        INSERT INTO fantasy_user_coin_ledger
          (user_id, transaction_type, coins, reason, fantasy_match_id)
        VALUES
          (${userId}, 'credit', ${CAPTAIN_BOOSTER_COST},
           '3X Captain Booster removed', ${fantasyMatchId})
      `;
      await sql`
        UPDATE fantasy_user_boosters
        SET status = 'removed'
        WHERE user_id          = ${userId}
          AND fantasy_match_id = ${fantasyMatchId}
          AND booster_type     = 'captain_3x'
          AND status IN ('active', 'reserved')
      `;
    }

    // Debit for new VC booster
    if (newVCCost > 0) {
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

    // Refund for removed VC booster
    if (vcRefund > 0) {
      await sql`
        INSERT INTO fantasy_user_coin_ledger
          (user_id, transaction_type, coins, reason, fantasy_match_id)
        VALUES
          (${userId}, 'credit', ${VC_BOOSTER_COST},
           '2X Vice-Captain Booster removed', ${fantasyMatchId})
      `;
      await sql`
        UPDATE fantasy_user_boosters
        SET status = 'removed'
        WHERE user_id          = ${userId}
          AND fantasy_match_id = ${fantasyMatchId}
          AND booster_type     = 'vc_2x'
          AND status IN ('active', 'reserved')
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
      total_new_booster_cost:    totalNewBoosterCost,
      total_booster_refund:      totalRefund,
      total_coins_used:          totalCoinsUsed,
      coins_remaining:           Number(match.budget_coins) - totalCoinsUsed
    });

  } catch (error) {
    console.error('submit-fantasy-team-v2 error:', error);
    return res.status(500).json({ error: error.message });
  }
};
