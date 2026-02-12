HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.runtime = HS.srv.runtime or {}

local R = HS.srv.runtime

local function enforceNonInteractive(playerId)
	if not IsPlayerValid(playerId) then return end
	DisablePlayerInput(playerId)
	SetPlayerParam("disableinteract", true, playerId)
	DisablePlayerDamage(playerId)
	if GetPlayerHealth(playerId) < 1.0 then
		SetPlayerHealth(1.0, playerId)
	end
	SetPlayerWalkingSpeed(0.0, playerId)
	SetPlayerCrouchSpeedScale(0.01, playerId)
	SetPlayerVelocity(Vec(0, 0, 0), playerId)
	ReleasePlayerGrab(playerId)
end

local function respawnHere(playerId, hp)
	if not IsPlayerValid(playerId) then return end
	local tr = GetPlayerTransform(playerId)
	RespawnPlayerAtTransform(tr, playerId)
	SetPlayerHealth(HS.util.clamp(tonumber(hp) or 1.0, 0.0, 1.0), playerId)
	ReleasePlayerGrab(playerId)
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
		local shapeId = tonumber(shapes[i]) or 0
		if shapeId > 0 then
			handleToPlayer[shapeId] = playerId
		end
	end
end

local function buildAttackerHandleMap()
	local handleToPlayer = {}
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		pid = tonumber(pid) or 0
		if pid > 0 and IsPlayerValid(pid) then
			handleToPlayer[pid] = pid

			if type(GetPlayerBodies) == "function" then
				local okPlayerBodies, playerBodies = pcall(GetPlayerBodies, pid)
				if okPlayerBodies and type(playerBodies) == "table" then
					for i = 1, #playerBodies do
						mapBodyOwner(handleToPlayer, playerBodies[i], pid)
					end
				end
			end

			if type(GetToolBody) == "function" then
				local okTool, toolBody = pcall(GetToolBody, pid)
				if okTool then
					mapBodyOwner(handleToPlayer, toolBody, pid)
				end
			end

			if type(GetPlayerVehicle) == "function" then
				local okVeh, veh = pcall(GetPlayerVehicle, pid)
				veh = okVeh and (tonumber(veh) or 0) or 0
				if veh > 0 then
					handleToPlayer[veh] = pid
					if type(GetVehicleBodies) == "function" then
						local okBodies, bodies = pcall(GetVehicleBodies, veh)
						if okBodies and type(bodies) == "table" then
							for i = 1, #bodies do
								mapBodyOwner(handleToPlayer, bodies[i], pid)
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
	if mapped > 0 and IsPlayerValid(mapped) then
		return mapped
	end

	if IsPlayerValid(id) then return id end

	if type(GetBodyPlayer) == "function" then
		local ok, pid = pcall(GetBodyPlayer, id)
		pid = ok and (tonumber(pid) or 0) or 0
		if pid > 0 and IsPlayerValid(pid) then
			return pid
		end
	end

	if type(GetShapeBody) == "function" then
		local okBody, bodyId = pcall(GetShapeBody, id)
		bodyId = okBody and (tonumber(bodyId) or 0) or 0
		if bodyId > 0 then
			local fromBodyMap = tonumber(handleToPlayer and handleToPlayer[bodyId]) or 0
			if fromBodyMap > 0 and IsPlayerValid(fromBodyMap) then
				return fromBodyMap
			end

			if type(GetBodyPlayer) == "function" then
				local okPid, pid = pcall(GetBodyPlayer, bodyId)
				pid = okPid and (tonumber(pid) or 0) or 0
				if pid > 0 and IsPlayerValid(pid) then
					return pid
				end
			end
		end
	end

	return 0
end

local function isSeekerGraceActive(state, now)
	if not state or not state.settings then return false end
	if state.phase ~= HS.const.PHASE_SEEKING then return false end
	if state.settings.allowHidersKillSeekers ~= true then return false end
	local endsAt = tonumber(state.seekerGraceEndsAt) or 0
	now = tonumber(now) or HS.util.now()
	return endsAt > 0 and now < endsAt
end

