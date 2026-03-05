HS = HS or {}
HS.cli = HS.cli or {}

local function teamColor(teamId)
	return HS.engine.teamColor(teamId)
end

local function roleLabel(teamId)
	if HS.select and HS.select.roleKey then
		return HS.t(HS.select.roleKey(teamId))
	end
	if teamId == HS.const.TEAM_SEEKERS then return "SEEKER" end
	if teamId == HS.const.TEAM_HIDERS then return "HIDER" end
	return "SPECTATOR"
end

local _topHud = { endSoundStarted = false }

local function formatClock(sec)
	local t = math.max(0, math.ceil(tonumber(sec) or 0))
	local m = math.floor(t / 60)
	local s = t - m * 60
	return string.format("%02d:%02d", m, s)
end

local function updateTimerSound(time)
	if time > 10 then
		_topHud.endSoundStarted = false
	elseif time > 0 and not _topHud.endSoundStarted then
		_topHud.endSoundStarted = true
		HS.engine.uiSound("timer/10-s-timer.ogg")
	end
end

local function drawTopMatchPanel(vm)
	if not vm or not vm.ready then return end
	local tleft = tonumber(vm.timeLeft) or 0
	updateTimerSound(tleft)

	local roundsToPlay = tonumber(vm.roundsToPlay) or 0
	local round = tonumber(vm.round) or 0

	local scoreSeekers = tonumber(vm.scoreSeekers) or 0
	local scoreHiders = tonumber(vm.scoreHiders) or 0

	local timerText = formatClock(tleft)
	local roundsText = ""
	if roundsToPlay > 0 then
		roundsText = tostring(round) .. "/" .. tostring(roundsToPlay)
	else
		roundsText = tostring(round) .. "/∞"
	end

	local seekerC = teamColor(HS.const.TEAM_SEEKERS)
	local hiderC = teamColor(HS.const.TEAM_HIDERS)

	local baseW = 440
	local baseH = 180
	local radius = 24
	local cut = 24
	local pad = 18

	local maxW = math.max(0, UiWidth() - 24)
	local scale = 1.0
	if maxW > 0 then
		scale = HS.util.clamp(maxW / baseW, 0.72, 1.0)
	end

	local innerW = baseW - pad * 2
	local innerH = baseH - cut - pad * 2
	local row1H = 56
	local rowGap = 10
	local row2Y = row1H + rowGap
	local row2H = math.max(44, innerH - row2Y)
	local colW = innerW / 3

	local function drawTopCell(cellIndex, label, value, labelColor, valueColor, valueFontSize)
		UiPush()
		UiAlign("center top")
		UiTranslate((cellIndex - 1) * colW + colW / 2, 0)

		if labelColor then
			UiColor(labelColor[1], labelColor[2], labelColor[3], 0.80)
		else
			UiColor(1, 1, 1, 0.55)
		end
		UiFont("regular.ttf", FONT_SIZE_18)
		UiText(label)

		UiTranslate(0, 24)
		UiTextShadow(0, 0, 0, 0.65, 2.0, 0.75)
		UiFont(FONT_BOLD, valueFontSize)
		if valueColor then
			UiColor(valueColor[1], valueColor[2], valueColor[3], 1)
		else
			UiColor(COLOR_WHITE)
		end
		UiText(value)
		UiPop()
	end

	UiPush()
	UiAlign("center top")
	UiTranslate(UiCenter(), 0)
	UiScale(scale)

	UiTranslate(0, -cut)
	if HS.ui.primitives and HS.ui.primitives.glassPill then
		HS.ui.primitives.glassPill(baseW, baseH, radius, 1.0)
	else
		uiDrawPanel(baseW, baseH, radius)
	end

	UiPush()
	UiAlign("left top")
	UiTranslate(-baseW / 2 + pad, cut + pad)

	UiPush()
	UiColor(1, 1, 1, 0.10)
	UiTranslate(colW, 0)
	UiRect(2, row1H)
	UiTranslate(colW, 0)
	UiRect(2, row1H)
	UiPop()

	UiPush()
	UiColor(1, 1, 1, 0.10)
	UiTranslate(0, row1H + rowGap / 2)
	UiRect(innerW, 2)
	UiPop()

	UiPush()
	UiTranslate(0, row2Y)
	UiColor(1, 1, 1, 0.06)
	UiRoundedRect(innerW, row2H, 18)
	UiColor(1, 1, 1, 0.08)
	UiRoundedRectOutline(innerW, row2H, 18, 2)
	UiPop()

	drawTopCell(1, HS.t("hs.team.seekers"), tostring(scoreSeekers), seekerC, seekerC, FONT_SIZE_32)
	drawTopCell(2, HS.t("hs.ui.top.rounds"), roundsText, nil, nil, FONT_SIZE_32)
	drawTopCell(3, HS.t("hs.team.hiders"), tostring(scoreHiders), hiderC, hiderC, FONT_SIZE_32)

	UiPush()
	UiAlign("center middle")
	UiTranslate(innerW / 2, row2Y + row2H / 2)
	UiTextShadow(0, 0, 0, 0.65, 2.0, 0.75)
	if tleft > 0 and tleft <= 10.0 then
		UiColor(COLOR_RED)
	else
		UiColor(COLOR_WHITE)
	end
	UiFont(FONT_BOLD, FONT_SIZE_40)
	UiText(timerText)
	UiPop()

	UiPop()
	UiPop()
