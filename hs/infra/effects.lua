HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.effects = HS.infra.effects or {}

local F = HS.infra.effects

F._cache = F._cache or {
	spectator = {},
	phase = "",
	superjump = {},
}

local function logWarn(msg, data)
	if HS.log and HS.log.warn then
		HS.log.warn(msg, data)
	end
end

local function isValid(pid)
	return HS.infra and HS.infra.players and HS.infra.players.isValid and HS.infra.players.isValid(pid)
end

local function pickDeterministicSpawn(list, playerId, round)
	if type(list) ~= "table" or #list == 0 then return nil end
	local pid = math.abs(math.floor(tonumber(playerId) or 0))
	local rnd = math.abs(math.floor(tonumber(round) or 0))
	local idx = ((pid * 31 + rnd * 17) % #list) + 1
	return list[idx]
end

local function respawnAt(tr, playerId, hp)
	if not isValid(playerId) then return end
	if type(tr) == "table" and type(RespawnPlayerAtTransform) == "function" then
		RespawnPlayerAtTransform(tr, playerId)
	end
	if type(SetPlayerHealth) == "function" then
		SetPlayerHealth(tonumber(hp) or 1.0, playerId)
	end
	if type(ReleasePlayerGrab) == "function" then
		ReleasePlayerGrab(playerId)
	end
end

local function moveToSpectator(state, playerId)
	if not isValid(playerId) then return end
	if HS.infra and HS.infra.mimic and HS.infra.mimic.stop then
		HS.infra.mimic.stop(state, playerId, "to_spectator")
	end
	local cur = GetPlayerTransform(playerId)
	local spawns = state and state.spawns and state.spawns.spectators or nil
	local tr = pickDeterministicSpawn(spawns, playerId, state and state.round or 0) or cur
	respawnAt(tr, playerId, 1.0)
	DisablePlayerInput(playerId)
	SetPlayerWalkingSpeed(0.0, playerId)
	SetPlayerCrouchSpeedScale(0.01, playerId)
	SetPlayerVelocity(Vec(0, 0, 0), playerId)
	ReleasePlayerGrab(playerId)
	if type(SetPlayerParam) == "function" then
		SetPlayerParam("disableinteract", true, playerId)
	end
end

local function lockSpectator(playerId)
	if not isValid(playerId) then return end
	DisablePlayerInput(playerId)
	SetPlayerWalkingSpeed(0.0, playerId)
	SetPlayerCrouchSpeedScale(0.01, playerId)
	SetPlayerVelocity(Vec(0, 0, 0), playerId)
	ReleasePlayerGrab(playerId)
	if type(SetPlayerParam) == "function" then
		SetPlayerParam("disableinteract", true, playerId)
	end
end

local function spawnByTeam(state, playerId, teamId)
	if not isValid(playerId) then return end
	if teamId ~= HS.const.TEAM_HIDERS and HS.infra and HS.infra.mimic and HS.infra.mimic.stop then
		HS.infra.mimic.stop(state, playerId, "non_hider_team")
	end
	local tr = GetPlayerTransform(playerId)
	if teamId == HS.const.TEAM_SEEKERS then
		tr = pickDeterministicSpawn(state.spawns and state.spawns.seekers, playerId, state.round) or tr
	elseif teamId == HS.const.TEAM_HIDERS then
		tr = pickDeterministicSpawn(state.spawns and state.spawns.hiders, playerId, state.round) or tr
	else
		tr = pickDeterministicSpawn(state.spawns and state.spawns.spectators, playerId, state.round) or tr
	end
	respawnAt(tr, playerId, 1.0)
end

local function applyTeamColor(teamId, playerId)
	if teamId == 0 then
		SetPlayerColor(0.55, 0.55, 0.55, playerId)
		return
	end
	if HS.engine and HS.engine.teamColor then
		local c = HS.engine.teamColor(teamId)
		if type(c) == "table" then
			SetPlayerColor(c[1], c[2], c[3], playerId)
			return
		end
	end
	if type(teamsGetColor) == "function" then
		local c = teamsGetColor(teamId)
		if type(c) == "table" then
			SetPlayerColor(c[1], c[2], c[3], playerId)
		end
	end
end

local function setActiveMovement(playerId, phase, teamId)
	if phase == HS.const.PHASE_INTERMISSION then
		DisablePlayerInput(playerId)
		SetPlayerWalkingSpeed(0.0, playerId)
		SetPlayerCrouchSpeedScale(0.01, playerId)
		SetPlayerVelocity(Vec(0, 0, 0), playerId)
		ReleasePlayerGrab(playerId)
		return
	end

	if phase == HS.const.PHASE_HIDING and teamId == HS.const.TEAM_SEEKERS then
		DisablePlayerInput(playerId)
		SetPlayerWalkingSpeed(0.0, playerId)
		SetPlayerCrouchSpeedScale(0.01, playerId)
		SetPlayerVelocity(Vec(0, 0, 0), playerId)
		ReleasePlayerGrab(playerId)
		return
	end

	if type(EnablePlayerInput) == "function" then
		EnablePlayerInput(playerId)
	end
	if type(SetPlayerParam) == "function" then
		SetPlayerParam("disableinteract", false, playerId)
	end
	SetPlayerWalkingSpeed(7.0, playerId)
	SetPlayerCrouchSpeedScale(1.0, playerId)
end

local function runDash(state, playerId)
	if not isValid(playerId) then return end
	local def = HS.abilities and HS.abilities.def and HS.abilities.def((HS.abilities.ids and HS.abilities.ids.dash) or "dash") or nil
	local cfg = def and def.cfg or {}
	local duration = tonumber(cfg.durationSeconds) or 0.25
	local dist = tonumber(cfg.distance) or 5.5
	if duration <= 0.01 then duration = 0.25 end

	local cam = GetPlayerCameraTransform(playerId)
	local aimTr = (type(cam) == "table" and cam) or GetPlayerTransform(playerId)
	local dir = TransformToParentVec(aimTr, Vec(0, 0, -1))
	dir = Vec(dir[1] or 0, 0, dir[3] or 0)
	if VecLength(dir) < 0.001 then
		dir = Vec(0, 0, -1)
	else
		dir = VecNormalize(dir)
	end

	local vel = GetPlayerVelocity(playerId) or Vec(0, 0, 0)
	local speed = dist / duration
	SetPlayerVelocity(Vec(dir[1] * speed, tonumber(vel[2]) or 0, dir[3] * speed), playerId)
	ReleasePlayerGrab(playerId)

	if HS.domain and HS.domain.events then
		local pos = VecAdd(GetPlayerTransform(playerId).pos, Vec(0, 0.9, 0))
		local endPos = VecAdd(pos, VecScale(dir, dist))
		local ev = HS.domain.events.clientAbilityVfx(def and def.id or "dash", playerId, pos, dir, endPos, 0)
		if ev and HS.infra and HS.infra.events and HS.infra.events.emit then
			HS.infra.events.emit(0, ev.type, ev.payload)
		end
	end
end

local function runSuperjump(state, playerId)
	if not isValid(playerId) then return end
	local def = HS.abilities and HS.abilities.def and HS.abilities.def((HS.abilities.ids and HS.abilities.ids.superjump) or "superjump") or nil
	local cfg = def and def.cfg or {}
	local boost = tonumber(cfg.jumpBoost) or 14.0
	local vel = GetPlayerVelocity(playerId) or Vec(0, 0, 0)
	SetPlayerVelocity(Vec(tonumber(vel[1]) or 0, math.max(tonumber(vel[2]) or 0, boost), tonumber(vel[3]) or 0), playerId)
	F._cache.superjump = F._cache.superjump or {}
	F._cache.superjump[playerId] = {
		untilAt = ((HS.infra and HS.infra.clock and HS.infra.clock.now and HS.infra.clock.now()) or 0) + 0.22,
		boost = boost,
	}

	if HS.domain and HS.domain.events then
		local contact, point = false, nil
		if type(GetPlayerGroundContact) == "function" then
			local c, _n, p = GetPlayerGroundContact(playerId)
			contact = c
			point = p
		end
		local pos = (contact and point) or VecAdd(GetPlayerTransform(playerId).pos, Vec(0, -0.9, 0))
		local ev = HS.domain.events.clientAbilityVfx(def and def.id or "superjump", playerId, pos, Vec(0, 1, 0), pos, 0)
		if ev and HS.infra and HS.infra.events and HS.infra.events.emit then
			HS.infra.events.emit(0, ev.type, ev.payload)
		end
	end
end

local function runMimic(state, playerId, payload)
	if not (HS.infra and HS.infra.mimic and HS.infra.mimic.start) then
		return
	end
	local bodyId = math.floor(tonumber(payload and payload.mimicBodyId) or 0)
	local ok, reason = HS.infra.mimic.start(state, playerId, bodyId)
	if ok then
		return
	end

	local key = "hs.toast.mimicUnavailable"
	if HS.infra.mimic.validationToastKey then
		key = HS.infra.mimic.validationToastKey(reason)
	end
	if HS.domain and HS.domain.events and HS.domain.events.clientToast and HS.infra and HS.infra.events and HS.infra.events.emit then
		local ev = HS.domain.events.clientToast({ key = key }, 1.6, nil, playerId)
		if ev then
			HS.infra.events.emit(tonumber(ev.target) or 0, ev.type, ev.payload)
		end
	end
	logWarn("Mimic start failed after domain approval", {
		playerId = tonumber(playerId) or 0,
		bodyId = bodyId,
		reason = tostring(reason or ""),
	})
end

function F.reset()
	F._cache = {
		spectator = {},
		phase = "",
		superjump = {},
	}
	if HS.infra and HS.infra.mimic and HS.infra.mimic.reset then
		HS.infra.mimic.reset()
	end
end

function F.handleServerEvent(state, _prevState, event, _frameNow)
	if type(event) ~= "table" then return end
	local t = tostring(event.type or "")
	local p = type(event.payload) == "table" and event.payload or {}

	if t == HS.domain.events.SRV_PLAYER_TO_SPECTATOR then
		local pid = tonumber(p.playerId) or 0
		if pid > 0 then
			moveToSpectator(state, pid)
			F._cache.spectator[pid] = true
		end
	elseif t == HS.domain.events.SRV_PLAYER_TO_TEAM then
		local pid = tonumber(p.playerId) or 0
		local teamId = tonumber(p.teamId) or 0
		if pid > 0 then
			spawnByTeam(state, pid, teamId)
			F._cache.spectator[pid] = false
		end
	elseif t == HS.domain.events.SRV_RESTORE_HEALTH then
		local pid = tonumber(p.playerId) or 0
		if pid > 0 and isValid(pid) then
			local hp = tonumber(p.health) or 1.0
			if (tonumber(GetPlayerHealth(pid)) or 0) <= 0 then
				respawnAt(GetPlayerTransform(pid), pid, hp)
			else
				SetPlayerHealth(hp, pid)
			end
		end
	elseif t == HS.domain.events.SRV_ABILITY_EXECUTE then
		local pid = tonumber(p.playerId) or 0
		local abilityId = tostring(p.abilityId or "")
		local ev = tostring(p.event or "use")
		if pid > 0 and abilityId ~= "" then
			if abilityId == ((HS.abilities and HS.abilities.ids and HS.abilities.ids.dash) or "dash") and ev == "use" then
				runDash(state, pid)
			elseif abilityId == ((HS.abilities and HS.abilities.ids and HS.abilities.ids.superjump) or "superjump") and ev == "trigger" then
				runSuperjump(state, pid)
			elseif abilityId == ((HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop") and ev == "use" then
				runMimic(state, pid, p)
			end
		end
	elseif t == HS.domain.events.SRV_ROUND_STARTED then
		for _, pid in ipairs(HS.domain.model.sortedPlayerIds(state)) do
			local ps = state.players[pid]
			if ps then
				if ps.team == HS.const.TEAM_SEEKERS or ps.team == HS.const.TEAM_HIDERS then
					spawnByTeam(state, pid, ps.team)
					F._cache.spectator[pid] = false
				else
					moveToSpectator(state, pid)
					F._cache.spectator[pid] = true
				end
			end
		end
	end
end

function F.syncState(state, prevState, _frameNow)
	if type(state) ~= "table" then return end
	local phase = tostring(state.phase or "")
	local phaseChanged = phase ~= tostring(F._cache.phase or "")
	local frameNow = tonumber(_frameNow) or ((HS.infra and HS.infra.clock and HS.infra.clock.now and HS.infra.clock.now()) or 0)
	F._cache.phase = phase

	for _, pid in ipairs(HS.domain.model.sortedPlayerIds(state)) do
		if isValid(pid) then
			local p = state.players[pid]
			if p then
				local spectator = p.out == true or p.team == 0
				if spectator then
					if F._cache.spectator[pid] ~= true or phaseChanged then
						moveToSpectator(state, pid)
						F._cache.spectator[pid] = true
					end
					F._cache.superjump[pid] = nil
					lockSpectator(pid)
				else
					if phaseChanged and prevState and prevState.phase == HS.const.PHASE_INTERMISSION then
						spawnByTeam(state, pid, p.team)
					end
					F._cache.spectator[pid] = false
					applyTeamColor(p.team, pid)
					setActiveMovement(pid, phase, p.team)
					if type(SetPlayerParam) == "function" then
						SetPlayerParam("healthRegeneration", state.settings and state.settings.healthRegenEnabled == true, pid)
					end
					if phase == HS.const.PHASE_HIDING and p.team == HS.const.TEAM_SEEKERS then
						if type(DisablePlayerDamage) == "function" then
							DisablePlayerDamage(pid)
						end
						if (tonumber(GetPlayerHealth(pid)) or 0) < 1.0 and type(SetPlayerHealth) == "function" then
							SetPlayerHealth(1.0, pid)
						end
					end

					local sj = F._cache.superjump[pid]
					if type(sj) == "table" then
						local untilAt = tonumber(sj.untilAt) or 0
						if frameNow <= untilAt then
							local boost = tonumber(sj.boost) or 14.0
							local v = GetPlayerVelocity(pid) or Vec(0, 0, 0)
							SetPlayerVelocity(
								Vec(
									tonumber(v[1]) or 0,
									math.max(tonumber(v[2]) or 0, boost),
									tonumber(v[3]) or 0
								),
								pid
							)
						else
							F._cache.superjump[pid] = nil
						end
					end
				end
			end
		end
	end

	if HS.infra and HS.infra.mimic and HS.infra.mimic.sync then
		HS.infra.mimic.sync(state, frameNow)
	end
end
