
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

local function chooseTarget(ctx, vm)
	if not vm or not vm.ready or not vm.me then return 0 end
	if not vm.teamOf or not vm.outOf then return 0 end

	local st = ctx.cache._spectateState or {}
	ctx.cache._spectateState = st

	local localId = tonumber(vm.me.id) or 0
	local localTeam = tonumber(vm.me.team) or 0

	local candidates = nil
	if localTeam == HS.const.TEAM_SEEKERS or localTeam == HS.const.TEAM_HIDERS then
		candidates = fillCandidates(ctx, vm, localTeam)
	else
		candidates = fillAnyCandidates(ctx, vm)
	end

	if localId ~= 0 then
		for i = 1, #candidates do
			if candidates[i] == localId then
				candidates[i] = 0
				break
			end
		end
	end

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
		for i = 1, #candidates do
			local pid = tonumber(candidates[i]) or 0
			if pid ~= 0 then
				target = pid
				break
			end
		end
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

	local tr = HS.engine.playerCameraTransform(targetId)
	if not tr then return false end
	return HS.engine.setCameraTransform(tr)
end

function S.draw(ctx, vm)
	if not isSpectating(vm) then return end
	if not ctx or not ctx.cache then return end

	local st = ctx.cache._spectateState or {}
	local targetId = tonumber(st.targetId) or 0
	local localTeam = tonumber(st.localTeam) or (vm.me and tonumber(vm.me.team) or 0)

	local label = HS.t("hs.ui.spectating.subtitle")
	if targetId ~= 0 and IsPlayerValid(targetId) then
		label = HS.t("hs.ui.spectating.following", { name = HS.engine.playerName(targetId) })
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
	UiColor(1, 1, 1, 0.92)
	UiFont("regular.ttf", FONT_SIZE_18)
	UiText(label)

	UiPop()
end