end

local _markerPosOffset = Vec(0, 1.0, 0)
local _markerLabelOffset = Vec(0, 1.2, 0)
local _tagAimOffset = Vec(0, 1.2, 0)

local function pickPlayerUnderCrosshair(playerId)
	local pid = tonumber(playerId) or 0

	local body = GetPlayerPickBody(pid)
	if body == 0 then body = GetPlayerPickBody(0) end
	if body == 0 then body = GetPlayerPickBody() end
	if body ~= 0 then
		local target = GetBodyPlayer(body)
		if type(target) == "number" and target > 0 then
			return target
		end
	end

	local shape = GetPlayerPickShape(pid)
	if shape == 0 then shape = GetPlayerPickShape(0) end
	if shape == 0 then shape = GetPlayerPickShape() end
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

local function aimPos(playerId)
	local tr = GetPlayerTransform(playerId)
	return VecAdd(tr.pos, _tagAimOffset)
end

local function isEligibleHider(vm, localId, playerId)
	if playerId == 0 or playerId == localId then return false end
	if not IsPlayerValid(playerId) then return false end
	if vm.outOf[playerId] == true then return false end
	return (vm.teamOf[playerId] or 0) == HS.const.TEAM_HIDERS
end

local function hasLineOfSightToPlayer(camPos, targetId, targetPos)
	targetPos = targetPos or aimPos(targetId)
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

local function drawTeamMarkers(ctx, vm)
	if not vm or not vm.ready then return end
	if not vm.teamOf or not vm.outOf then return end

	local localId = vm.me and vm.me.id or 0
	local localTeam = vm.me and vm.me.team or 0

	if localTeam ~= HS.const.TEAM_SEEKERS and localTeam ~= HS.const.TEAM_HIDERS then return end
	if vm.phase ~= HS.const.PHASE_HIDING and vm.phase ~= HS.const.PHASE_SEEKING then return end

	local markers = (ctx and ctx.cache and (ctx.cache._hudMarkers or {})) or {}
	if ctx and ctx.cache then
		ctx.cache._hudMarkers = markers
	end

	local color = teamColor(localTeam)
	local maxRange = 80.0
	local teamOf = vm.teamOf
	local outOf = vm.outOf

	local n = 0
	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		if pid ~= localId and IsPlayerValid(pid) and not IsPlayerDisabled(pid) and GetPlayerHealth(pid) > 0 then
			if outOf[pid] ~= true and teamOf[pid] == localTeam then
				n = n + 1
				local m = markers[n] or {}
				markers[n] = m
				m.pos = VecAdd(GetPlayerTransform(pid).pos, _markerPosOffset)
				m.offset = _markerLabelOffset
				m.color = color
				m.label = HS.engine.playerName(pid)
				m.lineOfSightRequired = true
				m.maxRange = maxRange
				m.drawIconInView = false
				m.player = pid
			end
		end
	end
	for i = #markers, n + 1, -1 do
		markers[i] = nil
	end

	hudDrawWorldMarkers(markers)
end

