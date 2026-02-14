HS = HS or {}
HS.presentation = HS.presentation or {}
HS.presentation.client = HS.presentation.client or {}
HS.presentation.client.runtime = HS.presentation.client.runtime or {}

local P = HS.presentation.client.runtime

P._vfx = P._vfx or {}

local function now()
	if HS.util and HS.util.time and HS.util.time.now then
		return HS.util.time.now()
	end
	return (HS.engine and HS.engine.now and HS.engine.now()) or 0
end

local function trimQueue(q, maxN)
	while #q > maxN do
		table.remove(q, 1)
	end
end

local function resolveMessage(message, params)
	if type(message) == "table" and message.key and HS.t then
		return HS.t(message.key, params or message.params)
	end
	if type(message) == "string" and string.sub(message, 1, 3) == "hs." and HS.t then
		return HS.t(message, params)
	end
	return tostring(message or "")
end

local function clearArray(t)
	if HS.util and HS.util.table and HS.util.table.clearArray then
		HS.util.table.clearArray(t)
		return
	end
	for i = #t, 1, -1 do
		t[i] = nil
	end
end

local function teamName(teamId)
	if HS.select and HS.select.teamNameKey and HS.t then
		return HS.t(HS.select.teamNameKey(teamId))
	end
	if teamId == HS.const.TEAM_SEEKERS then return "Seekers" end
	if teamId == HS.const.TEAM_HIDERS then return "Hiders" end
	return "Team"
end

local function teamColor(teamId)
	if teamId == HS.const.TEAM_SEEKERS and type(COLOR_TEAM_2) == "table" then
		return { COLOR_TEAM_2[1] or 0.8, COLOR_TEAM_2[2] or 0.25, COLOR_TEAM_2[3] or 0.2, COLOR_TEAM_2[4] or 1 }
	end
	if teamId == HS.const.TEAM_HIDERS and type(COLOR_TEAM_1) == "table" then
		return { COLOR_TEAM_1[1] or 0.2, COLOR_TEAM_1[2] or 0.55, COLOR_TEAM_1[3] or 0.8, COLOR_TEAM_1[4] or 1 }
	end
	if HS.engine and HS.engine.teamColor then
		local c = HS.engine.teamColor(teamId)
		if type(c) == "table" then
			return { c[1] or 1, c[2] or 1, c[3] or 1 }
		end
	end
	if teamId == HS.const.TEAM_SEEKERS then return { 0.8, 0.25, 0.2, 1 } end
	if teamId == HS.const.TEAM_HIDERS then return { 0.2, 0.55, 0.8, 1 } end
	return { 1, 1, 1 }
end

