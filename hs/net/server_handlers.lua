HS = HS or {}
HS.net = HS.net or {}
HS.net.server = HS.net.server or {}

local N = HS.net.server

N._queue = N._queue or {}
N.maxQueue = N.maxQueue or 256

local function logWarn(msg, data)
	if HS.log and HS.log.warn then
		HS.log.warn(msg, data)
	end
end

local function clearQueue()
	for i = #N._queue, 1, -1 do
		N._queue[i] = nil
	end
end

function N.init()
	clearQueue()
end

function N.enqueue(name, playerId, payload)
	if #N._queue >= (N.maxQueue or 256) then
		table.remove(N._queue, 1)
	end
	N._queue[#N._queue + 1] = {
		name = tostring(name or ""),
		playerId = tonumber(playerId) or 0,
		payload = payload,
	}
end

function N.dispatch(cmd)
	if type(cmd) ~= "table" then return false end
	if not (HS.srv and HS.srv.rpc) then return false end

	if cmd.kind == "start" and HS.srv.rpc.start then
		HS.srv.rpc.start(cmd.playerId, cmd.settings)
		return true
	elseif cmd.kind == "requestTag" and HS.srv.rpc.requestTag then
		HS.srv.rpc.requestTag(cmd.playerId)
		return true
	elseif cmd.kind == "ability" and HS.srv.rpc.ability then
		HS.srv.rpc.ability(cmd.playerId, cmd.abilityId, cmd.event)
		return true
	elseif cmd.kind == "timeSync" and HS.srv.rpc.timeSync then
		HS.srv.rpc.timeSync(cmd.playerId, cmd.seq, cmd.clientSentAt)
		return true
	elseif cmd.kind == "updateLoadout" and HS.srv.rpc.updateLoadout then
		HS.srv.rpc.updateLoadout(cmd.playerId, cmd.loadout)
		return true
	elseif cmd.kind == "teamsJoinTeam" and HS.srv.rpc.teamJoin then
		HS.srv.rpc.teamJoin(cmd.playerId, cmd.teamId)
		return true
	end

	logWarn("Unsupported command kind", { kind = cmd.kind })
	return false
end

function N.drain()
	if #N._queue == 0 then return end

	for i = 1, #N._queue do
		local raw = N._queue[i]
		N._queue[i] = nil
		if raw then
			local cmd, err = HS.net.contract.parse(raw.name, raw.playerId, raw.payload)
			if cmd then
				local ok, dispatchErr = pcall(N.dispatch, cmd)
				if not ok then
					logWarn("Command dispatch failed", { err = tostring(dispatchErr), kind = cmd.kind })
				end
			else
				logWarn("Dropped invalid command", { reason = err, name = raw.name, playerId = raw.playerId })
			end
		end
	end
end

-- Public RPC entry points.
function server.hs_start(playerId, settings)
	N.enqueue("start", playerId, settings)
end

function server.hs_requestTag(playerId)
	N.enqueue("requestTag", playerId, nil)
end

function server.hs_useAbility(playerId, abilityId)
	N.enqueue("ability", playerId, { abilityId = abilityId, event = "use" })
end

function server.hs_triggerSuperjump(playerId)
	N.enqueue("ability", playerId, {
		abilityId = HS.abilities and HS.abilities.ids and HS.abilities.ids.superjump or "superjump",
		event = "trigger",
	})
end

function server.hs_ability(playerId, abilityId, event)
	N.enqueue("ability", playerId, { abilityId = abilityId, event = event })
end

function server.hs_timeSync(playerId, seq, clientSentAt)
	N.enqueue("timeSync", playerId, { seq = seq, clientSentAt = clientSentAt })
end

function server.hs_updateLoadout(playerId, loadout)
	N.enqueue("updateLoadout", playerId, loadout)
end

-- Team selection RPC kept behind command-ingress for deterministic setup handling.
function server._teamsJoinTeam(playerId, teamId)
	N.enqueue("teamsJoinTeam", playerId, { teamId = teamId })
end
