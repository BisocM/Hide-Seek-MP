
HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.abilities = HS.srv.abilities or {}

local S = HS.srv.abilities

S.impl = S.impl or {}

local function isActivePhase(phase)
	return phase == HS.const.PHASE_HIDING or phase == HS.const.PHASE_SEEKING
end

local function getPlayer(state, playerId)
	if not state or not state.players then return nil end
	return state.players[playerId]
end

function S.register(abilityId, impl)
	abilityId = tostring(abilityId or "")
	if abilityId == "" then return false end
	if type(impl) ~= "table" then return false end
	S.impl[abilityId] = impl
	return true
end

if type(S._pendingImpl) == "table" then
	local pending = S._pendingImpl
	S._pendingImpl = nil
	for i = 1, #pending do
		local it = pending[i]
		if type(it) == "table" then
			S.register(it.id, it.impl)
		end
	end
end

function S.stateFor(state, playerId, abilityId)
	local p = getPlayer(state, playerId)
	if not p then return nil end
	p.abilities = p.abilities or {}
	local ab = p.abilities[abilityId]
	if ab == nil then
		ab = {}
		p.abilities[abilityId] = ab
	end
	ab.readyAt = tonumber(ab.readyAt) or 0
	ab.armedUntil = tonumber(ab.armedUntil) or 0
	return ab
end

function S.canExecuteAbility(state, playerId, def, _event, now)
	if not def then return false end
	if not IsPlayerValid(playerId) then return false end
	if not state or not state.players then return false end
	if not isActivePhase(state.phase) then return false end

	local p = state.players[playerId]
	if not p then return false end
	if p.out then return false end
	if p.team ~= def.team then return false end
	if def.team == HS.const.TEAM_HIDERS and state.settings and state.settings.hiderAbilitiesEnabled == false then
		return false
	end

	now = tonumber(now) or HS.util.now()
	return now >= 0
end

function S.executeAbility(state, playerId, abilityId, event)
	abilityId = tostring(abilityId or "")
	event = tostring(event or "use")

	local def = HS.abilities and HS.abilities.def and HS.abilities.def(abilityId) or nil
	if not def then return false end

	local impl = S.impl[def.id]
	if not impl or type(impl.execute) ~= "function" then return false end

	local now = HS.util.now()
	if not S.canExecuteAbility(state, playerId, def, event, now) then
		return false
	end

	local ab = S.stateFor(state, playerId, def.id)
	if not ab then return false end

	if event == "use" and now < (tonumber(ab.readyAt) or 0) then
		return false
	end

	if type(impl.canExecute) == "function" then
		local ok = impl.canExecute(state, playerId, event, now, def, ab)
		if ok ~= true then return false end
	end

	return impl.execute(state, playerId, event, now, def, ab) == true
end

function S.tryUse(state, playerId, abilityId)
	return S.executeAbility(state, playerId, abilityId, "use")
end

function S.tryTriggerSuperjump(state, playerId)
	local id = (HS.abilities and HS.abilities.ids and HS.abilities.ids.superjump) or "superjump"
	return S.executeAbility(state, playerId, id, "trigger")
end

function S.resetRound(state)
	if not state or not state.players then return end
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		local p = state.players[pid]
		if p then
			p.abilities = {}
		end
	end
end

function S.tick(state, dt)
	if not state or not state.players then return false end
	if not isActivePhase(state.phase) then return false end

	dt = tonumber(dt) or 0
	local now = HS.util.now()
	local changed = false

	for _, def in ipairs(HS.abilities.list()) do
		local impl = S.impl[def.id]
		if impl and type(impl.tick) == "function" then
			if impl.tick(state, dt, now, def) == true then
				changed = true
			end
		end
	end

	return changed
end

#include "abilities/dash.lua"
#include "abilities/superjump.lua"
