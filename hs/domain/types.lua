HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.types = HS.domain.types or {}

local T = HS.domain.types

local function defaultsSettings()
	if HS.defaults and HS.defaults.make then
		return HS.defaults.make()
	end
	if HS.settings and HS.settings.defaults then
		return HS.settings.defaults()
	end
	return {}
end

function T.newPlayerState()
	return {
		team = 0,
		baseTeam = 0,
		ready = false,
		out = false,
		late = false,
		abilities = {},
	}
end

function T.newMatchState(overrides)
	local st = {
		players = {},
		settings = defaultsSettings(),
		phase = (HS.const and HS.const.PHASE_SETUP) or "setup",
		phaseEndsAt = 0,
		seekerGraceEndsAt = 0,
		matchActive = false,
		round = 0,
		lastWinner = "",
		scoreSeekers = 0,
		scoreHiders = 0,
		seekerLock = {},
		spawns = { seekers = {}, hiders = {}, spectators = {}, ffa = {} },
	}

	if type(overrides) == "table" then
		for k, v in pairs(overrides) do
			st[k] = v
		end
	end

	if type(st.players) ~= "table" then
		st.players = {}
	end
	if type(st.settings) ~= "table" then
		st.settings = defaultsSettings()
	end
	return st
end

function T.ensurePlayer(st, playerId)
	if type(st) ~= "table" then return nil end
	st.players = st.players or {}
	if st.players[playerId] == nil then
		st.players[playerId] = T.newPlayerState()
	end
	return st.players[playerId]
end
