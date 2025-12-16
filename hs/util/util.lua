HS = HS or {}
HS.util = HS.util or {}

function HS.util.now()
	return GetTime()
end

function HS.util.clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

function HS.util.round(x)
	return math.floor(x + 0.5)
end

function HS.util.deepcopy(v, seen)
	if type(v) ~= "table" then return v end
	seen = seen or {}
	if seen[v] then return seen[v] end
	local t = {}
	seen[v] = t
	for k, vv in pairs(v) do
		t[HS.util.deepcopy(k, seen)] = HS.util.deepcopy(vv, seen)
	end
	return t
end

function HS.util.keysSorted(t)
	local ks = {}
	for k, _ in pairs(t or {}) do
		table.insert(ks, k)
	end
	table.sort(ks)
	return ks
end

function HS.util.getPlayersSorted()
	if HS and HS.engine and HS.engine.playersSorted then
		local ctx = HS.ctx and HS.ctx.get and HS.ctx.get() or nil
		return HS.engine.playersSorted(ctx)
	end
	local ids = GetAllPlayers() or {}
	table.sort(ids)
	return ids
end

function HS.util.countTeam(players, teamId)
	local n = 0
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = players[pid]
		if p and p.team == teamId then n = n + 1 end
	end
	return n
end

function HS.util.anyHidersAlive(players)
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = players[pid]
		if p and p.team == HS.const.TEAM_HIDERS and not p.out then
			return true
		end
	end
	return false
end

function HS.util.hidersRemaining(players)
	local n = 0
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = players[pid]
		if p and p.team == HS.const.TEAM_HIDERS and not p.out then
			n = n + 1
		end
	end
	return n
end

function HS.util.seekersCount(players)
	local n = 0
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = players[pid]
		if p and p.team == HS.const.TEAM_SEEKERS and not p.out then
			n = n + 1
		end
	end
	return n
end

function HS.util.vecDist(a, b)
	return VecLength(VecSub(a, b))
end

function HS.util.pickRandom(list)
	if not list or #list == 0 then return nil end
	return list[GetRandomInt(1, #list)]
end

function HS.util.formatSeconds(sec)
	sec = math.max(0, tonumber(sec) or 0)
	local m = math.floor(sec / 60)
	local s = math.floor(sec - m * 60)
	if m > 0 then
		return string.format("%d:%02d", m, s)
	end
	return string.format("%ds", s)
end
