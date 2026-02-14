HS = HS or {}
HS.app = HS.app or {}
HS.app.commands = HS.app.commands or {}

local C = HS.app.commands

C._seq = C._seq or 0

local function logWarn(msg, data)
	if HS.log and HS.log.warn then
		HS.log.warn(msg, data)
	end
end

local function now()
	if HS.util and HS.util.time and HS.util.time.now then
		return HS.util.time.now()
	end
	return (HS.engine and HS.engine.now and HS.engine.now()) or 0
end

local function localPlayerId()
	return (HS.engine and HS.engine.localPlayerId and HS.engine.localPlayerId()) or 0
end

local function buildEnvelope(commandType, playerId, payload, clientTime)
	local validate = HS.contracts and HS.contracts.validate
	local T = HS.contracts and HS.contracts.commandTypes
	if not (T and T.isKnown and T.isKnown(commandType)) then
		return nil, "unknown command type"
	end

	local pid = tonumber(playerId) or 0
	if pid <= 0 then
		return nil, "invalid player id"
	end

	local t = tonumber(clientTime)
	if t == nil then t = now() end
	C._seq = (tonumber(C._seq) or 0) + 1

	local env = {
		id = string.format("cmd:%d:%d:%d", pid, math.floor(t * 1000), C._seq),
		type = commandType,
		playerId = pid,
		clientTime = t,
		payload = type(payload) == "table" and payload or {},
		nonce = string.format("%d:%d:%d", pid, math.floor(t * 1000), C._seq),
	}

	local normalized, err = validate and validate.commandEnvelope and validate.commandEnvelope(env)
	if not normalized then
		return nil, err or "invalid command envelope"
	end
	return normalized, nil
end

local function sendEnvelope(playerId, env)
	if not (HS.engine and HS.engine.serverCall) then
		return false
	end
	return HS.engine.serverCall("server.hs_command", playerId, env) == true
end

function C.send(commandType, payload, playerId, clientTime)
	local pid = tonumber(playerId)
	if pid == nil or pid <= 0 then
		pid = localPlayerId()
	end
	if pid <= 0 then
		logWarn("Unable to send command without local player id", { type = tostring(commandType or "") })
		return false
	end

	local env, err = buildEnvelope(commandType, pid, payload, clientTime)
	if not env then
		logWarn("Failed to build command envelope", { type = tostring(commandType or ""), err = tostring(err) })
		return false
	end
	return sendEnvelope(pid, env)
end

function C.startMatch(payload, playerId, clientTime)
	local T = HS.contracts and HS.contracts.commandTypes
	return C.send(T and T.START_MATCH or "start_match", { settings = payload or {} }, playerId, clientTime)
end

function C.requestTag(playerId, clientTime)
	local T = HS.contracts and HS.contracts.commandTypes
	return C.send(T and T.REQUEST_TAG or "request_tag", {}, playerId, clientTime)
end

function C.ability(abilityId, event, playerId, clientTime, extraPayload)
	local T = HS.contracts and HS.contracts.commandTypes
	local payload = {
		abilityId = tostring(abilityId or ""),
		event = tostring(event or "use"),
	}
	if type(extraPayload) == "table" then
		for k, v in pairs(extraPayload) do
			local key = tostring(k or "")
			if key ~= "abilityId" and key ~= "event" then
				payload[key] = v
			end
		end
	end
	return C.send(T and T.ABILITY or "ability", payload, playerId, clientTime)
end

function C.timeSync(seq, clientSentAt, playerId, clientTime)
	local T = HS.contracts and HS.contracts.commandTypes
	return C.send(T and T.TIME_SYNC or "time_sync", {
		seq = tonumber(seq) or 0,
		clientSentAt = tonumber(clientSentAt) or 0,
	}, playerId, clientTime)
end

function C.updateLoadout(loadout, playerId, clientTime)
	local T = HS.contracts and HS.contracts.commandTypes
	return C.send(T and T.UPDATE_LOADOUT or "update_loadout", {
		loadout = type(loadout) == "table" and loadout or {},
	}, playerId, clientTime)
end

function C.teamJoin(teamId, playerId, clientTime)
	local T = HS.contracts and HS.contracts.commandTypes
	return C.send(T and T.TEAM_JOIN or "team_join", {
		teamId = tonumber(teamId) or 0,
	}, playerId, clientTime)
end