local function sortedIdsFromMap(map)
	local ids = {}
	if type(map) ~= "table" then return ids end
	for pid in pairs(map) do
		local n = tonumber(pid)
		if n and n > 0 then
			ids[#ids + 1] = n
		end
	end
	table.sort(ids)
	return ids
end

local function syncSetupUiState(vm)
	if type(shared) ~= "table" or type(vm) ~= "table" then
		return
	end

	shared._hud = shared._hud or {}
	local inSetup = tostring(vm.phase or "") == HS.const.PHASE_SETUP
	local setupState = tostring(vm.uiHints and vm.uiHints.setupState or "waiting")
	shared._hud.gameIsSetup = (not inSetup) or setupState == "countdown" or setupState == "locked" or setupState == "done"

	shared._teamState = shared._teamState or {
		teams = {},
		state = _WAITING or 1,
		maxDiff = 1,
	}
	local ts = shared._teamState
	ts.teams = ts.teams or {}

	for i = 1, 2 do
		ts.teams[i] = ts.teams[i] or { name = "", color = { 1, 1, 1 }, players = {} }
		ts.teams[i].name = teamName(i)
		ts.teams[i].color = teamColor(i)
		ts.teams[i].players = ts.teams[i].players or {}
		clearArray(ts.teams[i].players)
	end

	ts.maxDiff = math.max(0, tonumber(vm.settings and vm.settings.maxTeamDiff) or 1)
	if tostring(vm.phase or "") == HS.const.PHASE_SETUP then
		local setupState = tostring(vm.uiHints and vm.uiHints.setupState or "waiting")
		if setupState == "countdown" then
			ts.state = _COUNTDOWN or 2
		elseif setupState == "locked" then
			ts.state = _LOCKED or 3
		elseif setupState == "done" then
			ts.state = _DONE or 4
		else
			ts.state = _WAITING or 1
		end
	else
		ts.state = _DONE or 4
	end

	local teamOf = vm.teamOf or {}
	for _, pid in ipairs(sortedIdsFromMap(teamOf)) do
		local teamId = tonumber(teamOf[pid]) or 0
		if teamId == 1 or teamId == 2 then
			local players = ts.teams[teamId].players
			players[#players + 1] = pid
		end
	end
end

function P.init()
	P._vfx = {}
	if type(hudInit) == "function" then
		hudInit(false)
	end
	if HS.cli and HS.cli.abilities and HS.cli.abilities.init then
		HS.cli.abilities.init()
	end
	if HS.cli and HS.cli.admin_menu and HS.cli.admin_menu.init then
		HS.cli.admin_menu.init()
	end
	if HS.cli and HS.cli.spectate and HS.cli.spectate.init then
		HS.cli.spectate.init()
	end
	if HS.cli and HS.cli.toast and HS.cli.toast.init then
		HS.cli.toast.init()
	end
	if HS.cli and HS.cli.feed and HS.cli.feed.init then
		HS.cli.feed.init()
	end
end

function P.tick(dt, ctx)
	local sh = HS.select and HS.select.shared and HS.select.shared() or nil
	local vm = sh and HS.select and HS.select.matchVm and HS.select.matchVm(ctx, sh) or nil
	if vm then
		syncSetupUiState(vm)
		if HS.cli and HS.cli.spectate and HS.cli.spectate.tick then
			HS.cli.spectate.tick(dt, ctx, vm)
		end
		if HS.cli and HS.cli.spectate and HS.cli.spectate.applyCamera then
			HS.cli.spectate.applyCamera(ctx, vm)
		end
		if HS.cli and HS.cli.abilities and HS.cli.abilities.tick then
			HS.cli.abilities.tick(dt, ctx, vm)
		end
		if HS.cli and HS.cli.admin_menu and HS.cli.admin_menu.tick then
			HS.cli.admin_menu.tick(dt, ctx, vm)
		end
	end
	if type(hudTick) == "function" then
		hudTick(tonumber(dt) or 0)
	end
	if HS.cli and HS.cli.toast and HS.cli.toast.tick then
		HS.cli.toast.tick(tonumber(dt) or 0)
	end
	if HS.cli and HS.cli.feed and HS.cli.feed.tick then
		HS.cli.feed.tick(tonumber(dt) or 0)
	end

	local t = now()
	for i = #P._vfx, 1, -1 do
		if t >= (tonumber(P._vfx[i].untilAt) or 0) then
			table.remove(P._vfx, i)
		end
	end
end

function P.draw(ctx)
	local sh = HS.select and HS.select.shared and HS.select.shared() or nil
	local vm = sh and HS.select and HS.select.matchVm and HS.select.matchVm(ctx, sh) or nil
	if not vm then return end

	syncSetupUiState(vm)

	local dt = tonumber(ctx and ctx.dt) or 0
	if tostring(vm.phase or "") == HS.const.PHASE_SETUP then
		if HS.cli and HS.cli.pregame and HS.cli.pregame.draw then
			HS.cli.pregame.draw(dt, ctx, vm)
		end
	else
		if HS.cli and HS.cli.drawInGame then
			HS.cli.drawInGame(dt, ctx, vm)
		end
		if HS.cli and HS.cli.abilities and HS.cli.abilities.draw then
			HS.cli.abilities.draw(ctx, vm)
		end
	end

	if HS.cli and HS.cli.admin_menu and HS.cli.admin_menu.draw then
		HS.cli.admin_menu.draw(dt, ctx, vm)
	end
	if type(hudDrawBanner) == "function" then
		hudDrawBanner(dt)
	end
	if HS.cli and HS.cli.feed and HS.cli.feed.draw then
		HS.cli.feed.draw()
	end
	if HS.cli and HS.cli.toast and HS.cli.toast.draw then
		HS.cli.toast.draw()
	end

	for i = 1, #P._vfx do
		local v = P._vfx[i]
		if type(v.pos) == "table" then
			ParticleReset()
			ParticleType("plain")
			ParticleRadius(0.12, 0.02, "easeout")
			ParticleAlpha(0.8, 0)
			ParticleEmissive(2.8, 0)
			ParticleColor(0.6, 0.85, 1.0)
			SpawnParticle(v.pos, Vec(0, 1.5, 0), 0.35)
		end
	end
end

function client.hs_toast(message, seconds, params)
	if HS.cli and HS.cli.toast and HS.cli.toast.show then
		HS.cli.toast.show(message, seconds, params)
	end
end

function client.hs_victory(winner)
	local text
	winner = tostring(winner or "")
	if winner == HS.const.WIN_SEEKERS then
		text = resolveMessage("hs.ui.victory.seekers")
	elseif winner == HS.const.WIN_HIDERS then
		text = resolveMessage("hs.ui.victory.hiders")
	else
		text = resolveMessage("hs.toast.roundOver")
	end
	if type(hudShowBanner) == "function" then
		local c = nil
		if winner == HS.const.WIN_SEEKERS then
			c = teamColor(HS.const.TEAM_SEEKERS)
		elseif winner == HS.const.WIN_HIDERS then
			c = teamColor(HS.const.TEAM_HIDERS)
		end
		hudShowBanner(text, c or { 0.2, 0.2, 0.2, 0.85 }, { 1, 1, 1, 1 })
	end
	if HS.cli and HS.cli.toast and HS.cli.toast.show then
		HS.cli.toast.show(text, 2.4)
	end
end

function client.hs_feedCaught(attackerId, victimId, method, attackerName, victimName, _cause)
	if HS.cli and HS.cli.feed and HS.cli.feed.push then
		HS.cli.feed.push(attackerId, victimId, method, attackerName, victimName)
	end
end

function client.hs_abilityVfx(abilityId, x, y, z, _dx, _dy, _dz, _x2, _y2, _z2, _sourcePlayerId)
	if HS.cli and HS.cli.abilities and HS.cli.abilities.enqueueVfx then
		HS.cli.abilities.enqueueVfx(
			tostring(abilityId or ""),
			Vec(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0),
			Vec(tonumber(_dx) or 0, tonumber(_dy) or 0, tonumber(_dz) or 0),
			Vec(tonumber(_x2) or 0, tonumber(_y2) or 0, tonumber(_z2) or 0),
			tonumber(_sourcePlayerId) or 0
		)
	end
	P._vfx[#P._vfx + 1] = {
		abilityId = tostring(abilityId or ""),
		pos = Vec(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0),
		untilAt = now() + 0.12,
	}
	trimQueue(P._vfx, 18)
end