local function drawPickRoleHint(vm)
	if not vm or not vm.ready then return end
	if not vm.teamOf or not vm.outOf then return end
	if vm.phase ~= HS.const.PHASE_HIDING and vm.phase ~= HS.const.PHASE_SEEKING then return end

	local localId = vm.me and vm.me.id or 0
	local localTeam = vm.me and vm.me.team or 0
	local localOut = vm.me and vm.me.out == true
	if localOut or localTeam == 0 then return end

	local taggingEnabled = vm.settings and vm.settings.taggingEnabled == true
	local tagCandidate = 0
	if taggingEnabled and vm.phase == HS.const.PHASE_SEEKING and localTeam == HS.const.TEAM_SEEKERS then
		local range = tonumber(vm.settings and vm.settings.tagRangeMeters) or 4.0

		local cam = (HS.engine and HS.engine.playerCameraTransform and HS.engine.playerCameraTransform()) or nil
		local camPos = (type(cam) == "table" and cam.pos) or GetPlayerTransform(localId).pos
		local aimTr = (type(cam) == "table" and cam) or GetPlayerTransform(localId)
		local fwd = TransformToParentVec(aimTr, Vec(0, 0, -1))
		fwd = VecNormalize(fwd)

		local seekerPos = GetPlayerTransform(localId).pos
		local minDot = 0.97

		local function aimDotTo(pid)
			local to = VecSub(aimPos(pid), camPos)
			local dist = VecLength(to)
			if dist <= 0.001 then return 1.0 end
			return VecDot(VecNormalize(to), fwd)
		end

		local picked = pickPlayerUnderCrosshair(localId)
		if isEligibleHider(vm, localId, picked) then
			local ptr = GetPlayerTransform(picked)
			if HS.util.vecDist(seekerPos, ptr.pos) <= range then
				local dot = aimDotTo(picked)
				local ppos = VecAdd(ptr.pos, _tagAimOffset)
				if dot >= minDot and hasLineOfSightToPlayer(camPos, picked, ppos) then
					tagCandidate = picked
				end
			end
		end

		if tagCandidate == 0 then
			local bestDot = minDot
			local best = 0

			for _, pid in ipairs(HS.util.getPlayersSorted()) do
				if isEligibleHider(vm, localId, pid) then
					local ptr = GetPlayerTransform(pid)
					if HS.util.vecDist(seekerPos, ptr.pos) <= range then
						local ppos = VecAdd(ptr.pos, _tagAimOffset)
						local to = VecSub(ppos, camPos)
						local dist = VecLength(to)
						if dist > 0.001 then
							local dir = VecNormalize(to)
							local dot = VecDot(dir, fwd)
							if dot > bestDot and hasLineOfSightToPlayer(camPos, pid, ppos) then
								bestDot = dot
								best = pid
							end
						end
					end
				end
			end

			tagCandidate = best
		end
	end

	local function drawTagPromptGlyph(alpha, iconSize)
		alpha = HS.util.clamp(tonumber(alpha) or 1, 0, 1)
		local icon = (HS.ui and HS.ui.icons and HS.ui.icons.tag) or "ui/hud/crosshair-hand.png"
		iconSize = tonumber(iconSize) or 30
		local iconBox = iconSize + 10
		local keyW = math.max(36, iconSize + 14)
		local keyH = math.max(28, iconSize + 4)
		local gapY = math.max(6, math.floor(iconSize * 0.25))
		local totalH = iconBox + gapY + keyH
		local keyFont = (iconSize >= 34 and FONT_SIZE_25) or FONT_SIZE_22

		UiPush()
		UiAlign("center middle")

		UiPush()
		UiTranslate(0, -totalH / 2 + iconBox / 2)
		if HS.ui.primitives and HS.ui.primitives.iconBadge then
			HS.ui.primitives.iconBadge(icon, iconSize, alpha)
		end
		UiPop()

		UiPush()
		UiTranslate(0, totalH / 2 - keyH / 2)
		UiAlign("center middle")
		UiColor(0, 0, 0, 0.35 * alpha)
		UiRoundedRect(keyW, keyH, 10)
		UiColor(1, 1, 1, 0.14 * alpha)
		UiRoundedRectOutline(keyW, keyH, 10, 2)
		UiTextShadow(0, 0, 0, 0.75 * alpha, 2.0, 0.75)
		UiColor(1, 1, 1, 0.92 * alpha)
		UiFont(FONT_BOLD, keyFont)
		UiText("E")
		UiPop()

		UiPop()
	end

	if tagCandidate ~= 0 then
		UiPush()
		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle() + 60)
		drawTagPromptGlyph(1.0, 48)
		UiPop()
	end

	local targetId = pickPlayerUnderCrosshair(localId)
	if targetId == 0 or targetId == localId then return end
	if not IsPlayerValid(targetId) then return end

	local targetTeam = vm.teamOf[targetId] or 0
	if targetTeam ~= HS.const.TEAM_SEEKERS and targetTeam ~= HS.const.TEAM_HIDERS then return end
	if vm.outOf[targetId] == true then return end

	local role = roleLabel(targetTeam)
	local name = HS.engine.playerName(targetId)
	local c = teamColor(targetTeam)

	local showEliminatePrompt = (not taggingEnabled and vm.phase == HS.const.PHASE_SEEKING and localTeam == HS.const.TEAM_SEEKERS and targetTeam == HS.const.TEAM_HIDERS)

	UiPush()
	UiAlign("center middle")
	UiTranslate(UiCenter(), UiMiddle() + 110)

	UiPush()
	UiFont(FONT_BOLD, FONT_SIZE_25)
	local roleW = UiGetTextSize(role .. ": ")
	UiFont("regular.ttf", FONT_SIZE_20)
	local nameW = UiGetTextSize(name)
	UiPop()

	local totalW = roleW + nameW
	local w = math.max(280, totalW + 44)
	local h = showEliminatePrompt and 72 or 54

	uiDrawPanel(w, h, 14)

	UiPush()
	UiAlign("left middle")
	UiTranslate(-totalW / 2, showEliminatePrompt and -10 or 0)

	UiColor(c[1], c[2], c[3], 1)
	UiFont(FONT_BOLD, FONT_SIZE_25)
	UiTextShadow(0, 0, 0, 0.7, 2.0, 0.75)
	UiText(role .. ": ")

	UiTranslate(roleW, 0)
	UiColor(COLOR_WHITE)
	UiFont("regular.ttf", FONT_SIZE_20)
	UiTextShadow(0, 0, 0, 0.7, 2.0, 0.75)
	UiText(name)
	UiPop()

	if showEliminatePrompt then
		UiPush()
		UiAlign("center middle")
		UiTranslate(0, 18)
		UiColor(1, 1, 1, 0.7)
		UiFont("regular.ttf", FONT_SIZE_18)
		UiText(HS.t("hs.ui.pickRole.eliminatePrompt"))
		UiPop()
	end

	UiPop()
