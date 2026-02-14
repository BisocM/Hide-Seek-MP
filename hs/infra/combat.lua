HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.combat = HS.infra.combat or {}

local C = HS.infra.combat

C._lastAlive = C._lastAlive or {}
C._recentDamageByVictim = C._recentDamageByVictim or {}
C._suppressDeathsUntil = C._suppressDeathsUntil or 0
C._lastHurts = C._lastHurts or {}

local RECENT_DAMAGE_TTL = 2.5

function C.reset()
	C._lastAlive = {}
	C._recentDamageByVictim = {}
	C._suppressDeathsUntil = 0
	C._lastHurts = {}
end

function C.suppress(seconds, nowOverride)
	local n = tonumber(nowOverride) or now()
	local untilAt = n + math.max(0, tonumber(seconds) or 0)
	C._suppressDeathsUntil = math.max(tonumber(C._suppressDeathsUntil) or 0, untilAt)
end

local function append(tbl, victimId, attackerId, cause)
	tbl[#tbl + 1] = {
		victimId = tonumber(victimId) or 0,
		attackerId = tonumber(attackerId) or 0,
		cause = tostring(cause or ""),
	}
end

local function now()
	if HS.util and HS.util.time and HS.util.time.now then
		return HS.util.time.now()
	end
	if HS.infra and HS.infra.clock and HS.infra.clock.now then
		return tonumber(HS.infra.clock.now()) or 0
	end
	if type(GetTime) == "function" then
		return tonumber(GetTime()) or 0
	end
	return 0
end

local function mapBodyOwner(handleToPlayer, bodyId, playerId)
	bodyId = tonumber(bodyId) or 0
	playerId = tonumber(playerId) or 0
	if bodyId <= 0 or playerId <= 0 then return end
	handleToPlayer[bodyId] = playerId

	if type(GetBodyShapes) ~= "function" then return end
	local okShapes, shapes = pcall(GetBodyShapes, bodyId)
	if not okShapes or type(shapes) ~= "table" then return end
	for i = 1, #shapes do
		local sid = tonumber(shapes[i]) or 0
		if sid > 0 then
			handleToPlayer[sid] = playerId
		end
	end
end

local function buildAttackerHandleMap(state)
	local handleToPlayer = {}
	local ids = HS.domain.model.sortedPlayerIds(state)
	for i = 1, #ids do
		local pid = tonumber(ids[i]) or 0
		if pid > 0 and HS.infra.players.isValid(pid) then
			handleToPlayer[pid] = pid

			if type(GetPlayerBodies) == "function" then
				local ok, bodies = pcall(GetPlayerBodies, pid)
				if ok and type(bodies) == "table" then
					for j = 1, #bodies do
						mapBodyOwner(handleToPlayer, bodies[j], pid)
					end
				end
			end

			if type(GetToolBody) == "function" then
				local ok, toolBody = pcall(GetToolBody, pid)
				if ok then
					mapBodyOwner(handleToPlayer, toolBody, pid)
				end
			end

			if type(GetPlayerVehicle) == "function" then
				local okVeh, veh = pcall(GetPlayerVehicle, pid)
				veh = okVeh and (tonumber(veh) or 0) or 0
				if veh > 0 then
					handleToPlayer[veh] = pid
					if type(GetVehicleBodies) == "function" then
						local okBodies, vBodies = pcall(GetVehicleBodies, veh)
						if okBodies and type(vBodies) == "table" then
							for j = 1, #vBodies do
								mapBodyOwner(handleToPlayer, vBodies[j], pid)
							end
						end
					end
				end
			end
		end
	end
	return handleToPlayer
end

local function resolveAttackerPlayer(attacker, handleToPlayer)
	local id = tonumber(attacker) or 0
	if id <= 0 then return 0 end

	local mapped = tonumber(handleToPlayer and handleToPlayer[id]) or 0
	if mapped > 0 and HS.infra.players.isValid(mapped) then
		return mapped
	end

	if HS.infra.players.isValid(id) then
		return id
	end

	if type(GetBodyPlayer) == "function" then
		local ok, pid = pcall(GetBodyPlayer, id)
		pid = ok and (tonumber(pid) or 0) or 0
		if pid > 0 and HS.infra.players.isValid(pid) then
			return pid
		end
	end

	if type(GetShapeBody) == "function" then
		local okBody, bodyId = pcall(GetShapeBody, id)
		bodyId = okBody and (tonumber(bodyId) or 0) or 0
		if bodyId > 0 then
			local mappedBody = tonumber(handleToPlayer and handleToPlayer[bodyId]) or 0
			if mappedBody > 0 and HS.infra.players.isValid(mappedBody) then
				return mappedBody
			end
			if type(GetBodyPlayer) == "function" then
				local okPid, pid = pcall(GetBodyPlayer, bodyId)
				pid = okPid and (tonumber(pid) or 0) or 0
				if pid > 0 and HS.infra.players.isValid(pid) then
					return pid
				end
			end
		end
	end

	return 0
end

