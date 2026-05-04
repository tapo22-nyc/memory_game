const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  const { user_id, fantasy_match_id } = req.query;

  const team = await sql`
    SELECT *
    FROM fantasy_user_teams
    WHERE user_id = ${Number(user_id)}
    AND fantasy_match_id = ${Number(fantasy_match_id)}
    LIMIT 1
  `;

  if (!team.length) {
    return res.status(200).json({ team: null });
  }

  const players = await sql`
    SELECT p.*
    FROM fantasy_user_team_players utp
    JOIN fantasy_players p ON p.id = utp.player_id
    WHERE utp.fantasy_user_team_id = ${team[0].id}
  `;

  return res.status(200).json({
    team: team[0],
    players
  });
};