function R.enforcePerTickRules(state)
	local phase = state.phase
	if phase == HS.const.PHASE_SETUP then return end

	local healthRegenEnabled = state.settings.healthRegenEnabled == true
	local now = HS.util.now()
	local graceActive = isSeekerGraceActive(state, now)

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p and IsPlayerValid(pid) then
			local playing = (phase == HS.const.PHASE_HIDING or phase == HS.const.PHASE_SEEKING)
				and (p.team == HS.const.TEAM_SEEKERS or p.team == HS.const.TEAM_HIDERS)
				and not p.out
			SetPlayerParam("healthRegeneration", (playing and healthRegenEnabled) and true or false, pid)

			if p.out or p.team == 0 then
				SetPlayerColor(0.55, 0.55, 0.55, pid)
			else
				local c = teamsGetColor(p.team)
				if type(c) == "table" then
					SetPlayerColor(c[1], c[2], c[3], pid)
				end
			end

			if phase == HS.const.PHASE_INTERMISSION then
				DisablePlayerInput(pid)
				ReleasePlayerGrab(pid)
			end

			if p.out or p.team == 0 then
				enforceNonInteractive(pid)
			end

			if (phase == HS.const.PHASE_HIDING or phase == HS.const.PHASE_SEEKING) and p.team == HS.const.TEAM_SEEKERS and not p.out then
				if phase == HS.const.PHASE_HIDING or graceActive then
					DisablePlayerDamage(pid)
					local hp = tonumber(GetPlayerHealth(pid)) or 0
					if hp <= 0 then
						respawnHere(pid, 1.0)
						DisablePlayerDamage(pid)
					elseif hp < 1.0 then
						SetPlayerHealth(1.0, pid)
					end
					if phase == HS.const.PHASE_HIDING then
						DisablePlayerInput(pid)
					end
				end
			end
		end
	end
end

function R.handleSeekersNotKillableByHiders(state)
	if state.phase ~= HS.const.PHASE_SEEKING and state.phase ~= HS.const.PHASE_HIDING then
		return
	end
	local tagOnly = state.settings.tagOnlyMode == true
	if state.settings.allowHidersKillSeekers == true and not tagOnly then
		return
	end

	state._seekerHurtByHider = state._seekerHurtByHider or {}
	local hurt = state._seekerHurtByHider
	for k in pairs(hurt) do hurt[k] = nil end

	local function isHider(pid)
		if type(pid) ~= "number" or pid <= 0 then return false end
		if not IsPlayerValid(pid) then return false end
		local ap = state.players[pid]
		return ap and ap.team == HS.const.TEAM_HIDERS
	end

	local attackerHandleMap = buildAttackerHandleMap()
	local c = GetEventCount("playerhurt")
	for i = 1, c do
		local victim, before, after, attacker = GetEvent("playerhurt", i)
		local b = tonumber(before) or 0
		local a = tonumber(after) or 0
		if a < b then
			victim = tonumber(victim) or 0
			attacker = resolveAttackerPlayer(attacker, attackerHandleMap)
			if victim ~= 0 and attacker ~= 0 and IsPlayerValid(victim) and isHider(attacker) then
				local vp = state.players[victim]
				if vp and vp.team == HS.const.TEAM_SEEKERS and not vp.out then
					local dmg = b - a
					hurt[victim] = (tonumber(hurt[victim]) or 0) + dmg
				end
			end
		end
	end

	for victim, dmg in pairs(hurt) do
		dmg = tonumber(dmg) or 0
		victim = tonumber(victim) or 0
		if dmg > 0 and victim ~= 0 and IsPlayerValid(victim) then
			local cur = tonumber(GetPlayerHealth(victim)) or 0
			local restored = HS.util.clamp(cur + dmg, 0.0, 1.0)
			if restored > cur then
				if cur <= 0 and restored > 0 then
					local tr = GetPlayerTransform(victim)
					RespawnPlayerAtTransform(tr, victim)
					ReleasePlayerGrab(victim)
				end
				SetPlayerHealth(restored, victim)
			end
		end
	end
end

