HS = HS or {}
HS.contracts = HS.contracts or {}
HS.contracts.schemas = HS.contracts.schemas or {}

local S = HS.contracts.schemas

S.COMMAND_SCHEMA = "hs.command.v1"
S.EVENT_SCHEMA = "hs.event.v1"
S.SNAPSHOT_SCHEMA = "hs.snapshot.v1"

local function safeString(v)
	return tostring(v or "")
end

local function safeNumber(v, fallback)
	local n = tonumber(v)
	if n == nil then
		return tonumber(fallback) or 0
	end
	return n
end

local function safeInt(v, fallback)
	local n = math.floor(safeNumber(v, fallback))
	if n < 0 then
		return 0
	end
	return n
end

local function safePayload(v)
	if type(v) == "table" then
		return v
	end
	return {}
end

function S.commandEnvelope(input)
	if type(input) ~= "table" then
		return nil, "command envelope must be a table"
	end

	local env = {
		id = safeString(input.id),
		type = safeString(input.type),
		playerId = safeInt(input.playerId, 0),
		clientTime = safeNumber(input.clientTime, 0),
		payload = safePayload(input.payload),
		nonce = safeString(input.nonce),
	}

	return env, nil
end

function S.eventEnvelope(input)
	if type(input) ~= "table" then
		return nil, "event envelope must be a table"
	end

	local env = {
		tick = safeInt(input.tick, 0),
		type = safeString(input.type),
		payload = safePayload(input.payload),
	}

	return env, nil
end

function S.emptySnapshot()
	return {
		meta = {
			version = 1,
			schema = S.SNAPSHOT_SCHEMA,
			revision = 0,
			serverNow = 0,
		},
		match = {
			phase = (HS.const and HS.const.PHASE_SETUP) or "setup",
			phaseEndsAt = 0,
			round = 0,
			lastWinner = "",
			matchActive = false,
			scoreSeekers = 0,
			scoreHiders = 0,
			hidersRemaining = 0,
			seekersCount = 0,
		},
		players = {
			teamOf = {},
			readyOf = {},
			outOf = {},
		},
		abilities = {
			readyAt = {},
			armedUntil = {},
		},
		settings = {},
		uiHints = {},
	}
end
