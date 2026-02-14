HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.model = HS.domain.model or {}

local M = HS.domain.model

local function clampInt(v, minV, maxV)
	local n = math.floor(tonumber(v) or 0)
	if n < minV then return minV end
	if n > maxV then return maxV end
	return n
end

local function defaultSettings()
	return {
		hideSeconds = 20,
		seekSeconds = 300,
		intermissionSeconds = 10,
		roundsToPlay = 5,
		infectionMode = true,
		swapTeamsEachRound = true,
		maxTeamDiff = 1,
		seekerGraceSeconds = 5,
		tagRangeMeters = 4.0,
		taggingEnabled = true,
		tagOnlyMode = false,
		allowHidersKillSeekers = false,
		hiderAbilitiesEnabled = true,
		healthRegenEnabled = true,
		hiderTrailEnabled = true,
		seekerMapEnabled = false,
		requireAllReady = false,
		loadout = { enabled = false, tools = {}, assign = {} },
	}
end

local function copySettings(input)
	local inS = type(input) == "table" and input or {}
	local out = defaultSettings()
	for k, v in pairs(inS) do
		out[k] = v
	end
	return out
end

function M.newPlayerState()
	return {
		team = 0,
		baseTeam = 0,
		ready = false,
		out = false,
		late = false,
		abilities = {},
	}
end

function M.newState(opts)
	opts = type(opts) == "table" and opts or {}
		local st = {
			players = {},
			settings = copySettings(opts.settings),
			phase = (HS.const and HS.const.PHASE_SETUP) or "setup",
			setupState = "waiting",
			setupEndsAt = 0,
			phaseEndsAt = 0,
			seekerGraceEndsAt = 0,
			matchActive = false,
		round = 0,
		lastWinner = "",
		scoreSeekers = 0,
		scoreHiders = 0,
		spawns = type(opts.spawns) == "table" and opts.spawns or {
			seekers = {},
			hiders = {},
			spectators = {},
			ffa = {},
		},
	}
	return st
end

function M.clone(state)
	if HS.util and HS.util.deepcopy then
		return HS.util.deepcopy(state)
	end
	local copy = {}
	for k, v in pairs(state or {}) do
		copy[k] = v
	end
	return copy
end

function M.ensurePlayer(state, playerId)
	if type(state) ~= "table" then return nil end
	state.players = state.players or {}
	local pid = tonumber(playerId) or 0
	if pid <= 0 then return nil end
	if state.players[pid] == nil then
		state.players[pid] = M.newPlayerState()
	end
	local p = state.players[pid]
	if type(p.abilities) ~= "table" then
		p.abilities = {}
	end
	return p
end

function M.sortedPlayerIds(state)
	local ids = {}
	if type(state) ~= "table" or type(state.players) ~= "table" then
		return ids
	end
	for pid in pairs(state.players) do
		local n = tonumber(pid)
		if n and n > 0 then
			ids[#ids + 1] = n
		end
	end
	table.sort(ids)
	return ids
end

function M.countAlive(state, teamId)
	local n = 0
	for _, pid in ipairs(M.sortedPlayerIds(state)) do
		local p = state.players[pid]
		if p and p.team == teamId and p.out ~= true then
			n = n + 1
		end
	end
	return n
end

function M.clampTeamId(teamId)
	teamId = clampInt(teamId, 0, 2)
	return teamId
end

function M.ensureAbilityState(player, abilityId)
	player.abilities = player.abilities or {}
	abilityId = tostring(abilityId or "")
	if abilityId == "" then
		return nil
	end
	if type(player.abilities[abilityId]) ~= "table" then
		player.abilities[abilityId] = { readyAt = 0, armedUntil = 0 }
	end
	local ab = player.abilities[abilityId]
	ab.readyAt = tonumber(ab.readyAt) or 0
	ab.armedUntil = tonumber(ab.armedUntil) or 0
	return ab
end
