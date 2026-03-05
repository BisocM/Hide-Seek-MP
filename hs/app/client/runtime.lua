HS = HS or {}
HS.app = HS.app or {}
HS.app.clientRuntime = HS.app.clientRuntime or {}

local R = HS.app.clientRuntime

R._timeSync = R._timeSync or {
	nextAt = 0,
	seq = 0,
	offset = 0,
	lastSyncAt = 0,
	pending = {},
}

local function now()
	if HS.util and HS.util.time and HS.util.time.now then
		return HS.util.time.now()
	end
	return (HS.engine and HS.engine.now and HS.engine.now()) or 0
end

local function localPlayerId()
	return (HS.engine and HS.engine.localPlayerId and HS.engine.localPlayerId()) or 0
end

local function handleSetupInput(vm)
	if not vm or vm.phase ~= HS.const.PHASE_SETUP then return end
	if not (HS.app and HS.app.commands) then return end
	local pid = localPlayerId()
	if pid <= 0 then return end

	if HS.input and HS.input.keyPressed then
		if HS.input.keyPressed("abilityDash") then
			HS.app.commands.teamJoin(HS.const.TEAM_SEEKERS, pid)
		elseif HS.input.keyPressed("abilitySuperjump") then
			HS.app.commands.teamJoin(HS.const.TEAM_HIDERS, pid)
		elseif HS.input.keyPressed("abilitySlot3") then
			HS.app.commands.teamJoin(0, pid)
		end
	end
end

local function handleGameplayInput(vm)
	if not vm then return end
	if vm.phase ~= HS.const.PHASE_HIDING and vm.phase ~= HS.const.PHASE_SEEKING then
		return
	end
	if not vm.me or vm.me.id <= 0 then return end
	if not (HS.app and HS.app.commands) then return end

	if vm.phase == HS.const.PHASE_SEEKING and vm.settings and vm.settings.taggingEnabled == true and vm.me.team == HS.const.TEAM_SEEKERS and vm.me.out ~= true then
		if HS.input and HS.input.pressed and HS.input.pressed("tag") then
			HS.app.commands.requestTag(vm.me.id)
		end
	end
end

local function tickTimeSync(vm)
	if not vm or not vm.me or vm.me.id <= 0 then return end
	local ts = R._timeSync
	local t = now()
	if t < (tonumber(ts.nextAt) or 0) then return end
	if not (HS.app and HS.app.commands and HS.app.commands.timeSync) then return end

	ts.seq = (tonumber(ts.seq) or 0) + 1
	local seq = ts.seq
	ts.pending[seq] = t
	HS.app.commands.timeSync(seq, t, vm.me.id, t)
	ts.nextAt = t + 2.0
end

function R.init()
	R._timeSync = {
		nextAt = 0,
		seq = 0,
		offset = 0,
		lastSyncAt = 0,
		pending = {},
	}
	if HS.net and HS.net.client and HS.net.client.init then
		HS.net.client.init()
	end
end

function R.tick(_dt, ctx)
	local sh = HS.select and HS.select.shared and HS.select.shared() or nil
	local vm = sh and HS.select and HS.select.matchVm and HS.select.matchVm(ctx, sh) or nil
	if not vm then return end

	handleSetupInput(vm)
	handleGameplayInput(vm)
	tickTimeSync(vm)
end

function client.hs_timeSync(seq, serverNow, clientSentAt)
	local ts = R._timeSync
	seq = tonumber(seq) or 0
	serverNow = tonumber(serverNow) or 0
	local t3 = now()
	local t0 = tonumber(clientSentAt)
	if ts.pending and ts.pending[seq] ~= nil then
		t0 = tonumber(ts.pending[seq]) or t0
		ts.pending[seq] = nil
	end
	if t0 == nil then return end

	local rtt = t3 - t0
	if rtt < 0 or rtt > 3.0 then return end
	local offset = serverNow - ((t0 + t3) * 0.5)
	ts.offset = (tonumber(ts.offset) or 0) * 0.75 + offset * 0.25
	ts.lastSyncAt = t3
	local ctx = HS.ctx and HS.ctx.get and HS.ctx.get() or nil
	if ctx and type(ctx) == "table" then
		ctx.cache = ctx.cache or {}
		ctx.cache._serverTimeOffset = ts.offset
		ctx.cache._timeSyncLastAt = t3
	end
end