function R.handleHidersNotKillableBySeekers(state)
	if state.phase ~= HS.const.PHASE_SEEKING and state.phase ~= HS.const.PHASE_HIDING then
		return
	end
	if state.settings.tagOnlyMode ~= true then
		return
	end

	state._hiderHurtBySeeker = state._hiderHurtBySeeker or {}
	local hurt = state._hiderHurtBySeeker
	for k in pairs(hurt) do hurt[k] = nil end

	local function isSeeker(pid)
		if type(pid) ~= "number" or pid <= 0 then return false end
		if not IsPlayerValid(pid) then return false end
		local ap = state.players[pid]
		return ap and ap.team == HS.const.TEAM_SEEKERS
	end

	local attackerHandleMap = buildAttackerHandleMap()
	local c = GetEventCount("playerhurt")
	for i = 1, c do
		local victim, before, after, attacker = GetEvent("playerhurt", i)
		local b = tonumber(before) or 0
		local a = tonumber(after) or 0
		if a < b then
			victim = tonumber(victim) or 0
			attacker = resolveAttackerPlayer(attacker, attackerHandleMap)
			if victim ~= 0 and attacker ~= 0 and IsPlayerValid(victim) and isSeeker(attacker) then
				local vp = state.players[victim]
				if vp and vp.team == HS.const.TEAM_HIDERS and not vp.out then
					local dmg = b - a
					hurt[victim] = (tonumber(hurt[victim]) or 0) + dmg
				end
			end
		end
	end

	for victim, dmg in pairs(hurt) do
		dmg = tonumber(dmg) or 0
		victim = tonumber(victim) or 0
		if dmg > 0 and victim ~= 0 and IsPlayerValid(victim) then
			local cur = tonumber(GetPlayerHealth(victim)) or 0
			local restored = HS.util.clamp(cur + dmg, 0.0, 1.0)
			if restored > cur then
				if cur <= 0 and restored > 0 then
					local tr = GetPlayerTransform(victim)
					RespawnPlayerAtTransform(tr, victim)
					ReleasePlayerGrab(victim)
				end
				SetPlayerHealth(restored, victim)
			end
		end
	end
end

