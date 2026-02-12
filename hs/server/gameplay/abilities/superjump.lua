HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.abilities = HS.srv.abilities or {}

local S = HS.srv.abilities

local function clamp(v, a, b)
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

local function setPlayerVelocitySafe(playerId, v)
	if type(SetPlayerVelocity) ~= "function" then return end
	pcall(SetPlayerVelocity, v, playerId)
end

local function currentVelocity(playerId)
	if type(GetPlayerVelocity) ~= "function" then return Vec(0, 0, 0) end
	local ok, vel = pcall(GetPlayerVelocity, playerId)
	if ok and type(vel) == "table" then return vel end
	return Vec(0, 0, 0)
end

local Super = {}

function Super.canExecute(_state, _playerId, event, now, _def, ab)
	if event == "use" then
		if HS.abilities.isArmed(now, ab.armedUntil) then return false end
		return true
	end
	if event == "trigger" then
		return HS.abilities.isArmed(now, ab.armedUntil)
	end
	return false
end

function Super.execute(_state, playerId, event, now, def, ab)
	local cfg = def.cfg or {}
	if event == "use" then
		local armSeconds = clamp(cfg.armSeconds or 6.0, 0.25, 20.0)
		ab.armedUntil = now + armSeconds
		ab.readyAt = now + clamp(def.cooldownSeconds or 12.0, 0.1, 120.0)
		return true
	end

	ab.armedUntil = 0
	ab.boostUntil = now + 0.18
	ab.boost = clamp(cfg.jumpBoost or 14.0, 2.0, 40.0)

	local contact, _, point = GetPlayerGroundContact(playerId)
	local pos = (contact and point) or VecAdd(GetPlayerTransform(playerId).pos, Vec(0, -0.95, 0))
	if HS.srv.notify and HS.srv.notify.abilityVfx then
		HS.srv.notify.abilityVfx(0, def.id, pos, Vec(0, 1, 0), pos, playerId)
	else
		HS.engine.clientCall(0, "client.hs_abilityVfx", tostring(def.id), pos[1], pos[2], pos[3], 0, 1, 0, pos[1], pos[2], pos[3], playerId)
	end

	return true
end

function Super.tick(state, _dt, now, def)
	if not def or not def.id then return false end
	local ids = HS.util.getPlayersSorted()
	for i = 1, #ids do
		local pid = ids[i]
		if IsPlayerValid(pid) then
			local p = state.players[pid]
			if p and p.abilities then
				local ab = p.abilities[def.id]
				if ab and (tonumber(ab.boostUntil) or 0) > now then
					local vel = currentVelocity(pid)
					local nx = tonumber(vel[1]) or 0
					local ny = tonumber(vel[2]) or 0
					local nz = tonumber(vel[3]) or 0
					local boost = tonumber(ab.boost) or 0
					if boost > 0 then
						setPlayerVelocitySafe(pid, Vec(nx, math.max(ny, boost), nz))
					end
				elseif ab and ab.boostUntil then
					ab.boostUntil = 0
					ab.boost = 0
				end
			end
		end
	end
	return false
end

local function register(id, impl)
	if type(S.register) == "function" then
		return S.register(id, impl)
	end
	S._pendingImpl = S._pendingImpl or {}
	S._pendingImpl[#S._pendingImpl + 1] = { id = id, impl = impl }
	return true
end

register((HS.abilities and HS.abilities.ids and HS.abilities.ids.superjump) or "superjump", Super)
