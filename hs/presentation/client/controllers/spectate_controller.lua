
HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.spectate = HS.cli.spectate or {}

local S = HS.cli.spectate

local function clearArray(t)
	for i = #t, 1, -1 do
		t[i] = nil
	end
end

local function isActivePlayer(vm, pid)
	if pid == 0 then return false end
	if not IsPlayerValid(pid) then return false end
	if vm.outOf and vm.outOf[pid] == true then return false end
	local team = vm.teamOf and vm.teamOf[pid] or 0
	return team == HS.const.TEAM_SEEKERS or team == HS.const.TEAM_HIDERS
end

local function fillCandidates(ctx, vm, teamId)
	local out = ctx.cache._spectateCandidates or {}
	ctx.cache._spectateCandidates = out
	clearArray(out)

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		if isActivePlayer(vm, pid) and ((vm.teamOf and vm.teamOf[pid]) or 0) == teamId then
			out[#out + 1] = pid
		end
	end
	return out
end

local function fillAnyCandidates(ctx, vm)
	local out = ctx.cache._spectateCandidates or {}
	ctx.cache._spectateCandidates = out
	clearArray(out)

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		if isActivePlayer(vm, pid) then
			out[#out + 1] = pid
		end
	end
	return out
end

local function removeCandidate(candidates, pid)
	pid = tonumber(pid) or 0
	if pid == 0 then return end
	for i = 1, #candidates do
		if candidates[i] == pid then
			candidates[i] = 0
			return
		end
	end
end

local function pickRandomCandidate(candidates)
	local pool = {}
	for i = 1, #candidates do
		local pid = tonumber(candidates[i]) or 0
		if pid ~= 0 then
			pool[#pool + 1] = pid
		end
	end
	if #pool == 0 then return 0 end
	if type(GetRandomInt) == "function" then
		return pool[GetRandomInt(1, #pool)]
	end
	return pool[1]
end

local function chooseTarget(ctx, vm)
	if not vm or not vm.ready or not vm.me then return 0 end
	if not vm.teamOf or not vm.outOf then return 0 end

	local st = ctx.cache._spectateState or {}
	ctx.cache._spectateState = st

	local localId = tonumber(vm.me.id) or 0
	local localTeam = tonumber(vm.me.team) or 0

	local preferTeamOnly = (localTeam == HS.const.TEAM_SEEKERS or localTeam == HS.const.TEAM_HIDERS)
	local candidates = preferTeamOnly and fillCandidates(ctx, vm, localTeam) or fillAnyCandidates(ctx, vm)

	removeCandidate(candidates, localId)

	local target = tonumber(st.targetId) or 0
	local valid = false
	if target ~= 0 then
		for i = 1, #candidates do
			if candidates[i] == target then
				valid = true
				break
			end
		end
	end

	if not valid then
		target = pickRandomCandidate(candidates)
	end

	-- If no teammate is alive, fallback to any active player (typically enemy team).
	if target == 0 and preferTeamOnly then
		candidates = fillAnyCandidates(ctx, vm)
		removeCandidate(candidates, localId)
		target = pickRandomCandidate(candidates)
	end

	st.targetId = target
	st.localTeam = localTeam
	return target
end

local function isSpectating(vm)
	if not vm or not vm.ready or not vm.me then return false end
	if vm.phase == HS.const.PHASE_SETUP then return false end
	return vm.me.spectating == true
end

function S.init()
end

function S.tick(_dt, ctx, vm)
	if not ctx or not ctx.cache then return end

	local st = ctx.cache._spectateState or {}
	ctx.cache._spectateState = st

	if not isSpectating(vm) then
		st.targetId = 0
		st.localTeam = 0
		return
	end

	chooseTarget(ctx, vm)
end

function S.applyCamera(ctx, vm)
	if not isSpectating(vm) then return false end
	if not ctx or not ctx.cache then return false end

	local st = ctx.cache._spectateState
	local targetId = st and tonumber(st.targetId) or 0
	if targetId == 0 then
		targetId = chooseTarget(ctx, vm)
	end
	if targetId == 0 then return false end

	local pTr = GetPlayerTransform(targetId)
	if type(pTr) ~= "table" or type(pTr.pos) ~= "table" then return false end

	local camTr = HS.engine.playerCameraTransform(targetId) or pTr
	local forward = TransformToParentVec(camTr, Vec(0, 0, -1))
	if VecLength(forward) < 0.001 then
		forward = TransformToParentVec(pTr, Vec(0, 0, -1))
	end
	if VecLength(forward) < 0.001 then
		forward = Vec(0, 0, -1)
	else
		forward = VecNormalize(forward)
	end

	local focus = VecAdd(pTr.pos, Vec(0, 1.35, 0))
	local desired = VecAdd(focus, VecScale(forward, -4.25))
	desired = VecAdd(desired, Vec(0, 1.1, 0))

	if type(QueryRaycast) == "function" then
		local delta = VecSub(desired, focus)
		local dist = VecLength(delta)
		if dist > 0.001 then
			QueryRequire("physical")
			local dir = VecNormalize(delta)
			local hit, hitDist = QueryRaycast(focus, dir, dist, 0.15, true)
			if hit == true then
				local safeDist = math.max(0.5, (tonumber(hitDist) or dist) - 0.2)
				desired = VecAdd(focus, VecScale(dir, safeDist))
			end
		end
	end

	local lookAt = VecAdd(focus, Vec(0, 0.2, 0))
	local tr = Transform(desired, QuatLookAt(desired, lookAt))
	return HS.engine.setCameraTransform(tr)
end

function S.draw(ctx, vm)
	if not isSpectating(vm) then return end
	if not ctx or not ctx.cache then return end

	local st = ctx.cache._spectateState or {}
	local targetId = tonumber(st.targetId) or 0
	local localTeam = tonumber(st.localTeam) or (vm.me and tonumber(vm.me.team) or 0)

	local label = HS.t("hs.ui.spectating.subtitle")
	local followPrefix, followName, followSuffix, followNameColor = nil, nil, nil, nil
	if targetId ~= 0 and IsPlayerValid(targetId) then
		followName = HS.engine.playerName(targetId)
		local sentinel = "\31HS_NAME\30"
		local templ = HS.t("hs.ui.spectating.following", { name = sentinel })
		local a, b = string.find(templ, sentinel, 1, true)
		if a then
			followPrefix = string.sub(templ, 1, a - 1)
			followSuffix = string.sub(templ, b + 1)
		else
			followPrefix = HS.t("hs.ui.spectating.following", { name = "" })
			followSuffix = ""
		end
		label = tostring(followPrefix or "") .. tostring(followName or "") .. tostring(followSuffix or "")

		local team = (vm.teamOf and tonumber(vm.teamOf[targetId])) or 0
		followNameColor = HS.engine.teamColor(team)
	elseif localTeam == HS.const.TEAM_SEEKERS or localTeam == HS.const.TEAM_HIDERS then
		label = HS.t("hs.ui.spectating.noTeammate")
	end

	local marginBottom = 34

	UiPush()
	UiAlign("center middle")

	UiFont("regular.ttf", FONT_SIZE_18)
	local tw = UiGetTextSize(label)
	local w = math.max(320, (tonumber(tw) or 0) + 70)
	local h = 46
	UiTranslate(UiCenter(), UiHeight() - marginBottom - h * 0.5)
	if HS.ui.primitives and HS.ui.primitives.glassPill then
		HS.ui.primitives.glassPill(w, h, 16, 0.95)
	else
		uiDrawPanel(w, h, 16)
	end

	UiTextShadow(0, 0, 0, 0.75, 2.0, 0.75)
	UiFont("regular.ttf", FONT_SIZE_18)
	if followPrefix ~= nil and followName ~= nil and followSuffix ~= nil then
		local wPrefix = UiGetTextSize(followPrefix)
		local wName = UiGetTextSize(followName)
		local wSuffix = UiGetTextSize(followSuffix)
		wPrefix = tonumber(wPrefix) or 0
		wName = tonumber(wName) or 0
		wSuffix = tonumber(wSuffix) or 0
		local total = wPrefix + wName + wSuffix

		UiPush()
		UiAlign("left middle")
		UiTranslate(-total * 0.5, 0)

		UiColor(1, 1, 1, 0.92)
		if followPrefix ~= "" then
			UiText(followPrefix)
			UiTranslate(wPrefix, 0)
		end

		local c = followNameColor or { 1, 1, 1, 1 }
		UiColor(c[1] or 1, c[2] or 1, c[3] or 1, 0.92)
		if followName ~= "" then
			UiText(followName)
			UiTranslate(wName, 0)
		end

		UiColor(1, 1, 1, 0.92)
		if followSuffix ~= "" then
			UiText(followSuffix)
		end

		UiPop()
	else
		UiColor(1, 1, 1, 0.92)
		UiText(label)
	end

	UiPop()
end
