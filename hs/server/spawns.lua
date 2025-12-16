HS = HS or {}
HS.srv = HS.srv or {}

function HS.srv.collectSpawns()
	local spawns = {
		seekers = {},
		hiders = {},
		spectators = {},
		ffa = {},
	}

	local ffaLocs = FindLocations("playerspawn", true) or {}
	for i = 1, #ffaLocs do
		table.insert(spawns.ffa, GetLocationTransform(ffaLocs[i]))
	end

	local teamLocs = FindLocations("teamspawn", true) or {}
	for i = 1, #teamLocs do
		local loc = teamLocs[i]
		local v = GetTagValue(loc, "teamspawn")
		local tr = GetLocationTransform(loc)
		if v == "1" then
			table.insert(spawns.seekers, tr)
		elseif v == "2" then
			table.insert(spawns.hiders, tr)
		end
	end

	local specLocs = FindLocations("spectatorspawn", true) or {}
	for i = 1, #specLocs do
		table.insert(spawns.spectators, GetLocationTransform(specLocs[i]))
	end

	if #spawns.seekers == 0 then spawns.seekers = spawns.ffa end
	if #spawns.hiders == 0 then spawns.hiders = spawns.ffa end
	if #spawns.spectators == 0 then spawns.spectators = spawns.seekers end

	return spawns
end