function R.handleDeaths(state)
	if state.phase ~= HS.const.PHASE_SEEKING and state.phase ~= HS.const.PHASE_HIDING then
		return
	end

	local taggingEnabled = state.settings.taggingEnabled == true
	local infectionMode = state.settings.infectionMode == true
	local allowHidersKillSeekers = state.settings.allowHidersKillSeekers == true
	local tagOnly = state.settings.tagOnlyMode == true
	local now = HS.util.now()
	local graceActive = isSeekerGraceActive(state, now)
	local attackerHandleMap = buildAttackerHandleMap()
	state._recentDamageByVictim = state._recentDamageByVictim or {}
	local recentDamageByVictim = state._recentDamageByVictim
	local recentDamageTtl = 2.5

	for victimId, sample in pairs(recentDamageByVictim) do
		local victimNum = tonumber(victimId) or 0
		local ts = type(sample) == "table" and (tonumber(sample.t) or 0) or 0
		if victimNum <= 0 or not IsPlayerValid(victimNum) or (now - ts) > recentDamageTtl then
			recentDamageByVictim[victimId] = nil
		end
	end

	local attackerOf = {}
	local ec = GetEventCount("playerdied")
	for i = 1, ec do
		local victim, attacker = GetEvent("playerdied", i)
		victim = tonumber(victim) or 0
		if victim > 0 then
			attackerOf[victim] = resolveAttackerPlayer(attacker, attackerHandleMap)
		end
	end

	-- Some damage paths report a weak/empty attacker in `playerdied`.
	-- Keep the latest damage attacker as a fallback for kill-feed attribution.
	local hurtAttackerOf = {}
	local hc = GetEventCount("playerhurt")
	for i = 1, hc do
		local victim, before, after, attacker = GetEvent("playerhurt", i)
		local b = tonumber(before) or 0
		local a = tonumber(after) or 0
		if a < b then
			victim = tonumber(victim) or 0
			if victim > 0 then
				local resolved = resolveAttackerPlayer(attacker, attackerHandleMap)
				hurtAttackerOf[victim] = resolved
				if resolved > 0 then
					recentDamageByVictim[victim] = {
						attacker = resolved,
						t = now,
					}
				end
			end
		end
	end

	local function isSeekerPlayer(pid)
		if type(pid) ~= "number" or pid <= 0 then return false end
		if not IsPlayerValid(pid) then return false end
		local ap = state.players[pid]
		return ap and ap.team == HS.const.TEAM_SEEKERS
	end
	local function isKnownPlayer(pid)
		if type(pid) ~= "number" or pid <= 0 then return false end
		return IsPlayerValid(pid) or (state.players and state.players[pid] ~= nil)
	end
	local function isActiveHider(pid)
		if type(pid) ~= "number" or pid <= 0 then return false end
		if not IsPlayerValid(pid) then return false end
		local ap = state.players[pid]
		return ap and ap.team == HS.const.TEAM_HIDERS and not ap.out
	end
	local function resolveAttackerForFeed(victimId, primary)
		local a = tonumber(primary) or 0
		if isKnownPlayer(a) then return a end

		a = tonumber(attackerOf[victimId]) or 0
		if isKnownPlayer(a) then return a end

		a = tonumber(hurtAttackerOf[victimId]) or 0
		if isKnownPlayer(a) then return a end

		local sample = recentDamageByVictim[victimId]
		a = tonumber(sample and sample.attacker) or 0
		if isKnownPlayer(a) then return a end

		return 0
	end
	local function notifyKillFeed(attackerId, victimId)
		attackerId = tonumber(attackerId) or 0
		victimId = tonumber(victimId) or 0
		if not isKnownPlayer(attackerId) then
			return
		end
		HS.srv.notify.feedCaught(0, attackerId, victimId, "kill")
	end

	local changed = false
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p and not p.out and IsPlayerValid(pid) then
			local invulnerable = p.team == HS.const.TEAM_SEEKERS and (state.phase == HS.const.PHASE_HIDING or graceActive)
			if invulnerable and (tonumber(GetPlayerHealth(pid)) or 0) <= 0 then
				respawnHere(pid, 1.0)
				DisablePlayerDamage(pid)
				if state.phase == HS.const.PHASE_HIDING then
					DisablePlayerInput(pid)
				end
				changed = true
			end

			if (p.team == HS.const.TEAM_SEEKERS or p.team == HS.const.TEAM_HIDERS) and GetPlayerHealth(pid) <= 0 then
				local attacker = attackerOf[pid] or 0
				local attackerForFeed = resolveAttackerForFeed(pid, attacker)
				local seekerAttacker = isSeekerPlayer(attackerForFeed) and attackerForFeed or 0
				local handled = false

				if invulnerable then
					respawnHere(pid, 1.0)
					DisablePlayerDamage(pid)
					if state.phase == HS.const.PHASE_HIDING then
						DisablePlayerInput(pid)
					end
					changed = true
					handled = true
				end

				if p.team == HS.const.TEAM_SEEKERS then
					local hurtByHider = ((not allowHidersKillSeekers) or tagOnly)
						and (state._seekerHurtByHider and (tonumber(state._seekerHurtByHider[pid]) or 0) > 0)
					if hurtByHider or (tagOnly and isActiveHider(attackerForFeed)) then
						p.out = false
						local hp = (state._seekerHurtByHider and tonumber(state._seekerHurtByHider[pid])) or 1.0
						respawnHere(pid, hp)
						changed = true
						handled = true
					end
				elseif p.team == HS.const.TEAM_HIDERS and tagOnly then
					local hurtBySeeker = state._hiderHurtBySeeker and (tonumber(state._hiderHurtBySeeker[pid]) or 0) > 0
					if hurtBySeeker or seekerAttacker ~= 0 then
						notifyKillFeed(attackerForFeed, pid)
						p.out = false
						local hp = (state._hiderHurtBySeeker and tonumber(state._hiderHurtBySeeker[pid])) or 1.0
						respawnHere(pid, hp)
						changed = true
						handled = true
					end
				end

				if not handled then
					if p.team == HS.const.TEAM_HIDERS and not taggingEnabled and infectionMode then
						notifyKillFeed(attackerForFeed, pid)

						HS.srv.setCurrentTeam(state, pid, HS.const.TEAM_SEEKERS)
						p.out = false

						local tr = HS.util.pickRandom(state.spawns.seekers) or GetPlayerTransform(pid)
						RespawnPlayerAtTransform(tr, pid)
						SetPlayerHealth(1.0, pid)

						if state.phase == HS.const.PHASE_HIDING then
							state.seekerLock = state.seekerLock or {}
							state.seekerLock[pid] = GetPlayerTransform(pid)
							SetPlayerWalkingSpeed(0.0, pid)
							SetPlayerCrouchSpeedScale(0.01, pid)
							SetPlayerVelocity(Vec(0, 0, 0), pid)
							ReleasePlayerGrab(pid)
						end

						changed = true
					else
						if p.team == HS.const.TEAM_HIDERS then
							notifyKillFeed(attackerForFeed, pid)
						end

						p.out = true
						HS.srv.moveToSpectator(state, pid)
						changed = true
					end
				end
			end
		end
	end

	if changed then
		HS.state.snapshot.syncFromSource(state)
	end
end
