HS = HS or {}
HS.srv = HS.srv or {}
HS.srv.abilities = HS.srv.abilities or {}

local S = HS.srv.abilities

local function clamp(v, a, b)
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

local function isFn(f) return type(f) == "function" end

local function dashDirection(playerId)
	local cam = nil
	if isFn(GetPlayerCameraTransform) then
		local ok, tr = pcall(GetPlayerCameraTransform, playerId)
		if ok and type(tr) == "table" then
			cam = tr
		end
	end
	local dir = nil
	if type(cam) == "table" then
		dir = TransformToParentVec(cam, Vec(0, 0, -1))
	end
	if type(dir) ~= "table" then
		local tr = GetPlayerTransform(playerId)
		dir = TransformToParentVec(tr, Vec(0, 0, -1))
	end
	dir = Vec(dir[1] or 0, 0, dir[3] or 0)
	if VecLength(dir) < 0.001 then
		return Vec(0, 0, -1)
	end
	return VecNormalize(dir)
end

local function setPlayerVelocitySafe(playerId, v)
	if not isFn(SetPlayerVelocity) then return end
	pcall(SetPlayerVelocity, v, playerId)
end

local function releaseGrabSafe(playerId)
	if not isFn(ReleasePlayerGrab) then return end
	pcall(ReleasePlayerGrab, playerId)
end

local function currentVelocity(playerId)
	if not isFn(GetPlayerVelocity) then return Vec(0, 0, 0) end
	local ok, vel = pcall(GetPlayerVelocity, playerId)
	if ok and type(vel) == "table" then return vel end
	return Vec(0, 0, 0)
end

local Dash = {}

function Dash.canExecute(_state, _playerId, event, _now, _def, _ab)
	if event ~= "use" then return false end
	return true
end

function Dash.execute(state, playerId, _event, now, def, ab)
	if not state or not state.players or not state.players[playerId] then return false end

	local dir = dashDirection(playerId)
	local tr = GetPlayerTransform(playerId)
	local origin = VecAdd(tr.pos, Vec(0, 0.9, 0))
	local cfg = (def and def.cfg) or {}
	local duration = clamp(cfg.durationSeconds or 0.25, 0.08, 0.60)
	local dist = clamp(cfg.distance or 5.5, 0.5, 20.0)
	local speed = clamp(dist / duration, 1.0, 48.0)
	local endPos = VecAdd(origin, VecScale(dir, dist))

	if HS.srv.notify and HS.srv.notify.abilityVfx then
		HS.srv.notify.abilityVfx(0, def.id, origin, dir, endPos, playerId)
	else
		HS.engine.clientCall(0, "client.hs_abilityVfx", tostring(def.id), origin[1], origin[2], origin[3], dir[1], dir[2], dir[3], endPos[1], endPos[2], endPos[3], playerId)
	end

	ab.activeUntil = now + duration
	ab.dirX = dir[1] or 0
	ab.dirZ = dir[3] or 0
	ab.speed = speed

	local vel = currentVelocity(playerId)
	local ny = tonumber(vel[2]) or 0
	setPlayerVelocitySafe(playerId, Vec(ab.dirX * speed, ny, ab.dirZ * speed))
	releaseGrabSafe(playerId)

	ab.readyAt = now + clamp(def.cooldownSeconds or 8.0, 0.1, 120.0)
	return true
end

function Dash.tick(state, _dt, now, def)
	if not def or not def.id then return false end
	local ids = HS.util.getPlayersSorted()

	local durationGuard = clamp((def and def.cfg and def.cfg.durationSeconds) or 0.25, 0.08, 0.60) + 0.10

	for i = 1, #ids do
		local pid = ids[i]
		if IsPlayerValid(pid) then
			local p = state.players[pid]
			if p and p.abilities then
				local ab = p.abilities[def.id]
				if ab and (tonumber(ab.activeUntil) or 0) > now then
					if (ab.activeUntil - now) <= durationGuard then
						local dirX = tonumber(ab.dirX) or 0
						local dirZ = tonumber(ab.dirZ) or 0
						local speed = tonumber(ab.speed) or 0
						if speed > 0 then
							local vel = currentVelocity(pid)
							local ny = tonumber(vel[2]) or 0
							setPlayerVelocitySafe(pid, Vec(dirX * speed, ny, dirZ * speed))
						end
					end
				elseif ab and ab.activeUntil then
					ab.activeUntil = 0
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

register((HS.abilities and HS.abilities.ids and HS.abilities.ids.dash) or "dash", Dash)
