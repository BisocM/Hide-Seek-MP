HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.events = HS.infra.events or {}

local E = HS.infra.events

E._tick = E._tick or 0

local function nextTick()
	E._tick = (tonumber(E._tick) or 0) + 1
	return E._tick
end

local function logWarn(msg, data)
	if HS.log and HS.log.warn then
		HS.log.warn(msg, data)
	end
end

function E.emit(targetPlayerId, eventType, payload)
	local validate = HS.contracts and HS.contracts.validate
	local env, err = validate and validate.eventEnvelope and validate.eventEnvelope({
		tick = nextTick(),
		type = tostring(eventType or ""),
		payload = type(payload) == "table" and payload or {},
	})
	if not env then
		logWarn("Dropped invalid event envelope", { reason = err, type = eventType })
		return false
	end
	return HS.engine.clientCall(tonumber(targetPlayerId) or 0, "client.hs_event", env)
end

function E.reset()
	E._tick = 0
end
