HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.targeting = HS.infra.targeting or {}

local T = HS.infra.targeting

local TAG_AIM_OFFSET = Vec(0, 1.2, 0)
local TAG_AIM_DOT_MIN = 0.97

local function isEligibleTarget(state, seekerId, targetId)
	if targetId == 0 or targetId == seekerId then return false end
	if not HS.infra.players.isValid(targetId) then return false end
	local p = state and state.players and state.players[targetId] or nil
	if not p then return false end
	if p.team ~= HS.const.TEAM_HIDERS then return false end
	if p.out == true then return false end
	return true
end

local function aimPos(playerId)
	local tr = GetPlayerTransform(playerId)
	return VecAdd(tr.pos, TAG_AIM_OFFSET)
end

local function pickUnderCrosshair(playerId)
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

local function hasLineOfSight(camPos, targetId)
	local targetPos = aimPos(targetId)
	local to = VecSub(targetPos, camPos)
	local dist = VecLength(to)
	if dist <= 0.001 then return true end

	QueryRequire("physical")
	local dir = VecNormalize(to)
	local hit, hitDist, _n, shape = QueryRaycast(camPos, dir, dist, 0.15, true)
	if not hit then return true end
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

local function inRangeAndAim(state, seekerId, targetId, range)
	if not isEligibleTarget(state, seekerId, targetId) then return false end

	local cam = GetPlayerCameraTransform(seekerId)
	local camPos = (type(cam) == "table" and cam.pos) or GetPlayerTransform(seekerId).pos
	local aimTr = (type(cam) == "table" and cam) or GetPlayerTransform(seekerId)
	local fwd = VecNormalize(TransformToParentVec(aimTr, Vec(0, 0, -1)))

	local a = GetPlayerTransform(seekerId).pos
	local b = GetPlayerTransform(targetId).pos
	if VecLength(VecSub(a, b)) > range then return false end

	local to = VecSub(aimPos(targetId), camPos)
	local dist = VecLength(to)
	if dist > 0.001 then
		local dir = VecNormalize(to)
		local dot = VecDot(dir, fwd)
		if dot < TAG_AIM_DOT_MIN then
			return false
		end
	end
	if not hasLineOfSight(camPos, targetId) then return false end
	return true
end

function T.findTagTarget(state, seekerId, range)
	seekerId = tonumber(seekerId) or 0
	if seekerId <= 0 then return 0 end
	if not HS.infra.players.isValid(seekerId) then return 0 end

	local seeker = state and state.players and state.players[seekerId] or nil
	if not seeker or seeker.team ~= HS.const.TEAM_SEEKERS or seeker.out == true then
		return 0
	end

	range = tonumber(range) or 4.0
	local picked = pickUnderCrosshair(seekerId)
	if picked > 0 and inRangeAndAim(state, seekerId, picked, range) then
		return picked
	end

	local cam = GetPlayerCameraTransform(seekerId)
	local camPos = (type(cam) == "table" and cam.pos) or GetPlayerTransform(seekerId).pos
	local aimTr = (type(cam) == "table" and cam) or GetPlayerTransform(seekerId)
	local fwd = VecNormalize(TransformToParentVec(aimTr, Vec(0, 0, -1)))
	local seekerPos = GetPlayerTransform(seekerId).pos

	local best = 0
	local bestDot = TAG_AIM_DOT_MIN
	for _, pid in ipairs(HS.domain.model.sortedPlayerIds(state)) do
		if isEligibleTarget(state, seekerId, pid) then
			local ppos = GetPlayerTransform(pid).pos
			if VecLength(VecSub(ppos, seekerPos)) <= range then
				local to = VecSub(aimPos(pid), camPos)
				local dist = VecLength(to)
				if dist > 0.001 then
					local dir = VecNormalize(to)
					local dot = VecDot(dir, fwd)
					if dot > bestDot and hasLineOfSight(camPos, pid) then
						bestDot = dot
						best = pid
					end
				end
			end
		end
	end

	return best
end
