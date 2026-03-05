HS = HS or {}
HS.contracts = HS.contracts or {}
HS.contracts.validate = HS.contracts.validate or {}

local V = HS.contracts.validate

local function isNonEmptyString(v)
	return type(v) == "string" and v ~= ""
end

local function isTable(v)
	return type(v) == "table"
end

local function isPositiveNumber(v)
	local n = tonumber(v)
	return n ~= nil and n > 0
end

local function isNonNegativeNumber(v)
	local n = tonumber(v)
	return n ~= nil and n >= 0
end

local function requireTableKey(t, key)
	if type(t) ~= "table" then
		return false
	end
	return type(t[key]) == "table"
end

function V.commandEnvelope(input)
	local schemas = HS.contracts and HS.contracts.schemas
	local types = HS.contracts and HS.contracts.commandTypes
	if not schemas then
		return nil, "missing contracts.schemas"
	end

	local env, schemaErr = schemas.commandEnvelope(input)
	if not env then
		return nil, schemaErr
	end
	if not isNonEmptyString(env.id) then
		return nil, "missing command id"
	end
	if not isNonEmptyString(env.nonce) then
		return nil, "missing command nonce"
	end
	if tonumber(env.playerId) == nil or tonumber(env.playerId) <= 0 then
		return nil, "invalid command playerId"
	end
	if tonumber(env.clientTime) == nil then
		return nil, "invalid command clientTime"
	end
	if not isTable(env.payload) then
		return nil, "invalid command payload"
	end
	if not (types and types.isKnown and types.isKnown(env.type)) then
		return nil, "unknown command type"
	end

	if env.type == types.ABILITY then
		local abilityId = tostring(env.payload.abilityId or "")
		if abilityId == "" then
			return nil, "ability command missing abilityId"
		end
	end
	if env.type == types.TEAM_JOIN then
		local teamId = tonumber(env.payload.teamId)
		if teamId == nil then
			return nil, "team_join command missing teamId"
		end
	end

	return env, nil
end

function V.eventEnvelope(input)
	local schemas = HS.contracts and HS.contracts.schemas
	local types = HS.contracts and HS.contracts.eventTypes
	if not schemas then
		return nil, "missing contracts.schemas"
	end

	local env, schemaErr = schemas.eventEnvelope(input)
	if not env then
		return nil, schemaErr
	end
	if tonumber(env.tick) == nil or env.tick < 0 then
		return nil, "invalid event tick"
	end
	if not (types and types.isKnown and types.isKnown(env.type)) then
		return nil, "unknown event type"
	end
	if not isTable(env.payload) then
		return nil, "invalid event payload"
	end

	if env.type == types.FEED_CAUGHT then
		local payload = env.payload
		if not isNonNegativeNumber(payload.attackerId) then
			return nil, "feed_caught missing attackerId"
		end
		if not isPositiveNumber(payload.victimId) then
			return nil, "feed_caught missing victimId"
		end
		local method = tostring(payload.method or "")
		if method ~= "tag" and method ~= "kill" and method ~= "self" then
			return nil, "feed_caught invalid method"
		end
		if payload.cause ~= nil and type(payload.cause) ~= "string" then
			return nil, "feed_caught invalid cause"
		end
		if payload.attackerName ~= nil and type(payload.attackerName) ~= "string" then
			return nil, "feed_caught invalid attackerName"
		end
		if payload.victimName ~= nil and type(payload.victimName) ~= "string" then
			return nil, "feed_caught invalid victimName"
		end
	end

	return env, nil
end

function V.snapshot(snapshot)
	if type(snapshot) ~= "table" then
		return false, "snapshot must be a table"
	end

	if not requireTableKey(snapshot, "meta") then
		return false, "snapshot.meta missing"
	end
	if not requireTableKey(snapshot, "match") then
		return false, "snapshot.match missing"
	end
	if not requireTableKey(snapshot, "players") then
		return false, "snapshot.players missing"
	end
	if not requireTableKey(snapshot, "abilities") then
		return false, "snapshot.abilities missing"
	end
	if not requireTableKey(snapshot, "settings") then
		return false, "snapshot.settings missing"
	end
	if not requireTableKey(snapshot, "uiHints") then
		return false, "snapshot.uiHints missing"
	end

	local meta = snapshot.meta
	local match = snapshot.match
	local players = snapshot.players
	local abilities = snapshot.abilities

	if tonumber(meta.version) == nil then
		return false, "snapshot.meta.version missing"
	end
	if not isNonEmptyString(meta.schema) then
		return false, "snapshot.meta.schema missing"
	end
	if tonumber(meta.revision) == nil then
		return false, "snapshot.meta.revision missing"
	end
	if tonumber(meta.serverNow) == nil then
		return false, "snapshot.meta.serverNow missing"
	end

	if not isNonEmptyString(match.phase) then
		return false, "snapshot.match.phase missing"
	end
	if tonumber(match.phaseEndsAt) == nil then
		return false, "snapshot.match.phaseEndsAt missing"
	end
	if tonumber(match.round) == nil then
		return false, "snapshot.match.round missing"
	end
	if type(match.lastWinner) ~= "string" then
		return false, "snapshot.match.lastWinner missing"
	end
	if type(match.matchActive) ~= "boolean" then
		return false, "snapshot.match.matchActive missing"
	end

	if not requireTableKey(players, "teamOf") then
		return false, "snapshot.players.teamOf missing"
	end
	if not requireTableKey(players, "readyOf") then
		return false, "snapshot.players.readyOf missing"
	end
	if not requireTableKey(players, "outOf") then
		return false, "snapshot.players.outOf missing"
	end

	if not requireTableKey(abilities, "readyAt") then
		return false, "snapshot.abilities.readyAt missing"
	end
	if not requireTableKey(abilities, "armedUntil") then
		return false, "snapshot.abilities.armedUntil missing"
	end

	return true, nil
end