end

function HS.cli.drawInGame(_dt, ctx, vm)
	if not vm or not vm.ready then return end

	local phase = vm.phase or HS.const.PHASE_SETUP
	local tleft = tonumber(vm.timeLeft) or 0
	local team = vm.me and vm.me.team or 0
	local out = vm.me and vm.me.out == true
	local spectating = vm.me and vm.me.spectating == true

	drawTopMatchPanel(vm)

	if not spectating then
		drawTeamMarkers(ctx, vm)
		drawPickRoleHint(vm)
	end

	if phase == HS.const.PHASE_HIDING and team == HS.const.TEAM_SEEKERS and not out then
		UiPush()
		UiAlign("left top")
		UiColor(0, 0, 0, 1)
		UiRect(UiWidth(), UiHeight())

		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle())
		uiDrawPanel(520, 220, 16)
		UiTranslate(0, -16)

		UiColor(COLOR_WHITE)
		UiFont(FONT_BOLD, FONT_SIZE_50)
		UiText(HS.t("hs.ui.blind.title"))
		UiTranslate(0, 70)
		UiFont("regular.ttf", FONT_SIZE_25)
		UiText(HS.t("hs.ui.blind.subtitle", { time = HS.util.formatSeconds(tleft) }))
		UiPop()
	end

	if spectating and phase ~= HS.const.PHASE_SETUP then
		if HS.cli.spectate and HS.cli.spectate.draw then
			HS.cli.spectate.draw(ctx, vm)
		else
			UiPush()
			UiAlign("center bottom")
			UiTranslate(UiCenter(), UiHeight() - 26)
			uiDrawTextPanel(HS.t("hs.ui.spectating.title"), 1)
			UiPop()
		end
	end
end
