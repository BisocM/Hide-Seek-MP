HS = HS or {}
HS.infra = HS.infra or {}
HS.infra.spatial = HS.infra.spatial or {}

local S = HS.infra.spatial

local function optNumber(v, fallback)
	local n = tonumber(v)
	if n == nil then
		return tonumber(fallback) or 0
	end
	return n
end

local function copyQueryOpts(opts, rejectBodyId)
	local out = {}
	if type(opts) == "table" then
		for k, v in pairs(opts) do
			out[k] = v
		end
	end
	out.rejectBodyId = tonumber(rejectBodyId) or 0
	return out
end

local function withPhysicalQuery(opts)
	if type(QueryRequire) == "function" then
		local requirePhysical = true
		if type(opts) == "table" and opts.requirePhysical == false then
			requirePhysical = false
		end
		if requirePhysical then
			pcall(QueryRequire, "physical")
		end
	end
	if type(QueryRejectBody) == "function" and type(opts) == "table" then
		local rejectBodyId = tonumber(opts.rejectBodyId) or 0
		if rejectBodyId > 0 then
			pcall(QueryRejectBody, rejectBodyId)
		end
	end
end

local function horizontalDist(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return 0
	end
	local dx = (tonumber(a[1]) or 0) - (tonumber(b[1]) or 0)
	local dz = (tonumber(a[3]) or 0) - (tonumber(b[3]) or 0)
	return math.sqrt(dx * dx + dz * dz)
end

function S.vecDist(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return 0
	end
	if HS.util and HS.util.vecDist then
		local ok, d = pcall(HS.util.vecDist, a, b)
		if ok then
			return tonumber(d) or 0
		end
	end
	local dx = (tonumber(a[1]) or 0) - (tonumber(b[1]) or 0)
	local dy = (tonumber(a[2]) or 0) - (tonumber(b[2]) or 0)
	local dz = (tonumber(a[3]) or 0) - (tonumber(b[3]) or 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function S.isPointInWater(pos)
	if type(IsPointInWater) ~= "function" then
		return false
	end
	local ok, inWater = pcall(IsPointInWater, pos)
	return ok and inWater == true
end

function S.pointInAabb(pos, minPos, maxPos, padding)
	if type(pos) ~= "table" or type(minPos) ~= "table" or type(maxPos) ~= "table" then
		return false
	end
	local pad = tonumber(padding) or 0
	local x = tonumber(pos[1]) or 0
	local y = tonumber(pos[2]) or 0
	local z = tonumber(pos[3]) or 0
	local mnx = (tonumber(minPos[1]) or 0) - pad
	local mny = (tonumber(minPos[2]) or 0) - pad
	local mnz = (tonumber(minPos[3]) or 0) - pad
	local mxx = (tonumber(maxPos[1]) or 0) + pad
	local mxy = (tonumber(maxPos[2]) or 0) + pad
	local mxz = (tonumber(maxPos[3]) or 0) + pad
	return x >= mnx and x <= mxx and y >= mny and y <= mxy and z >= mnz and z <= mxz
end

function S.pushPointOutsideAabb(pos, minPos, maxPos, padding)
	if not S.pointInAabb(pos, minPos, maxPos, padding) then
		return pos
	end
	local pad = tonumber(padding) or 0
	local x = tonumber(pos[1]) or 0
	local y = tonumber(pos[2]) or 0
	local z = tonumber(pos[3]) or 0
	local mnx = (tonumber(minPos[1]) or 0) - pad
	local mnz = (tonumber(minPos[3]) or 0) - pad
	local mxx = (tonumber(maxPos[1]) or 0) + pad
	local mxz = (tonumber(maxPos[3]) or 0) + pad
	local cx = (mnx + mxx) * 0.5
	local cz = (mnz + mxz) * 0.5
	local dx = x - cx
	local dz = z - cz
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.001 then
		dx, dz, len = 1, 0, 1
	end
	dx = dx / len
	dz = dz / len
	local ex = math.abs(mxx - mnx) * 0.5 + 0.1
	local ez = math.abs(mxz - mnz) * 0.5 + 0.1
	return Vec(cx + dx * ex, y, cz + dz * ez)
end

function S.hasOverheadCover(pos, opts)
	if type(pos) ~= "table" then
		return false
	end
	if type(QueryRaycast) ~= "function" then
		return false
	end
	local startOffset = optNumber(type(opts) == "table" and opts.coverProbeStart, 0.15)
	local probeHeight = math.max(0.5, optNumber(type(opts) == "table" and opts.coverProbeHeight, 7.0))
	local start = VecAdd(pos, Vec(0, startOffset, 0))
	withPhysicalQuery(opts)
	local ok, hit, dist = pcall(QueryRaycast, start, Vec(0, 1, 0), probeHeight)
	if not ok or hit ~= true then
		return false
	end
	return (tonumber(dist) or probeHeight) < (probeHeight - 0.05)
end

function S.hasLineOfSight(fromPos, toPos, opts)
	if type(fromPos) ~= "table" or type(toPos) ~= "table" then
		return true
	end
	if type(QueryRaycast) ~= "function" then
		return true
	end
	local startY = optNumber(type(opts) == "table" and opts.pathStartYOffset, 0.9)
	local endY = optNumber(type(opts) == "table" and opts.pathEndYOffset, 0.9)
	local start = VecAdd(fromPos, Vec(0, startY, 0))
	local finish = VecAdd(toPos, Vec(0, endY, 0))
	local delta = VecSub(finish, start)
	local dist = VecLength(delta)
	if dist <= 0.05 then
		return true
	end
	local dir = VecScale(delta, 1.0 / dist)
	withPhysicalQuery(opts)
	local ok, hit, hitDist = pcall(QueryRaycast, start, dir, dist)
	if not ok or hit ~= true then
		return true
	end
	local d = tonumber(hitDist) or 0
	return d >= (dist - 0.05)
end

function S.queryBlockedAabb(minPos, maxPos, opts)
	if type(QueryAabb) ~= "function" then
		return false
	end
	withPhysicalQuery(opts)
	local ok, v = pcall(QueryAabb, minPos, maxPos)
	if not ok then
		return false
	end
	if type(v) == "boolean" then
		return v == true
	end
	if type(v) == "number" then
		return v > 0
	end
	if type(v) == "table" then
		return #v > 0
	end
	return false
end

function S.resolveGroundPoint(pos, opts)
	if type(pos) ~= "table" then
		return nil
	end
	if type(QueryRaycast) ~= "function" then
		return pos
	end
	local castHeight = optNumber(type(opts) == "table" and opts.castHeight, 4.5)
	local castDistance = optNumber(type(opts) == "table" and opts.castDistance, 12.0)
	local groundOffset = optNumber(type(opts) == "table" and opts.groundOffset, 0.2)
	local start = VecAdd(pos, Vec(0, castHeight, 0))
	withPhysicalQuery(opts)
	local ok, hit, dist = pcall(QueryRaycast, start, Vec(0, -1, 0), castDistance)
	if not ok or hit ~= true then
		return nil
	end
	local d = tonumber(dist) or 0
	return Vec(start[1], start[2] - d + groundOffset, start[3])
end

function S.hasHeadClearance(pos, opts)
	if type(pos) ~= "table" then
		return false
	end
	if type(QueryRaycast) ~= "function" then
		return true
	end
	local clearance = optNumber(type(opts) == "table" and opts.headClearance, 1.95)
	local start = VecAdd(pos, Vec(0, 0.15, 0))
	withPhysicalQuery(opts)
	local ok, hit, dist = pcall(QueryRaycast, start, Vec(0, 1, 0), clearance)
	if not ok then
		return true
	end
	if hit ~= true then
		return true
	end
	return (tonumber(dist) or 0) >= math.max(0, clearance - 0.05)
end

function S.hasFootroom(pos, opts)
	if type(pos) ~= "table" then
		return false
	end
	local half = (type(opts) == "table" and type(opts.footHalfExtents) == "table" and opts.footHalfExtents) or Vec(0.35, 0.95, 0.35)
	local minPos = Vec(pos[1] - (tonumber(half[1]) or 0.35), pos[2], pos[3] - (tonumber(half[3]) or 0.35))
	local maxPos = Vec(
		pos[1] + (tonumber(half[1]) or 0.35),
		pos[2] + (tonumber(half[2]) or 0.95) * 2.0,
		pos[3] + (tonumber(half[3]) or 0.35)
	)
	return not S.queryBlockedAabb(minPos, maxPos, opts)
end

function S.findSafeExitTransformAroundBody(bodyId, fallbackTr, opts)
	local fallback = type(fallbackTr) == "table" and fallbackTr or Transform(Vec(0, 2, 0))
	local fallbackRot = fallback.rot or Quat()
	local fallbackPos = (type(fallback.pos) == "table") and fallback.pos or nil
	local body = tonumber(bodyId) or 0
	if body <= 0 then
		return fallback
	end

	opts = type(opts) == "table" and opts or {}
	local rejectBodyId = tonumber(opts.rejectBodyId) or body
	local groundRejectBodyId = tonumber(opts.groundRejectBodyId)
	if groundRejectBodyId == nil then
		groundRejectBodyId = rejectBodyId
	end
	local clearanceRejectBodyId = tonumber(opts.clearanceRejectBodyId)
	if clearanceRejectBodyId == nil then
		clearanceRejectBodyId = 0
	end
	local topYOffset = optNumber(opts.topYOffset, 1.35)
	local ringStep = math.max(0.1, optNumber(opts.ringStep, 1.2))
	local ringCount = math.max(1, math.floor(optNumber(opts.ringCount, 5)))
	local ringSteps = math.max(1, math.floor(optNumber(opts.ringSteps, 14)))
	local ringBaseOffset = optNumber(opts.ringBaseOffset, 0.5)
	local fallbackRadius = math.max(0.2, optNumber(opts.fallbackRadius, 1.75))
	local fallbackRingSteps = math.max(1, math.floor(optNumber(opts.fallbackRingSteps, 8)))
	local preferredPos = (type(opts.preferredPos) == "table") and opts.preferredPos or nil
	local preferredRadius = math.max(0.2, optNumber(opts.preferredRadius, 2.15))
	local preferredRingSteps = math.max(1, math.floor(optNumber(opts.preferredRingSteps, 12)))
	local preferredLocalRingSteps = math.max(1, math.floor(optNumber(opts.preferredLocalRingSteps, 16)))
	local preferredLocalRadii = {}
	if type(opts.preferredLocalRadii) == "table" and #opts.preferredLocalRadii > 0 then
		for i = 1, #opts.preferredLocalRadii do
			preferredLocalRadii[#preferredLocalRadii + 1] = math.max(0, tonumber(opts.preferredLocalRadii[i]) or 0)
		end
	else
		preferredLocalRadii = { 0.0, 0.35, 0.75, 1.15, 1.55, 1.95, 2.35, 2.8, 3.25 }
	end
	local maxRise = optNumber(opts.maxRiseFromFallback, 1.6)
	local maxDrop = optNumber(opts.maxDropFromFallback, 6.0)
	local maxHorizontal = math.max(0.5, optNumber(opts.maxHorizontalFromFallback, 6.5))
	local localSearchMaxHorizontal = math.max(0.5, optNumber(opts.localSearchMaxHorizontal, 3.4))
	local coverMismatchPenalty = math.max(0, optNumber(opts.coverMismatchPenalty, 3.5))
	local blockedPathPenalty = math.max(0, optNumber(opts.blockedPathPenalty, 2.4))
	local rejectInsideBodyPadding = optNumber(opts.rejectInsideBodyPadding, 0.08)
	local preferCoveredMatch = opts.preferCoveredMatch ~= false
	local hardCoverMatch = opts.hardCoverMatch == true
	local strictPreferredLos = opts.strictPreferredLos == true

	local baseOpts = {
		requirePhysical = opts.requirePhysical ~= false,
		castHeight = opts.castHeight,
		castDistance = opts.castDistance,
		groundOffset = opts.groundOffset,
		headClearance = opts.headClearance,
		footHalfExtents = opts.footHalfExtents,
		coverProbeHeight = opts.coverProbeHeight,
		coverProbeStart = opts.coverProbeStart,
		pathStartYOffset = opts.pathStartYOffset,
		pathEndYOffset = opts.pathEndYOffset,
	}
	local groundOpts = copyQueryOpts(baseOpts, groundRejectBodyId)
	local clearanceOpts = copyQueryOpts(baseOpts, clearanceRejectBodyId)

	local cands = {}
	if type(preferredPos) == "table" then
		cands[#cands + 1] = preferredPos
		for i = 0, preferredRingSteps - 1 do
			local a = (i / preferredRingSteps) * math.pi * 2.0
			cands[#cands + 1] = Vec(
				preferredPos[1] + math.cos(a) * preferredRadius,
				preferredPos[2] + 0.35,
				preferredPos[3] + math.sin(a) * preferredRadius
			)
		end
	end
	if type(fallbackPos) == "table" then
		cands[#cands + 1] = fallbackPos
		for i = 0, fallbackRingSteps - 1 do
			local a = (i / fallbackRingSteps) * math.pi * 2.0
			cands[#cands + 1] = Vec(
				fallbackPos[1] + math.cos(a) * fallbackRadius,
				fallbackPos[2] + 0.4,
				fallbackPos[3] + math.sin(a) * fallbackRadius
			)
		end
	end

	local bodyBoundsMin = nil
	local bodyBoundsMax = nil
	if type(GetBodyBounds) == "function" then
		local ok, mn, mx = pcall(GetBodyBounds, body)
		if ok and type(mn) == "table" and type(mx) == "table" then
			bodyBoundsMin = mn
			bodyBoundsMax = mx
			local cx = ((tonumber(mn[1]) or 0) + (tonumber(mx[1]) or 0)) * 0.5
			local cz = ((tonumber(mn[3]) or 0) + (tonumber(mx[3]) or 0)) * 0.5
			local ex = math.abs((tonumber(mx[1]) or 0) - (tonumber(mn[1]) or 0))
			local ez = math.abs((tonumber(mx[3]) or 0) - (tonumber(mn[3]) or 0))
			local topY = (tonumber(mx[2]) or 0) + topYOffset
			local baseRadius = math.max(1.5, math.max(ex, ez) * 0.5 + ringBaseOffset)

			local ringRadii = {}
			if type(opts.ringRadii) == "table" and #opts.ringRadii > 0 then
				for i = 1, #opts.ringRadii do
					ringRadii[#ringRadii + 1] = math.max(0, tonumber(opts.ringRadii[i]) or 0)
				end
			else
				ringRadii[1] = 0.0
				for i = 2, ringCount do
					ringRadii[i] = baseRadius + (i - 2) * ringStep
				end
			end

			for rIndex = 1, #ringRadii do
				local radius = ringRadii[rIndex]
				local steps = (radius <= 0.01) and 1 or ringSteps
				for i = 0, steps - 1 do
					local a = (i / steps) * math.pi * 2.0
					local x = cx + math.cos(a) * radius
					local z = cz + math.sin(a) * radius
					cands[#cands + 1] = Vec(x, topY, z)
					cands[#cands + 1] = Vec(x, topY + 0.7, z)
				end
			end
		end
	end

	local bestPos = nil
	local bestScore = nil
	local referencePos = preferredPos or fallbackPos
	local referenceCovered = nil
	if preferCoveredMatch and type(referencePos) == "table" then
		referenceCovered = S.hasOverheadCover(referencePos, clearanceOpts)
	end

	if type(preferredPos) == "table" and #preferredLocalRadii > 0 then
		local localBestPos = nil
		local localBestScore = nil
		for rIndex = 1, #preferredLocalRadii do
			local radius = preferredLocalRadii[rIndex]
			local steps = (radius <= 0.01) and 1 or preferredLocalRingSteps
			for i = 0, steps - 1 do
				local a = (i / steps) * math.pi * 2.0
				local cand = Vec(
					preferredPos[1] + math.cos(a) * radius,
					preferredPos[2] + 0.35,
					preferredPos[3] + math.sin(a) * radius
				)
				local groundPos = S.resolveGroundPoint(cand, groundOpts)
				if type(groundPos) == "table" then
					local validCandidate = not S.isPointInWater(groundPos)
						and S.hasHeadClearance(groundPos, clearanceOpts)
						and S.hasFootroom(groundPos, clearanceOpts)
					if validCandidate and type(bodyBoundsMin) == "table" and type(bodyBoundsMax) == "table"
						and S.pointInAabb(groundPos, bodyBoundsMin, bodyBoundsMax, rejectInsideBodyPadding) then
						validCandidate = false
					end
					local dx = (tonumber(groundPos[1]) or 0) - (tonumber(preferredPos[1]) or 0)
					local dy = (tonumber(groundPos[2]) or 0) - (tonumber(preferredPos[2]) or 0)
					local dz = (tonumber(groundPos[3]) or 0) - (tonumber(preferredPos[3]) or 0)
					local horizontal = math.sqrt(dx * dx + dz * dz)
					if validCandidate and (dy > maxRise or dy < -maxDrop or horizontal > localSearchMaxHorizontal) then
						validCandidate = false
					end
					if validCandidate and strictPreferredLos and not S.hasLineOfSight(preferredPos, groundPos, clearanceOpts) then
						validCandidate = false
					end
					if validCandidate then
						local score = horizontal * 2.2 + math.abs(dy) * 4.0
						if referenceCovered ~= nil then
							local candCovered = S.hasOverheadCover(groundPos, clearanceOpts)
							if candCovered ~= referenceCovered then
								if hardCoverMatch then
									validCandidate = false
								else
									score = score + coverMismatchPenalty
								end
							end
						end
						if validCandidate then
							if type(fallbackPos) == "table" then
								local fbH = horizontalDist(groundPos, fallbackPos)
								score = score + fbH * 0.2
							end
							if localBestScore == nil or score < localBestScore then
								localBestScore = score
								localBestPos = groundPos
							end
						end
					end
				end
			end
		end
		if type(localBestPos) == "table" then
			return Transform(localBestPos, fallbackRot)
		end
	end

	for i = 1, #cands do
		local groundPos = S.resolveGroundPoint(cands[i], groundOpts)
		if type(groundPos) == "table" then
			local validCandidate = not S.isPointInWater(groundPos)
				and S.hasHeadClearance(groundPos, clearanceOpts)
				and S.hasFootroom(groundPos, clearanceOpts)
			if validCandidate and type(bodyBoundsMin) == "table" and type(bodyBoundsMax) == "table"
				and S.pointInAabb(groundPos, bodyBoundsMin, bodyBoundsMax, rejectInsideBodyPadding) then
				validCandidate = false
			end
				if validCandidate then
					local dx = 0
					local dz = 0
					local dy = 0
					if type(referencePos) == "table" then
						dx = (tonumber(groundPos[1]) or 0) - (tonumber(referencePos[1]) or 0)
						dy = (tonumber(groundPos[2]) or 0) - (tonumber(referencePos[2]) or 0)
						dz = (tonumber(groundPos[3]) or 0) - (tonumber(referencePos[3]) or 0)
						local horizontal = math.sqrt(dx * dx + dz * dz)
						if not (dy > maxRise or dy < -maxDrop or horizontal > maxHorizontal) then
							local prefLosBlocked = false
							if type(preferredPos) == "table" then
								prefLosBlocked = not S.hasLineOfSight(preferredPos, groundPos, clearanceOpts)
							end
							if not (strictPreferredLos and prefLosBlocked) then
								local score = horizontal + math.abs(dy) * 2.75
								if type(preferredPos) == "table" then
									local prefH = horizontalDist(groundPos, preferredPos)
									local prefDy = (tonumber(groundPos[2]) or 0) - (tonumber(preferredPos[2]) or 0)
									score = prefH * 1.55 + math.abs(prefDy) * 3.2
									if type(fallbackPos) == "table" then
										local fbH = horizontalDist(groundPos, fallbackPos)
										local fbDy = (tonumber(groundPos[2]) or 0) - (tonumber(fallbackPos[2]) or 0)
										score = score + fbH * 0.35 + math.abs(fbDy) * 0.45
									end
								end
								if referenceCovered ~= nil then
									local candCovered = S.hasOverheadCover(groundPos, clearanceOpts)
									if candCovered ~= referenceCovered then
										if hardCoverMatch and type(preferredPos) == "table" then
											score = nil
										else
											score = score + coverMismatchPenalty
										end
									end
								end
								if score ~= nil and type(preferredPos) == "table" and prefLosBlocked then
									score = score + blockedPathPenalty
								end
								if score ~= nil and (bestScore == nil or score < bestScore) then
									bestScore = score
									bestPos = groundPos
								end
							end
						end
					else
						return Transform(groundPos, fallbackRot)
					end
				end
			end
		end

	if type(bestPos) == "table" then
		return Transform(bestPos, fallbackRot)
	end

	if type(fallbackPos) == "table" and type(bodyBoundsMin) == "table" and type(bodyBoundsMax) == "table" then
		local nudge = S.pushPointOutsideAabb(fallbackPos, bodyBoundsMin, bodyBoundsMax, rejectInsideBodyPadding + 0.2)
		local gp = S.resolveGroundPoint(nudge, groundOpts)
		if type(gp) == "table" and not S.isPointInWater(gp) and S.hasHeadClearance(gp, clearanceOpts) and S.hasFootroom(gp, clearanceOpts) then
			return Transform(gp, fallbackRot)
		end
	end

	return fallback
end
