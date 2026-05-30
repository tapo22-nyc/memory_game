const GT_TEAM = "Gujarat Titans";

async function fetchMatchScorecard(cricapiKey, matchId) {
  const url = `https://api.cricapi.com/v1/match_scorecard?apikey=${cricapiKey}&id=${matchId}`;
  const res = await fetch(url);
  return await res.json();
}

function extractTeamBattingRows(scorecardJson, teamName = GT_TEAM) {
  if (!scorecardJson?.data?.scorecard) return [];

  const innings = scorecardJson.data.scorecard.find((inn) =>
    inn.inning?.toLowerCase().includes(teamName.toLowerCase().split(" ")[0])
  );

  if (!innings?.batting) return [];

  return innings.batting.map((row) => ({
    cricapi_match_id: scorecardJson.data.id,
    match_name: scorecardJson.data.name,
    match_date: scorecardJson.data.date,
    team_name: teamName,
    player_cricapi_id: row.batsman?.id,
    player_name: row.batsman?.name,
    runs: row.r || 0,
    balls: row.b || 0,
    fours: row["4s"] || 0,
    sixes: row["6s"] || 0,
    strike_rate: row.sr || 0
  }));
}

async function getTeamLastFiveBattingRows(cricapiKey, matchIds, teamName = GT_TEAM) {
  const allRows = [];

  for (const matchId of matchIds) {
    const scorecardJson = await fetchMatchScorecard(cricapiKey, matchId);
    const rows = extractTeamBattingRows(scorecardJson, teamName);
    allRows.push(...rows);
  }

  return allRows;
}

module.exports = {
  getTeamLastFiveBattingRows
};
