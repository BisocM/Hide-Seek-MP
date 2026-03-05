HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.mimic = HS.infra.mimic or {}

local M = HS.infra.mimic

M._active = M._active or {}

local function logInfo(msg, data)
	if HS.log and HS.log.info then
		HS.log.info(msg, data)
	end
end

local function logWarn(msg, data)
	if HS.log and HS.log.warn then
		HS.log.warn(msg, data)
	end
end

local function now()
	if HS.util and HS.util.time and HS.util.time.now then
		return HS.util.time.now()
	end
	if HS.infra and HS.infra.clock and HS.infra.clock.now then
		return tonumber(HS.infra.clock.now()) or 0
	end
	if type(GetTime) == "function" then
		return tonumber(GetTime()) or 0
	end
	return 0
end

local function mimicId()
	return (HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop"
end

local function mimicCfg()
	local def = HS.abilities and HS.abilities.def and HS.abilities.def(mimicId()) or nil
	local cfg = type(def and def.cfg) == "table" and def.cfg or {}
	return {
		maxShapes = math.max(1, math.floor(tonumber(cfg.maxShapes) or 20)),
		maxVoxels = math.max(128, math.floor(tonumber(cfg.maxVoxels) or 32000)),
		maxMass = math.max(10, tonumber(cfg.maxMass) or 450),
		maxExtent = math.max(0.5, tonumber(cfg.maxExtent) or 4.5),
		walkSpeedScale = HS.util.clamp(tonumber(cfg.walkSpeedScale) or 0.62, 0.2, 1.0),
	}
end

local function isPlayerValid(pid)
	return HS.infra and HS.infra.players and HS.infra.players.isValid and HS.infra.players.isValid(pid)
end

local function toolApi()
	return HS.infra and HS.infra.playerTools or nil
end

local function pickBodyUnderCrosshair(playerId)
	if type(GetPlayerPickBody) ~= "function" then
		return 0
	end

	playerId = tonumber(playerId) or 0
	if playerId <= 0 then
		return 0
	end
	local ok, body = pcall(GetPlayerPickBody, playerId)
	body = ok and (tonumber(body) or 0) or 0
	return body > 0 and body or 0
end

local function safeGetBodyShapes(bodyId)
	if type(GetBodyShapes) ~= "function" then
		return {}
	end
	local ok, shapes = pcall(GetBodyShapes, bodyId)
	if not ok or type(shapes) ~= "table" then
		return {}
	end
	return shapes
end

local function safeGetBodyBoundsExtent(bodyId)
	if type(GetBodyBounds) ~= "function" then
		return 0
	end
	local ok, mn, mx = pcall(GetBodyBounds, bodyId)
	if not ok or type(mn) ~= "table" or type(mx) ~= "table" then
		return 0
	end
	local ex = math.abs((tonumber(mx[1]) or 0) - (tonumber(mn[1]) or 0))
	local ey = math.abs((tonumber(mx[2]) or 0) - (tonumber(mn[2]) or 0))
	local ez = math.abs((tonumber(mx[3]) or 0) - (tonumber(mn[3]) or 0))
	return math.max(ex, ey, ez)
end

local function hasBlockTag(handle)
	if type(HasTag) ~= "function" then
		return false
	end
	local ok, blocked = pcall(HasTag, handle, "hs_mimic_block")
	return ok and blocked == true
end

local function parseBodyValidation(state, playerId, bodyId)
	local cfg = mimicCfg()
	local pid = tonumber(playerId) or 0
	local body = tonumber(bodyId) or 0

	local data = {
		playerId = pid,
		bodyId = body,
		shapeCount = 0,
		voxelCount = 0,
		mass = 0,
		extent = 0,
		reason = "",
	}

	if body <= 0 then
		data.reason = "no_pick"
		return false, data
	end

	if type(IsHandleValid) == "function" then
		local ok, valid = pcall(IsHandleValid, body)
		if not ok or valid ~= true then
			data.reason = "invalid_handle"
			return false, data
		end
	end

	if type(GetWorldBody) == "function" then
		local ok, worldBody = pcall(GetWorldBody)
		if ok and (tonumber(worldBody) or 0) == body then
			data.reason = "world_body"
			return false, data
		end
	end

	if type(IsBodyBroken) == "function" then
		local ok, broken = pcall(IsBodyBroken, body)
		if ok and broken == true then
			data.reason = "broken_body"
			return false, data
		end
	end

	if type(IsBodyDynamic) == "function" then
		local ok, dyn = pcall(IsBodyDynamic, body)
		if ok and dyn ~= true then
			data.reason = "not_dynamic"
			return false, data
		end
	end

	if type(GetBodyPlayer) == "function" then
		local ok, owner = pcall(GetBodyPlayer, body)
		if ok and (tonumber(owner) or 0) > 0 then
			data.reason = "player_body"
			return false, data
		end
	end

	if type(GetBodyVehicle) == "function" then
		local ok, veh = pcall(GetBodyVehicle, body)
		if ok and (tonumber(veh) or 0) > 0 then
			data.reason = "vehicle_body"
			return false, data
		end
	end

	if hasBlockTag(body) then
		data.reason = "tag_blocked"
		return false, data
	end

	local shapesRaw = safeGetBodyShapes(body)
	local shapes = {}
	local voxels = 0
	for i = 1, #shapesRaw do
		local sid = tonumber(shapesRaw[i]) or 0
		if sid > 0 then
			if type(IsHandleValid) == "function" then
				local ok, valid = pcall(IsHandleValid, sid)
				if not ok or valid ~= true then
					data.reason = "invalid_shape"
					return false, data
				end
			end
			if hasBlockTag(sid) then
				data.reason = "tag_blocked"
				return false, data
			end
			local isBroken = false
			if type(IsShapeBroken) == "function" then
				local okBroken, broken = pcall(IsShapeBroken, sid)
				isBroken = okBroken and broken == true
			end
			if not isBroken then
				shapes[#shapes + 1] = sid
				if type(GetShapeVoxelCount) == "function" then
					local okV, n = pcall(GetShapeVoxelCount, sid)
					if okV then
						voxels = voxels + math.max(0, math.floor(tonumber(n) or 0))
					end
				end
			end
		end
	end

	data.shapeCount = #shapes
	data.voxelCount = voxels
	if #shapes <= 0 then
		data.reason = "no_shapes"
		return false, data
	end
	if #shapes > cfg.maxShapes then
		data.reason = "too_many_shapes"
		return false, data
	end
	if voxels > cfg.maxVoxels then
		data.reason = "too_many_voxels"
		return false, data
	end

	if type(GetBodyMass) == "function" then
		local okM, mass = pcall(GetBodyMass, body)
		data.mass = okM and (tonumber(mass) or 0) or 0
		if data.mass > cfg.maxMass then
			data.reason = "too_heavy"
			return false, data
		end
	end

	data.extent = safeGetBodyBoundsExtent(body)
	if data.extent > cfg.maxExtent then
		data.reason = "too_large"
		return false, data
	end

	data.shapes = shapes
	return true, data
end

function M.validateBody(state, playerId, bodyId)
	return parseBodyValidation(state, playerId, bodyId)
end

function M.validationToastKey(reason)
	if HS.contracts and HS.contracts.abilityErrors and HS.contracts.abilityErrors.mimicToastKey then
		return HS.contracts.abilityErrors.mimicToastKey(reason)
	end
	return "hs.toast.mimicUnavailable"
end

function M.selectForCommand(state, playerId)
	local pid = tonumber(playerId) or 0
	local body = pickBodyUnderCrosshair(pid)
	local ok, data = M.validateBody(state, pid, body)
	if not ok then
		logWarn("Mimic target rejected", {
			playerId = pid,
			bodyId = tonumber(data and data.bodyId) or 0,
			reason = tostring(data and data.reason or "invalid"),
			shapeCount = tonumber(data and data.shapeCount) or 0,
			voxelCount = tonumber(data and data.voxelCount) or 0,
			mass = tonumber(data and data.mass) or 0,
			extent = tonumber(data and data.extent) or 0,
		})
		return {
			bodyId = 0,
			reason = tostring(data and data.reason or "no_pick"),
			shapeCount = tonumber(data and data.shapeCount) or 0,
			voxelCount = tonumber(data and data.voxelCount) or 0,
			mass = tonumber(data and data.mass) or 0,
			extent = tonumber(data and data.extent) or 0,
		}
	end
	logInfo("Mimic target validated", {
		playerId = pid,
		bodyId = tonumber(data.bodyId) or 0,
		shapeCount = tonumber(data.shapeCount) or 0,
		voxelCount = tonumber(data.voxelCount) or 0,
		mass = tonumber(data.mass) or 0,
		extent = tonumber(data.extent) or 0,
	})
	return {
		bodyId = tonumber(data.bodyId) or 0,
		reason = "",
		shapeCount = tonumber(data.shapeCount) or 0,
		voxelCount = tonumber(data.voxelCount) or 0,
		mass = tonumber(data.mass) or 0,
		extent = tonumber(data.extent) or 0,
	}
end

local function isHandleValid(handle)
	local h = tonumber(handle) or 0
	if h <= 0 then return false end
	if type(IsHandleValid) ~= "function" then
		return true
	end
	local ok, valid = pcall(IsHandleValid, h)
	return ok and valid == true
end

local function safeBodyDynamic(bodyId, fallback)
	if type(IsBodyDynamic) ~= "function" then
		return fallback == true
	end
	local ok, dyn = pcall(IsBodyDynamic, tonumber(bodyId) or 0)
	if not ok then
		return fallback == true
	end
	return dyn == true
end

local function safeBodyActive(bodyId, fallback)
	if type(IsBodyActive) ~= "function" then
		return fallback == true
	end
	local ok, active = pcall(IsBodyActive, tonumber(bodyId) or 0)
	if not ok then
		return fallback == true
	end
	return active == true
end

local function getBodyTransformSafe(bodyId, fallbackTr)
	bodyId = tonumber(bodyId) or 0
	if bodyId > 0 and type(GetBodyTransform) == "function" then
		local ok, tr = pcall(GetBodyTransform, bodyId)
		if ok and type(tr) == "table" then
			return tr
		end
	end
	return type(fallbackTr) == "table" and fallbackTr or Transform(Vec(0, 0, 0), Quat())
end

local function safeGetPlayerTool(playerId)
	local api = toolApi()
	if api and api.getEquipped then
		return tostring(api.getEquipped(playerId) or "")
	end
	playerId = tonumber(playerId) or 0
	if playerId <= 0 or type(GetPlayerTool) ~= "function" then
		return ""
	end
	local ok, toolId = pcall(GetPlayerTool, playerId)
	return ok and tostring(toolId or "") or ""
end

local function safeSetPlayerTool(playerId, toolId)
	local api = toolApi()
	if api and api.setEquipped then
		return api.setEquipped(playerId, toolId) == true
	end
	playerId = tonumber(playerId) or 0
	toolId = tostring(toolId or "")
	if playerId <= 0 or type(SetPlayerTool) ~= "function" then
		return false
	end
	local ok = pcall(SetPlayerTool, toolId, playerId)
	if ok then return true end
	ok = pcall(SetPlayerTool, playerId, toolId)
	return ok == true
end

local function getPlayerHealthSafe(playerId, fallback)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 then
		return tonumber(fallback) or 1.0
	end
	if type(GetPlayerHealth) ~= "function" then
		return tonumber(fallback) or 1.0
	end
	local ok, hp = pcall(GetPlayerHealth, playerId)
	if not ok then
		return tonumber(fallback) or 1.0
	end
	return math.max(0.1, tonumber(hp) or (tonumber(fallback) or 1.0))
end

local function restorePlayerHealthSafe(playerId, hp)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 or type(SetPlayerHealth) ~= "function" then
		return
	end
	pcall(SetPlayerHealth, math.max(0.1, tonumber(hp) or 1.0), playerId)
end

local function setPlayerTransformSafe(playerId, tr)
	playerId = tonumber(playerId) or 0
	if playerId <= 0 or type(tr) ~= "table" then
		return false
	end
	if type(SetPlayerTransform) ~= "function" then
		return false
	end
	local ok = pcall(SetPlayerTransform, tr, playerId)
	if ok then return true end
	ok = pcall(SetPlayerTransform, playerId, tr)
	return ok == true
end

local function vecDist(a, b)
	local sp = HS.infra and HS.infra.spatial or nil
	if sp and type(sp.vecDist) == "function" then
		local ok, d = pcall(sp.vecDist, a, b)
		if ok then
			return tonumber(d) or 0
		end
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return 0
	end
	local dx = (tonumber(a[1]) or 0) - (tonumber(b[1]) or 0)
	local dy = (tonumber(a[2]) or 0) - (tonumber(b[2]) or 0)
	local dz = (tonumber(a[3]) or 0) - (tonumber(b[3]) or 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function captureShapeFilters(shapeIds)
	local out = {}
	local list = type(shapeIds) == "table" and shapeIds or {}
	for i = 1, #list do
		local sid = tonumber(list[i]) or 0
		if sid > 0 and isHandleValid(sid) then
			local layer, mask = 1, 255
			if type(GetShapeCollisionFilter) == "function" then
				local ok, l, m = pcall(GetShapeCollisionFilter, sid)
				if ok then
					layer = math.floor(tonumber(l) or 1)
					mask = math.floor(tonumber(m) or 255)
				end
			end
			out[sid] = { layer = layer, mask = mask }
		end
	end
	return out
end

local function applyNoCollisions(shapeFilters)
	if type(SetShapeCollisionFilter) ~= "function" then
		return
	end
	for sid in pairs(type(shapeFilters) == "table" and shapeFilters or {}) do
		local shapeId = tonumber(sid) or 0
		if shapeId > 0 and isHandleValid(shapeId) then
			local ok = pcall(SetShapeCollisionFilter, shapeId, 0, 0)
			if not ok then
				pcall(SetShapeCollisionFilter, shapeId, 1, 0)
			end
		end
	end
end

local function restoreCollisions(shapeFilters)
	if type(SetShapeCollisionFilter) ~= "function" then
		return
	end
	for sid, f in pairs(type(shapeFilters) == "table" and shapeFilters or {}) do
		local shapeId = tonumber(sid) or 0
		if shapeId > 0 and isHandleValid(shapeId) then
			local layer = math.floor(tonumber(f and f.layer) or 1)
			local mask = math.floor(tonumber(f and f.mask) or 255)
			pcall(SetShapeCollisionFilter, shapeId, layer, mask)
		end
	end
end

local function toolAllowedBySettings(state, playerId, toolId)
	toolId = tostring(toolId or "")
	if toolId == "" or toolId == "none" then
		return false
	end
	if type(state) ~= "table" then
		return true
	end

	local p = state.players and state.players[playerId] or nil
	if not p or p.out == true then
		return false
	end

	local loadout = state.settings and state.settings.loadout or nil
	if type(loadout) ~= "table" or loadout.enabled ~= true then
		return true
	end
	if not (HS.loadout and HS.loadout.allowed) then
		return true
	end

	local assign = type(loadout.assign) == "table" and loadout.assign[toolId] or nil
	if assign == nil and HS.loadout.defaultAssignFor then
		assign = HS.loadout.defaultAssignFor(toolId)
	end
	return HS.loadout.allowed(assign, tonumber(p.team) or 0) == true
end

local function isMimicActiveInState(state, playerId, atNow)
	local phase = tostring(state and state.phase or "")
	if phase ~= HS.const.PHASE_HIDING and phase ~= HS.const.PHASE_SEEKING then
		return false
	end
	local p = state and state.players and state.players[playerId] or nil
	if not p then return false end
	if p.team ~= HS.const.TEAM_HIDERS or p.out == true then
		return false
	end
	local ab = p.abilities and p.abilities[mimicId()] or nil
	local untilAt = tonumber(ab and ab.armedUntil) or 0
	return untilAt > (tonumber(atNow) or 0)
end

local function setPlayerHiddenSafe(pid)
	if type(SetPlayerHidden) ~= "function" then return end
	pcall(SetPlayerHidden, pid)
end

local function tickProxy(rec, pid)
	if type(rec) ~= "table" then return end
	if not isPlayerValid(pid) then return end
	local playerTr = GetPlayerTransform(pid)
	local body = tonumber(rec.bodyId) or tonumber(rec.proxyBody) or 0
	local bodyTr = getBodyTransformSafe(body, playerTr)

	local anchorPos = type(rec.anchorPos) == "table" and rec.anchorPos or (type(bodyTr.pos) == "table" and bodyTr.pos or nil)
	if type(anchorPos) ~= "table" then
		anchorPos = Vec(0, 0, 0)
	end
	local cameraRot = (type(playerTr) == "table" and type(playerTr.rot) == "table") and playerTr.rot
		or (type(rec.cameraRot) == "table" and rec.cameraRot)
		or (type(bodyTr.rot) == "table" and bodyTr.rot)
		or Quat()
	local bodyRot = (type(rec.anchorRot) == "table") and rec.anchorRot
		or (type(bodyTr.rot) == "table" and bodyTr.rot)
		or cameraRot
		or Quat()
	rec.anchorPos = anchorPos
	rec.cameraRot = cameraRot
	if type(rec.anchorRot) ~= "table" then
		rec.anchorRot = bodyRot
	end

	if type(ReleasePlayerGrab) == "function" then
		pcall(ReleasePlayerGrab, pid)
	end

	if body > 0 then
		if type(SetBodyTransform) == "function" then
			pcall(SetBodyTransform, body, Transform(anchorPos, bodyRot))
		end
		if type(SetBodyDynamic) == "function" then
			pcall(SetBodyDynamic, body, false)
		end
		if type(SetBodyActive) == "function" then
			pcall(SetBodyActive, body, false)
		end
		if type(SetBodyVelocity) == "function" then
			pcall(SetBodyVelocity, body, Vec(0, 0, 0))
		end
		if type(SetBodyAngularVelocity) == "function" then
			pcall(SetBodyAngularVelocity, body, Vec(0, 0, 0))
		end
	end

	local targetTr = Transform(anchorPos, cameraRot)
	local playerPos = (type(playerTr) == "table" and type(playerTr.pos) == "table") and playerTr.pos or anchorPos
	if vecDist(playerPos, anchorPos) > 0.75 then
		local moved = setPlayerTransformSafe(pid, targetTr)
		if not moved and type(RespawnPlayerAtTransform) == "function" then
			local t = now()
			local last = tonumber(rec.lastRespawnAt) or -999
			if (t - last) > 0.45 then
				local hp = getPlayerHealthSafe(pid, 1.0)
				pcall(RespawnPlayerAtTransform, targetTr, pid)
				restorePlayerHealthSafe(pid, hp)
				rec.lastRespawnAt = t
			end
		end
	end

	setPlayerHiddenSafe(pid)
	SetPlayerWalkingSpeed(0.0, pid)
	SetPlayerCrouchSpeedScale(0.01, pid)
	SetPlayerVelocity(Vec(0, 0, 0), pid)
	if type(SetPlayerParam) == "function" then
		pcall(SetPlayerParam, "disableinteract", true, pid)
	end
	safeSetPlayerTool(pid, "none")
	safeSetPlayerTool(pid, "")
end

function M.stop(stateOrPlayerId, playerIdOrReason, reason)
	local state = nil
	local pid = 0
	local why = ""
	if type(stateOrPlayerId) == "table" then
		state = stateOrPlayerId
		pid = tonumber(playerIdOrReason) or 0
		why = tostring(reason or "")
	else
		pid = tonumber(stateOrPlayerId) or 0
		why = tostring(playerIdOrReason or "")
	end

	if pid <= 0 then return end
	local rec = M._active[pid]
	if type(rec) ~= "table" then return end

	local body = tonumber(rec.bodyId) or tonumber(rec.proxyBody) or 0
	if body > 0 then
		restoreCollisions(rec.shapeFilters)
		if type(SetBodyDynamic) == "function" then
			pcall(SetBodyDynamic, body, rec.wasDynamic == true)
		end
		if type(SetBodyActive) == "function" then
			pcall(SetBodyActive, body, rec.wasActive == true)
		end
	end

	if type(SetPlayerParam) == "function" then
		pcall(SetPlayerParam, "disableinteract", false, pid)
	end

	local shouldRespawnNearProp = (why ~= "restart" and why ~= "reset" and why ~= "to_spectator" and why ~= "non_hider_team")
	if shouldRespawnNearProp and isPlayerValid(pid) then
		local exitPos = (type(rec.exitSeedPos) == "table" and rec.exitSeedPos)
			or (type(rec.anchorPos) == "table" and rec.anchorPos)
			or nil
		local exitRot = (type(rec.exitSeedRot) == "table" and rec.exitSeedRot)
			or (type(rec.cameraRot) == "table" and rec.cameraRot)
			or (type(rec.anchorRot) == "table" and rec.anchorRot)
			or Quat()
		if type(exitPos) == "table" then
			local exitTr = Transform(exitPos, exitRot)
			local moved = setPlayerTransformSafe(pid, exitTr)
			if not moved and type(RespawnPlayerAtTransform) == "function" then
				local hp = getPlayerHealthSafe(pid, 1.0)
				pcall(RespawnPlayerAtTransform, exitTr, pid)
				restorePlayerHealthSafe(pid, hp)
			end
			if type(SetPlayerVelocity) == "function" then
				pcall(SetPlayerVelocity, Vec(0, 0, 0), pid)
			end
			if type(ReleasePlayerGrab) == "function" then
				pcall(ReleasePlayerGrab, pid)
			end
		end
	end

	local shouldRestoreTool = (why ~= "restart" and why ~= "reset" and why ~= "to_spectator" and why ~= "non_hider_team")
	if shouldRestoreTool and toolAllowedBySettings(state, pid, rec.prevTool) then
		safeSetPlayerTool(pid, rec.prevTool)
	end

	M._active[pid] = nil

	logInfo("Mimic proxy removed", {
		playerId = pid,
		reason = why,
	})
end

function M.start(state, playerId, bodyId)
	local pid = tonumber(playerId) or 0
	if pid <= 0 or not isPlayerValid(pid) then
		return false, "invalid_player"
	end

	local ok, validation = M.validateBody(state, pid, bodyId)
	if not ok then
		logWarn("Mimic start rejected", validation)
		return false, tostring(validation and validation.reason or "invalid")
	end

	for otherPid, active in pairs(M._active) do
		local opid = tonumber(otherPid) or 0
		local activeBody = tonumber(active and active.bodyId) or tonumber(active and active.proxyBody) or 0
		if opid > 0 and opid ~= pid and activeBody == tonumber(validation.bodyId) then
			return false, "target_in_use"
		end
	end

	M.stop(state, pid, "restart")
	if type(ReleasePlayerGrab) == "function" then
		pcall(ReleasePlayerGrab, pid)
	end

	local playerTr = GetPlayerTransform(pid)
	local entryPos = (type(playerTr) == "table" and type(playerTr.pos) == "table")
		and Vec(
			tonumber(playerTr.pos[1]) or 0,
			tonumber(playerTr.pos[2]) or 0,
			tonumber(playerTr.pos[3]) or 0
		)
		or nil
	local entryRot = (type(playerTr) == "table" and type(playerTr.rot) == "table") and playerTr.rot or nil
	local possessedBody = tonumber(validation.bodyId) or 0
	if possessedBody <= 0 or not isHandleValid(possessedBody) then
		logWarn("Mimic possession failed", {
			playerId = pid,
			bodyId = possessedBody,
			reason = "invalid_body",
		})
		return false, "invalid_body"
	end
	local bodyTr = getBodyTransformSafe(possessedBody, playerTr)
	local anchorPos = (type(bodyTr) == "table" and type(bodyTr.pos) == "table") and bodyTr.pos
		or ((type(playerTr) == "table" and type(playerTr.pos) == "table") and playerTr.pos)
		or Vec(0, 0, 0)
	local anchorRot = (type(bodyTr) == "table" and type(bodyTr.rot) == "table") and bodyTr.rot
		or ((type(playerTr) == "table" and type(playerTr.rot) == "table") and playerTr.rot)
		or Quat()

	local wasDynamic = safeBodyDynamic(possessedBody, true)
	local wasActive = safeBodyActive(possessedBody, true)
	local shapeFilters = captureShapeFilters(validation.shapes)
	applyNoCollisions(shapeFilters)
	if type(SetBodyDynamic) == "function" then
		pcall(SetBodyDynamic, possessedBody, false)
	end
	if type(SetBodyActive) == "function" then
		pcall(SetBodyActive, possessedBody, false)
	end
	if type(SetBodyVelocity) == "function" then
		pcall(SetBodyVelocity, possessedBody, Vec(0, 0, 0))
	end
	if type(SetBodyAngularVelocity) == "function" then
		pcall(SetBodyAngularVelocity, possessedBody, Vec(0, 0, 0))
	end
	if type(SetBodyTransform) == "function" then
		pcall(SetBodyTransform, possessedBody, Transform(anchorPos, anchorRot))
	end

	local hp = getPlayerHealthSafe(pid, 1.0)
	local targetTr = Transform(anchorPos, anchorRot)
	if not setPlayerTransformSafe(pid, targetTr) and type(RespawnPlayerAtTransform) == "function" then
		pcall(RespawnPlayerAtTransform, targetTr, pid)
		restorePlayerHealthSafe(pid, hp)
	end

	M._active[pid] = {
		playerId = pid,
		sourceBody = possessedBody,
		bodyId = possessedBody,
		proxyBody = possessedBody,
		anchorPos = anchorPos,
		anchorRot = anchorRot,
		cameraRot = entryRot or anchorRot,
		exitSeedPos = entryPos or anchorPos,
		exitSeedRot = entryRot or anchorRot,
		shapeFilters = shapeFilters,
		wasDynamic = wasDynamic,
		wasActive = wasActive,
		prevTool = safeGetPlayerTool(pid),
		shapeCount = validation.shapeCount,
		voxelCount = validation.voxelCount,
		startedAt = now(),
	}

	tickProxy(M._active[pid], pid)

	if HS.domain and HS.domain.events and HS.domain.events.clientAbilityVfx and HS.infra and HS.infra.events and HS.infra.events.emit then
		local pos = anchorPos or Vec(0, 0, 0)
		local ev = HS.domain.events.clientAbilityVfx(mimicId(), pid, pos, Vec(0, 1, 0), pos, 0)
		if ev then
			HS.infra.events.emit(0, ev.type, ev.payload)
		end
	end

	logInfo("Mimic possession started", {
		playerId = pid,
		bodyId = possessedBody,
		shapeCount = validation.shapeCount,
		voxelCount = validation.voxelCount,
	})
	return true, nil
end

function M.reset()
	for pid in pairs(M._active) do
		M.stop(nil, pid, "reset")
	end
	M._active = {}
end

function M.sync(state, frameNow)
	local nowT = tonumber(frameNow) or now()
	for pid, rec in pairs(M._active) do
		local p = tonumber(pid) or 0
		if p <= 0 then
			M._active[pid] = nil
		else
			local proxyBody = tonumber(rec and rec.bodyId) or tonumber(rec and rec.proxyBody) or 0
			local proxyValid = proxyBody > 0
			if proxyValid and type(IsHandleValid) == "function" then
				local ok, v = pcall(IsHandleValid, proxyBody)
				proxyValid = ok and v == true
			end
			if not proxyValid then
				M.stop(state, p, "proxy_missing")
			elseif not isMimicActiveInState(state, p, nowT) then
				M.stop(state, p, "state_inactive")
			else
				tickProxy(rec, p)
			end
		end
	end
end
