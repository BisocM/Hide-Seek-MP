HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.timeSync = HS.cli.timeSync or {}

local TS = HS.cli.timeSync

local function now()
	return (HS.engine and HS.engine.now and HS.engine.now()) or 0
end

local function localPlayerId()
	return (HS.engine and HS.engine.localPlayerId and HS.engine.localPlayerId()) or 0
end

local function applySample(ctx, offset, rtt)
	if not ctx or not ctx.cache then
		TS._lastSample = { offset = offset, rtt = rtt, at = now() }
		return
	end

	offset = tonumber(offset) or 0
	rtt = tonumber(rtt) or 0
	if math.abs(offset) > 60 then return end

	local prev = ctx.cache._serverTimeOffset
	local alpha = (rtt > 0.20) and 0.12 or 0.22
	if prev == nil then
		ctx.cache._serverTimeOffset = offset
	else
		ctx.cache._serverTimeOffset = prev * (1.0 - alpha) + offset * alpha
	end

	ctx.cache._timeSyncLastAt = now()
	ctx.cache._timeSyncRtt = rtt
end

function TS.init()
	TS._seq = TS._seq or 0
	TS._pending = TS._pending or {}
	TS._sent = 0
	TS._nextAt = 0
end

function TS.tick(_dt, ctx, sh)
	if not sh then return end

	if TS._lastSample then
		local s = TS._lastSample
		TS._lastSample = nil
		applySample(ctx, s.offset, s.rtt)
	end

	local t = now()
	if t < (tonumber(TS._nextAt) or 0) then return end

	local pid = localPlayerId()
	if pid == 0 then return end

	TS._seq = (tonumber(TS._seq) or 0) + 1
	local seq = TS._seq
	TS._pending[seq] = t

	local rpc = HS.engine and HS.engine.serverRpc
	if rpc and rpc.timeSync then
		rpc.timeSync(pid, seq, t)
	end

	TS._sent = (tonumber(TS._sent) or 0) + 1
	local warmup = TS._sent <= 4
	TS._nextAt = t + (warmup and 0.35 or 2.0)
end

function client.hs_timeSync(seq, serverNow, clientSentAt)
	if not HS.cli or not HS.cli.timeSync then return end

	seq = tonumber(seq) or 0
	serverNow = tonumber(serverNow) or 0

	local t3 = now()
	local t0 = tonumber(clientSentAt)
	local pending = HS.cli.timeSync._pending
	if pending and pending[seq] ~= nil then
		t0 = tonumber(pending[seq]) or t0
		pending[seq] = nil
	end
	if t0 == nil then return end

	local rtt = t3 - t0
	if rtt < 0 or rtt > 3.0 then return end

	local offset = serverNow - (t0 + t3) * 0.5
	local ctx = HS.ctx and HS.ctx.get and HS.ctx.get() or nil
	applySample(ctx, offset, rtt)
end

