HS = HS or {}
HS.net = HS.net or {}
HS.net.server = HS.net.server or {}

local N = HS.net.server

N._queue = N._queue or {}
N.maxQueue = N.maxQueue or 512

local function clearQueue()
	for i = #N._queue, 1, -1 do
		N._queue[i] = nil
	end
end

local function logWarn(msg, data)
	if HS.log and HS.log.warn then
		HS.log.warn(msg, data)
	end
end

function N.init()
	clearQueue()
end

function N.enqueueEnvelope(envelope)
	if type(envelope) ~= "table" then
		return false
	end
	if #N._queue >= (N.maxQueue or 512) then
		table.remove(N._queue, 1)
	end
	N._queue[#N._queue + 1] = envelope
	return true
end

function N.drain()
	if #N._queue == 0 then return {} end
	local out = N._queue
	N._queue = {}
	return out
end

function server.hs_command(playerId, envelope)
	if type(envelope) ~= "table" then
		logWarn("Dropped non-table command envelope", { playerId = tonumber(playerId) or 0 })
		return
	end
	local env = envelope
	env.playerId = tonumber(playerId) or 0
	N.enqueueEnvelope(env)
end
