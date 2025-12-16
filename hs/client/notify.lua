
local function teamColor(teamId)
	return HS.engine.teamColor(teamId)
end

function client.hs_victory(winner)
	local w = tostring(winner or "")
	if w == "" then return end

	local winnerName = w
	if w == HS.const.WIN_SEEKERS then
		winnerName = HS.t("hs.team.seekers")
	elseif w == HS.const.WIN_HIDERS then
		winnerName = HS.t("hs.team.hiders")
	end

	local text = HS.t("hs.banner.victory", { winner = winnerName })
	local tc = {1, 1, 1, 1}
	if w == HS.const.WIN_SEEKERS then
		tc = teamColor(HS.const.TEAM_SEEKERS)
	elseif w == HS.const.WIN_HIDERS then
		tc = teamColor(HS.const.TEAM_HIDERS)
	end

	hudShowBanner(text, {0, 0, 0, 0.75}, {tc[1], tc[2], tc[3], 1})
end
