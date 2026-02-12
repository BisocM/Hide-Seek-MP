HS = HS or {}
HS.srv = HS.srv or {}

local TAG_AIM_OFFSET = Vec(0, 1.2, 0)
local TAG_AIM_DOT_MIN = 0.97 -- ~14 degrees

function HS.srv.moveToSpectator(state, playerId)
	local t = GetPlayerTransform(playerId)
	local dest = HS.util.pickRandom(state.spawns.spectators) or t
	RespawnPlayerAtTransform(dest, playerId)
	SetPlayerHealth(1.0, playerId)
	DisablePlayerInput(playerId)
	SetPlayerWalkingSpeed(0.0, playerId)
	SetPlayerCrouchSpeedScale(0.01, playerId)
	SetPlayerVelocity(Vec(0, 0, 0), playerId)
	ReleasePlayerGrab(playerId)
end

function HS.srv.tagHider(state, seekerId, hiderId)
	local s = state.settings
	if s.infectionMode then
		HS.srv.setCurrentTeam(state, hiderId, HS.const.TEAM_SEEKERS)
		state.players[hiderId].out = false
		HS.srv.notify.feedCaught(0, seekerId, hiderId, "tag")
	else
		state.players[hiderId].out = true
		HS.srv.moveToSpectator(state, hiderId)
		HS.srv.notify.feedCaught(0, seekerId, hiderId, "tag")
	end
end

local function isEligibleTagTarget(state, seekerId, targetId)
	if targetId == 0 or targetId == seekerId then return false end
	if not IsPlayerValid(targetId) then return false end

	local target = state.players[targetId]
	if not target then return false end
	if target.team ~= HS.const.TEAM_HIDERS then return false end
	if target.out then return false end
	return true
end

local function aimPos(playerId)
	return VecAdd(GetPlayerTransform(playerId).pos, TAG_AIM_OFFSET)
end

local function pickPlayerUnderCrosshair(playerId)
	local body = GetPlayerPickBody(playerId)
	if body ~= 0 then
		local target = GetBodyPlayer(body)
		if type(target) == "number" and target > 0 then
			return target
		end
	end

	local shape = GetPlayerPickShape(playerId)
	if shape ~= 0 then
		local b = GetShapeBody(shape)
		if b ~= 0 then
			local target = GetBodyPlayer(b)
			if type(target) == "number" and target > 0 then
				return target
			end
		end
	end

	return 0
end

local function findPickTargetInRange(state, seekerId, range)
	local cam = GetPlayerCameraTransform(seekerId)
	local camPos = (type(cam) == "table" and cam.pos) or GetPlayerTransform(seekerId).pos
	local aimTr = (type(cam) == "table" and cam) or GetPlayerTransform(seekerId)
	local fwd = TransformToParentVec(aimTr, Vec(0, 0, -1))
	fwd = VecNormalize(fwd)

	local targetId = pickPlayerUnderCrosshair(seekerId)
	if not isEligibleTagTarget(state, seekerId, targetId) then return 0 end

	local a = GetPlayerTransform(seekerId).pos
	local b = GetPlayerTransform(targetId).pos
	if HS.util.vecDist(a, b) > range then return 0 end

	local to = VecSub(aimPos(targetId), camPos)
	local dist = VecLength(to)
	if dist > 0.001 then
		local dir = VecNormalize(to)
		local dot = VecDot(dir, fwd)
		if dot < TAG_AIM_DOT_MIN then
			return 0
		end
	end
	if not hasLineOfSightToPlayer(camPos, targetId) then
		return 0
	end

	return targetId
end

local function hasLineOfSightToPlayer(camPos, targetId)
	local targetPos = aimPos(targetId)
	local to = VecSub(targetPos, camPos)
	local dist = VecLength(to)
	if dist <= 0.001 then return true end

	QueryRequire("physical")
	local dir = VecNormalize(to)
	local hit, hitDist, _n, shape = QueryRaycast(camPos, dir, dist, 0.15, true)
	if not hit then
		return true
	end
	if shape ~= nil and shape ~= 0 then
		local b = GetShapeBody(shape)
		if b ~= 0 then
			local p = GetBodyPlayer(b)
			if type(p) == "number" and p == targetId then
				return true
			end
		end
	end

	return (tonumber(hitDist) or 0) >= dist - 0.35
end

local function findAimTargetInRange(state, seekerId, range)
	local cam = GetPlayerCameraTransform(seekerId)
	local camPos = (type(cam) == "table" and cam.pos) or GetPlayerTransform(seekerId).pos
	local aimTr = (type(cam) == "table" and cam) or GetPlayerTransform(seekerId)
	local fwd = TransformToParentVec(aimTr, Vec(0, 0, -1))
	fwd = VecNormalize(fwd)

	local seekerPos = GetPlayerTransform(seekerId).pos

	local best = 0
	local bestDot = TAG_AIM_DOT_MIN
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		if isEligibleTagTarget(state, seekerId, pid) then
			if HS.util.vecDist(seekerPos, GetPlayerTransform(pid).pos) <= range then
				local to = VecSub(aimPos(pid), camPos)
				local dist = VecLength(to)
				if dist > 0.001 then
					local dir = VecNormalize(to)
					local dot = VecDot(dir, fwd)
					if dot > bestDot and hasLineOfSightToPlayer(camPos, pid) then
						bestDot = dot
						best = pid
					end
				end
			end
		end
	end
	return best
end

function HS.srv.tryTag(state, seekerId)
	local s = state.settings
	if not IsPlayerValid(seekerId) then return false end

	local seeker = state.players[seekerId]
	if not seeker or seeker.team ~= HS.const.TEAM_SEEKERS then return false end
	if seeker.out then return false end

	local range = tonumber(s.tagRangeMeters) or 4.0

	local targetId = findPickTargetInRange(state, seekerId, range)
	if targetId == 0 then
		targetId = findAimTargetInRange(state, seekerId, range)
	end
	if targetId == 0 then return false end

	HS.srv.tagHider(state, seekerId, targetId)
	return true
end
