HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.teams = HS.domain.teams or {}

local T = HS.domain.teams

function T.count(state)
	local seekers = 0
	local hiders = 0
	if type(state) ~= "table" or type(state.players) ~= "table" then
		return seekers, hiders
	end
	for _, p in pairs(state.players) do
		if type(p) == "table" and p.out ~= true then
			if p.team == HS.const.TEAM_SEEKERS then seekers = seekers + 1 end
			if p.team == HS.const.TEAM_HIDERS then hiders = hiders + 1 end
		end
	end
	return seekers, hiders
end