local function sampleRecentAttacker(victimId, nowT)
	local rec = C._recentDamageByVictim[tonumber(victimId) or 0]
	if type(rec) ~= "table" then return 0 end
	local attacker = tonumber(rec.attacker) or 0
	local t = tonumber(rec.t) or 0
	if attacker <= 0 or (nowT - t) > RECENT_DAMAGE_TTL then
		return 0
	end
	return attacker
end

local function pruneRecentDamage(state, nowT)
	for victimId, rec in pairs(C._recentDamageByVictim) do
		local vid = tonumber(victimId) or 0
		local t = type(rec) == "table" and (tonumber(rec.t) or 0) or 0
		if vid <= 0 or not (state and state.players and state.players[vid]) or (nowT - t) > RECENT_DAMAGE_TTL then
			C._recentDamageByVictim[victimId] = nil
		end
	end
end

local function pullHurtAttribution(state, handleToPlayer, nowT, hurtsOut)
	local attackerByVictim = {}
	if type(GetEventCount) ~= "function" or type(GetEvent) ~= "function" then
		return attackerByVictim
	end
	local ok, count = pcall(GetEventCount, "playerhurt")
	if not ok or type(count) ~= "number" then
		return attackerByVictim
	end
	for i = 1, count do
		local okEv, victim, before, after, attacker = pcall(GetEvent, "playerhurt", i)
		if okEv then
			local b = tonumber(before) or 0
			local a = tonumber(after) or 0
			local v = tonumber(victim) or 0
			if v > 0 and a < b then
				local resolved = resolveAttackerPlayer(attacker, handleToPlayer)
				if type(hurtsOut) == "table" and state and state.players and state.players[v] then
					hurtsOut[#hurtsOut + 1] = {
						victimId = v,
						attackerId = math.max(0, resolved),
						before = b,
						after = a,
					}
				end
				if resolved > 0 then
					attackerByVictim[v] = resolved
					C._recentDamageByVictim[v] = {
						attacker = resolved,
						t = nowT,
					}
				end
			end
		end
	end
	return attackerByVictim
end

local function pullEngineDeathEvents(state, out, handleToPlayer, hurtAttackerByVictim, nowT)
	if type(GetEventCount) ~= "function" or type(GetEvent) ~= "function" then
		return false
	end
	local ok, count = pcall(GetEventCount, "playerdied")
	if not ok or type(count) ~= "number" then
		return false
	end
	for i = 1, count do
		local okEv, victim, attacker, _point, _impulse, cause = pcall(GetEvent, "playerdied", i)
		if okEv then
			local v = tonumber(victim) or 0
			if v > 0 and state and state.players and state.players[v] then
				local resolved = resolveAttackerPlayer(attacker, handleToPlayer)
				local fallback = tonumber(hurtAttackerByVictim[v]) or sampleRecentAttacker(v, nowT)
				if (resolved <= 0 or resolved == v) and fallback > 0 and fallback ~= v then
					resolved = fallback
				end
				append(out, v, resolved, cause)
			end
		end
	end
	return count > 0
end

local function pullHealthTransitions(state, out, nowT)
	for _, pid in ipairs(HS.domain.model.sortedPlayerIds(state)) do
		if HS.infra.players.isValid(pid) then
			local hp = tonumber(GetPlayerHealth(pid)) or 0
			local alive = hp > 0
			local prev = C._lastAlive[pid]
			if prev == nil then
				C._lastAlive[pid] = alive
			elseif prev == true and alive == false then
				local fallback = sampleRecentAttacker(pid, nowT)
				if fallback == pid then
					fallback = 0
				end
				append(out, pid, fallback, "")
				C._lastAlive[pid] = false
			elseif alive == true then
				C._lastAlive[pid] = true
			end
		end
	end

	for pid in pairs(C._lastAlive) do
		if not (state and state.players and state.players[pid]) then
			C._lastAlive[pid] = nil
		end
	end
end

function C.pollDeaths(state)
	local out = {}
	C._lastHurts = {}
	local nowT = now()
	if nowT < (tonumber(C._suppressDeathsUntil) or 0) then
		for _, pid in ipairs(HS.domain.model.sortedPlayerIds(state)) do
			if HS.infra.players.isValid(pid) then
				C._lastAlive[pid] = (tonumber(GetPlayerHealth(pid)) or 0) > 0
			end
		end
		pruneRecentDamage(state, nowT)
		return out
	end

	pruneRecentDamage(state, nowT)
	local handleToPlayer = buildAttackerHandleMap(state)
	local hurtAttackerByVictim = pullHurtAttribution(state, handleToPlayer, nowT, C._lastHurts)
	local fromEvents = pullEngineDeathEvents(state, out, handleToPlayer, hurtAttackerByVictim, nowT)
	if not fromEvents then
		pullHealthTransitions(state, out, nowT)
	else
		for _, pid in ipairs(HS.domain.model.sortedPlayerIds(state)) do
			if HS.infra.players.isValid(pid) then
				C._lastAlive[pid] = (tonumber(GetPlayerHealth(pid)) or 0) > 0
			end
		end
	end
	return out
end

function C.pollHurts()
	local out = C._lastHurts or {}
	C._lastHurts = {}
	return out
end
