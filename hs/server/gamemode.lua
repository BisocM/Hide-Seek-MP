HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.app = HS.srv.app or HS.srv.gm or {}
HS.srv.gm = HS.srv.app -- legacy alias

local function setupTeamsForMode(state)
	if shared and shared._hud then
		shared._hud.gameIsSetup = false
	end
	teamsInit(2)
	teamsSetNames({ "hs.team.seekers", "hs.team.hiders" })
	teamsSetColors({ { 0.8, 0.25, 0.2, 1 }, { 0.2, 0.55, 0.8, 1 } })
	teamsSetMaxDiff(state and state.settings and state.settings.maxTeamDiff)
end

function HS.srv.app.applyHostSettings(state, settings)
	state.settings = state.settings or HS.defaults.make()
	local normalized = (HS.settings and HS.settings.normalize and HS.settings.normalize(settings, state.settings)) or (settings or state.settings)
	state.settings = normalized
	state._settingsCopy = HS.util.deepcopy(normalized)

	teamsSetMaxDiff(normalized.maxTeamDiff)
end

function HS.srv.app.resetToSetup(state, reason)
	state.matchActive = false
	state.round = 0
	state.lastWinner = ""
	state.scoreSeekers = 0
	state.scoreHiders = 0
	state.phase = HS.const.PHASE_SETUP
	state.phaseEndsAt = 0
	state.seekerLock = {}
	state.seekerGraceEndsAt = 0
	state.insufficientPlayersSince = nil

	setupTeamsForMode(state)

		for _, pid in ipairs(HS.util.getPlayersSorted()) do
			local p = state.players[pid]
			if p then
				p.team = 0
				p.baseTeam = 0
				p.ready = false
				p.out = false
				p.late = false
				p.abilities = {}
			end
	end

	HS.srv.syncShared(state)
	if reason and reason ~= "" then
		if HS.srv.notify and HS.srv.notify.toast then
			HS.srv.notify.toast(0, reason, 2.2)
		else
			HS.engine.clientCall(0, "client.hs_toast", tostring(reason), 2.2)
		end
	end
end

function HS.srv.app.init()
	SetRandomSeed(math.floor(HS.util.now() * 1000))

	hudInit(false)

	server.hs = {
		players = {},
		settings = HS.defaults.make(),
		phase = HS.const.PHASE_SETUP,
		phaseEndsAt = 0,
		seekerGraceEndsAt = 0,
		matchActive = false,
		round = 0,
		lastWinner = "",
		scoreSeekers = 0,
		scoreHiders = 0,
		seekerLock = {},
		spawns = HS.srv.collectSpawns(),
	}

	setupTeamsForMode(server.hs)

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		HS.srv.ensurePlayer(server.hs, pid)
	end

	HS.srv.syncShared(server.hs)
end

local function onTeamsLocked(state)
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = HS.srv.ensurePlayer(state, pid)
		p.team = teamsGetTeamId(pid)
		p.baseTeam = p.team
		p.ready = false
		p.out = false
		p.late = false
	end

	local c1, c2 = HS.srv.countTeams(state)
	if c1 == 0 or c2 == 0 then
		HS.srv.app.resetToSetup(state, "hs.toast.needPlayersPerTeam")
		return
	end

	HS.srv.beginRound(state)
end

local function syncPlayerRoster(state)
	state.players = state.players or {}
	state._presentPlayers = state._presentPlayers or {}
	local present = state._presentPlayers
	for k in pairs(present) do
		present[k] = nil
	end

	local changed = false
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		present[pid] = true
		if state.players[pid] == nil then
			changed = true
			local p = HS.srv.ensurePlayer(state, pid)
			if state.phase == HS.const.PHASE_SETUP then
				HS.srv.notify.toast(pid, "hs.toast.welcome", 2.4)
				else
					p.team = 0
					p.baseTeam = 0
					p.out = true
					p.late = true
					HS.srv.moveToSpectator(state, pid)
					HS.srv.notify.toast(pid, "hs.toast.lateJoin", 2.6)
			end
		end
	end

	for pid in pairs(state.players) do
		if not present[pid] then
			state.players[pid] = nil
			changed = true
		end
	end

	return changed
end

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

local function isSeekerGraceActive(state, now)
	if not state or not state.settings then return false end
	if state.phase ~= HS.const.PHASE_SEEKING then return false end
	if state.settings.allowHidersKillSeekers ~= true then return false end
	local endsAt = tonumber(state.seekerGraceEndsAt) or 0
	now = tonumber(now) or HS.util.now()
	return endsAt > 0 and now < endsAt
end

local function enforcePerTickRules(state)
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

local function handleSeekersNotKillableByHiders(state)
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

	local c = GetEventCount("playerhurt")
	for i = 1, c do
		local victim, before, after, attacker = GetEvent("playerhurt", i)
		local b = tonumber(before) or 0
		local a = tonumber(after) or 0
		if a < b then
			victim = tonumber(victim) or 0
			attacker = tonumber(attacker) or 0
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

local function handleHidersNotKillableBySeekers(state)
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

	local c = GetEventCount("playerhurt")
	for i = 1, c do
		local victim, before, after, attacker = GetEvent("playerhurt", i)
		local b = tonumber(before) or 0
		local a = tonumber(after) or 0
		if a < b then
			victim = tonumber(victim) or 0
			attacker = tonumber(attacker) or 0
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

