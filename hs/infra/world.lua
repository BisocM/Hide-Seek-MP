HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.world = HS.infra.world or {}

local W = HS.infra.world

function W.collectSpawns()
	local spawns = {
		seekers = {},
		hiders = {},
		spectators = {},
		ffa = {},
	}

	local ffaLocs = (type(FindLocations) == "function" and FindLocations("playerspawn", true)) or {}
	for i = 1, #ffaLocs do
		spawns.ffa[#spawns.ffa + 1] = GetLocationTransform(ffaLocs[i])
	end

	local teamLocs = (type(FindLocations) == "function" and FindLocations("teamspawn", true)) or {}
	for i = 1, #teamLocs do
		local loc = teamLocs[i]
		local tag = (type(GetTagValue) == "function" and GetTagValue(loc, "teamspawn")) or ""
		local tr = GetLocationTransform(loc)
		if tag == "1" then
			spawns.seekers[#spawns.seekers + 1] = tr
		elseif tag == "2" then
			spawns.hiders[#spawns.hiders + 1] = tr
		end
	end

	local specLocs = (type(FindLocations) == "function" and FindLocations("spectatorspawn", true)) or {}
	for i = 1, #specLocs do
		spawns.spectators[#spawns.spectators + 1] = GetLocationTransform(specLocs[i])
	end

	if #spawns.seekers == 0 then spawns.seekers = spawns.ffa end
	if #spawns.hiders == 0 then spawns.hiders = spawns.ffa end
	if #spawns.spectators == 0 then spawns.spectators = spawns.seekers end

	return spawns
end
