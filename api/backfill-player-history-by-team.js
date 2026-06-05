import { neon } from "@neondatabase/serverless";

const sql = neon(process.env.DATABASE_URL);

async function fetchMatches(offset = 0) {
  const url =
    `https://api.cricapi.com/v1/matches?apikey=${process.env.CRICAPI_KEY}` +
    `&offset=${offset}`;

  const response = await fetch(url);
  const data = await response.json();

  if (!response.ok || data.status === "failure") {
    throw new Error(`matches failed: ${JSON.stringify(data)}`);
  }

  return data;
}

function normalize(value) {
  return String(value || "").trim().toLowerCase();
}

export default async function handler(req, res) {
  try {
    const team = req.query.team || "India";
    const format = req.query.format || "t20";

    const offsets = [0, 25, 50, 75, 100];
    const allMatches = [];

    for (const offset of offsets) {
      const apiData = await fetchMatches(offset);
      const matches = apiData.data || [];

      allMatches.push(...matches);

      if (matches.length === 0) break;
    }

    const filteredMatches = allMatches.filter(match => {
      const teams = match.teams || [];

      return (
        match.matchEnded === true &&
        normalize(match.matchType) === normalize(format) &&
        teams.some(t => normalize(t) === normalize(team))
      );
    });

    return res.status(200).json({
      success: true,
      team,
      format,
      offsets_checked: offsets,
      total_matches_scanned: allMatches.length,
      filtered_matches_found: filteredMatches.length,
      filteredMatches: filteredMatches.map(m => ({
        id: m.id,
        name: m.name,
        matchType: m.matchType,
        date: m.date,
        teams: m.teams,
        status: m.status,
        matchEnded: m.matchEnded
      }))
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