local function handleDeaths(state)
	if state.phase ~= HS.const.PHASE_SEEKING and state.phase ~= HS.const.PHASE_HIDING then
		return
	end

	local taggingEnabled = state.settings.taggingEnabled == true
	local infectionMode = state.settings.infectionMode == true
	local allowHidersKillSeekers = state.settings.allowHidersKillSeekers == true
	local tagOnly = state.settings.tagOnlyMode == true
	local now = HS.util.now()
	local graceActive = isSeekerGraceActive(state, now)

	local attackerOf = {}
	local ec = GetEventCount("playerdied")
	for i = 1, ec do
		local victim, attacker = GetEvent("playerdied", i)
		if type(victim) == "number" and victim > 0 then
			attackerOf[victim] = tonumber(attacker) or 0
		end
	end

	local function isActiveSeeker(pid)
		if type(pid) ~= "number" or pid <= 0 then return false end
		if not IsPlayerValid(pid) then return false end
		local ap = state.players[pid]
		return ap and ap.team == HS.const.TEAM_SEEKERS and not ap.out
	end
	local function isActiveHider(pid)
		if type(pid) ~= "number" or pid <= 0 then return false end
		if not IsPlayerValid(pid) then return false end
		local ap = state.players[pid]
		return ap and ap.team == HS.const.TEAM_HIDERS and not ap.out
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
					local hurtByHider = ((not allowHidersKillSeekers) or tagOnly) and (state._seekerHurtByHider and (tonumber(state._seekerHurtByHider[pid]) or 0) > 0)
					if hurtByHider or (tagOnly and isActiveHider(attacker)) then
						p.out = false
						local hp = (state._seekerHurtByHider and tonumber(state._seekerHurtByHider[pid])) or 1.0
						respawnHere(pid, hp)
						changed = true
						handled = true
					end
				elseif p.team == HS.const.TEAM_HIDERS and tagOnly then
					local hurtBySeeker = state._hiderHurtBySeeker and (tonumber(state._hiderHurtBySeeker[pid]) or 0) > 0
					if hurtBySeeker or isActiveSeeker(attacker) then
						p.out = false
						local hp = (state._hiderHurtBySeeker and tonumber(state._hiderHurtBySeeker[pid])) or 1.0
						respawnHere(pid, hp)
						changed = true
						handled = true
					end
				end

				if not handled then
					if p.team == HS.const.TEAM_HIDERS and not taggingEnabled and infectionMode then
							if isActiveSeeker(attacker) then
								HS.srv.notify.feedCaught(0, attacker, pid, "kill")
							end

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
						if p.team == HS.const.TEAM_HIDERS and isActiveSeeker(attacker) then
							HS.srv.notify.feedCaught(0, attacker, pid, "kill")
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
		HS.srv.syncShared(state)
	end
end

function HS.srv.app.tick(dt)
	local st = server.hs
	if not st then return end

	HS.srv.app.systems = HS.srv.app.systems or {
		{
			name = "teams-setup",
			tick = function(_self, _ctx, state, dtt)
				if state.phase ~= HS.const.PHASE_SETUP then return false end
				teamsTick(dtt)
				if teamsIsSetup() then
					onTeamsLocked(state)
					return true
				end
				return false
			end,
		},
		{
			name = "players-roster",
			tick = function(_self, _ctx, state, _dtt)
				if syncPlayerRoster(state) then
					HS.srv.syncShared(state)
				end
				return false
			end,
		},
		{
			name = "lobby-guard",
			tick = function(_self, _ctx, state, _dtt)
				if state.phase == HS.const.PHASE_SETUP then return false end

				local count = tonumber(GetPlayerCount()) or 0
				if count < 2 then
					state.insufficientPlayersSince = state.insufficientPlayersSince or HS.util.now()
					if (HS.util.now() - state.insufficientPlayersSince) >= 1.0 then
						HS.srv.app.resetToSetup(state, "hs.toast.notEnoughPlayers")
						return true
					end
				else
					state.insufficientPlayersSince = nil
				end
				return false
			end,
		},
		{
			name = "rules-pre",
			tick = function(_self, _ctx, state, _dtt)
				enforcePerTickRules(state)
				handleSeekersNotKillableByHiders(state)
				handleHidersNotKillableBySeekers(state)
				handleDeaths(state)
				return false
			end,
		},
		{
			name = "match",
			tick = function(_self, _ctx, state, dtt)
				HS.srv.tickRound(state, dtt)
				return false
			end,
		},
		{
			name = "abilities",
			tick = function(_self, _ctx, state, dtt)
				if HS.srv.abilities and HS.srv.abilities.tick then
					if HS.srv.abilities.tick(state, dtt) then
						HS.srv.syncShared(state)
					end
				end
				return false
			end,
		},
		{
			name = "rules-post",
			tick = function(_self, _ctx, state, _dtt)
				enforcePerTickRules(state)
				return false
			end,
		},
	}

	local ctx = HS.ctx and HS.ctx.get and HS.ctx.get() or nil
	for i = 1, #HS.srv.app.systems do
		local sys = HS.srv.app.systems[i]
		local fn = sys and sys.tick
		if type(fn) == "function" then
			local ok, stop = pcall(fn, sys, ctx, st, dt)
			if not ok then
				local log = (ctx and ctx.log) or HS.log
				if log and log.error then
					log.error("Server system tick failed: " .. tostring(sys.name or i), { err = stop })
				end
			elseif stop == true then
				break
			end
		end
	end
end
