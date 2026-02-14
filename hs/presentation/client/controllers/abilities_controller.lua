HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.abilities = HS.cli.abilities or {}

local C = HS.cli.abilities

C.impl = C.impl or {}
C.fx = C.fx or {}

local SIDEBAR_SLOT_COUNT = 5
local SLOT_FALLBACK_KEYS = {
	[3] = "abilitySlot3",
	[4] = "abilitySlot4",
	[5] = "abilitySlot5",
}
local PRESS_ANIM_SECONDS = 0.16
local PRESS_ANIM_IN_FRACTION = 0.35

local function clamp(v, a, b)
	if HS.util and HS.util.math and HS.util.math.clamp then
		return HS.util.math.clamp(tonumber(v) or 0, a, b)
	end
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

local function clearTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

function C.register(abilityId, impl)
	abilityId = tostring(abilityId or "")
	if abilityId == "" then return false end
	if type(impl) ~= "table" then return false end
	C.impl[abilityId] = impl
	return true
end

if type(C._pendingImpl) == "table" then
	local pending = C._pendingImpl
	C._pendingImpl = nil
	for i = 1, #pending do
		local it = pending[i]
		if type(it) == "table" then
			C.register(it.id, it.impl)
		end
	end
end

function C.fx.lightenColor(c)
	if type(c) ~= "table" then
		return 0.85, 0.85, 0.95
	end
	local r = clamp((c[1] or 1) * 0.35 + 0.65, 0, 1)
	local g = clamp((c[2] or 1) * 0.35 + 0.65, 0, 1)
	local b = clamp((c[3] or 1) * 0.35 + 0.65, 0, 1)
	return r, g, b
end

function C.fx.vfxInRange(pos)
	local localId = HS.engine.localPlayerId()
	if type(pos) ~= "table" then return true end
	if localId == 0 then return true end
	if HS.engine and HS.engine.isPlayerValid and not HS.engine.isPlayerValid(localId) then return true end
	local tr = GetPlayerTransform(localId)
	local localPos = (type(tr) == "table") and tr.pos or nil
	if type(localPos) ~= "table" then return true end
	local ok, dist = pcall(HS.util.vecDist, pos, localPos)
	if not ok then return true end
	return (tonumber(dist) or 0) <= 120.0
end

local function isActivePhase(phase)
	return phase == HS.const.PHASE_HIDING or phase == HS.const.PHASE_SEEKING
end

local function isLocalHider(vm)
	if not vm or not vm.me then return false end
	return vm.me.team == HS.const.TEAM_HIDERS and vm.me.out ~= true and vm.me.spectating ~= true
end

local function hiderAbilitiesEnabled(vm)
	if not vm or not vm.settings then return true end
	return vm.settings.hiderAbilitiesEnabled ~= false
end

local function abilityVm(vm, def)
	if not vm or not def or not vm.abilities then return nil end
	return vm.abilities[def.id]
end

local function abilitySlot(def)
	return math.floor(tonumber(def and (def.slot or (def.ui and def.ui.slot))) or 0)
end

local function abilityInputKey(def, slot)
	slot = tonumber(slot) or abilitySlot(def)
	if slot >= 3 and slot <= SIDEBAR_SLOT_COUNT then
		return SLOT_FALLBACK_KEYS[slot] or ""
	end
	local key = tostring(def and def.key or "")
	if key ~= "" then
		return key
	end
	return SLOT_FALLBACK_KEYS[slot] or ""
end

local function beginPressAnim(abilityId, now)
	abilityId = tostring(abilityId or "")
	if abilityId == "" then return end
	now = tonumber(now) or HS.engine.now()
	C._pressAnims = C._pressAnims or {}
	C._pressAnims[abilityId] = {
		startedAt = now,
		untilAt = now + PRESS_ANIM_SECONDS,
	}
end

local function pressAnimAmount(abilityId, now)
	abilityId = tostring(abilityId or "")
	if abilityId == "" then return 0 end
	local anims = C._pressAnims
	if type(anims) ~= "table" then return 0 end
	local rec = anims[abilityId]
	if type(rec) ~= "table" then return 0 end

	now = tonumber(now) or HS.engine.now()
	local t0 = tonumber(rec.startedAt) or 0
	local t1 = tonumber(rec.untilAt) or 0
	if t1 <= t0 or now >= t1 then
		anims[abilityId] = nil
		return 0
	end

	local p = clamp((now - t0) / (t1 - t0), 0, 1)
	if p <= PRESS_ANIM_IN_FRACTION then
		return clamp(p / PRESS_ANIM_IN_FRACTION, 0, 1)
	end

	local outSpan = math.max(0.0001, 1.0 - PRESS_ANIM_IN_FRACTION)
	return clamp(1.0 - ((p - PRESS_ANIM_IN_FRACTION) / outSpan), 0, 1)
end

local function getPredictedArmedUntil(abilityId, now)
	abilityId = tostring(abilityId or "")
	local map = C._predictedArmedUntil
	if abilityId == "" or type(map) ~= "table" then
		return 0
	end
	local untilAt = tonumber(map[abilityId]) or 0
	now = tonumber(now) or HS.engine.now()
	if untilAt > 0 and now >= untilAt then
		map[abilityId] = nil
		return 0
	end
	return untilAt
end

local function setPredictedArmed(def, now)
	if type(def) ~= "table" then return end
	if type(def.trigger) ~= "table" then return end
	local event = tostring(def.trigger.event or "")
	if event == "" then return end
	local armSeconds = tonumber(def.cfg and def.cfg.armSeconds) or 0
	if armSeconds <= 0 then return end
	now = tonumber(now) or HS.engine.now()
	C._predictedArmedUntil = C._predictedArmedUntil or {}
	C._predictedArmedUntil[tostring(def.id or "")] = now + armSeconds
end

local function clearPredictedArmed(abilityId)
	abilityId = tostring(abilityId or "")
	if abilityId == "" then return end
	if type(C._predictedArmedUntil) == "table" then
		C._predictedArmedUntil[abilityId] = nil
	end
end

local function mimicAbilityId()
	return (HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop"
end

local function mimicToastKey(reason)
	if HS.contracts and HS.contracts.abilityErrors and HS.contracts.abilityErrors.mimicToastKey then
		return HS.contracts.abilityErrors.mimicToastKey(reason)
	end
	return "hs.toast.mimicUnavailable"
end

local function ensureMimicSelection()
	C._mimicSelection = C._mimicSelection or {
		active = false,
		hoverBodyId = 0,
		bodyId = 0,
		valid = false,
		reason = "no_pick",
		keyName = "",
		lastInvalidToastAt = -999,
	}
	return C._mimicSelection
end

local function clearMimicSelection()
	local s = ensureMimicSelection()
	s.active = false
	s.hoverBodyId = 0
	s.bodyId = 0
	s.valid = false
	s.reason = "no_pick"
	s.keyName = ""
end

local function isLocalMimicActive(vm, now)
	if not vm or not vm.me or not vm.abilities then
		return false
	end
	if vm.me.team ~= HS.const.TEAM_HIDERS or vm.me.out == true then
		return false
	end
	local ab = vm.abilities[mimicAbilityId()]
	local untilAt = tonumber(ab and ab.armedUntil) or 0
	return untilAt > (tonumber(now) or HS.engine.now())
end

local function updateMimicCamera(vm, now)
	C._mimicCamera = C._mimicCamera or {
		active = false,
		prevThirdPersonKnown = false,
		prevThirdPerson = false,
	}
	local cam = C._mimicCamera
	local active = isLocalMimicActive(vm, now)

	if active then
		if cam.active ~= true and type(GetBool) == "function" then
			local ok, v = pcall(GetBool, "game.thirdperson")
			cam.prevThirdPersonKnown = ok
			cam.prevThirdPerson = ok and v == true
		end
		if type(RequestThirdPerson) == "function" then
			pcall(RequestThirdPerson, true)
		end
		if type(SetPlayerCameraOffsetTransform) == "function" then
			local off = Transform(Vec(0, 1.0, 3.4), Quat())
			local ok = pcall(SetPlayerCameraOffsetTransform, off, true)
			if not ok then
				pcall(SetPlayerCameraOffsetTransform, off)
			end
		end
	elseif cam.active == true then
		if type(RequestThirdPerson) == "function" then
			local desired = cam.prevThirdPersonKnown and cam.prevThirdPerson == true
			pcall(RequestThirdPerson, desired)
		end
		if type(SetPlayerCameraOffsetTransform) == "function" then
			local reset = Transform(Vec(0, 0, 0), Quat())
			local ok = pcall(SetPlayerCameraOffsetTransform, reset, false)
			if not ok then
				pcall(SetPlayerCameraOffsetTransform, reset)
			end
		end
	end

	cam.active = active
end

local function showToastKey(key, seconds)
	if not (HS.cli and HS.cli.toast and HS.cli.toast.show) then
		return
	end
	HS.cli.toast.show({ key = tostring(key or "") }, tonumber(seconds) or 1.2)
end

local function pickMimicBody(localPlayerId)
	local pid = tonumber(localPlayerId) or 0
	if pid <= 0 then
		return 0
	end
	local body = 0
	if type(GetPlayerPickBody) == "function" then
		local ok, v = pcall(GetPlayerPickBody, pid)
		body = ok and (tonumber(v) or 0) or 0
	end
	if body > 0 then
		return body
	end
	if type(GetPlayerPickShape) == "function" and type(GetShapeBody) == "function" then
		local okS, sid = pcall(GetPlayerPickShape, pid)
		sid = okS and (tonumber(sid) or 0) or 0
		if sid > 0 then
			local okB, bid = pcall(GetShapeBody, sid)
			bid = okB and (tonumber(bid) or 0) or 0
			if bid > 0 then
				return bid
			end
		end
	end
	return 0
end

local function validateMimicBody(bodyId, playerId)
	bodyId = tonumber(bodyId) or 0
	playerId = tonumber(playerId) or 0
	if bodyId <= 0 then
		return false, "no_pick"
	end
	if HS.infra and HS.infra.mimic and HS.infra.mimic.validateBody then
		local ok, data = HS.infra.mimic.validateBody(nil, playerId, bodyId)
		if ok == true then
			return true, ""
		end
		return false, tostring(data and data.reason or "invalid")
	end
	return true, ""
end

local function drawMimicHighlight(bodyId, valid)
	bodyId = tonumber(bodyId) or 0
	if bodyId <= 0 then return end

	local r, g, b = 1.0, 0.34, 0.34
	if valid == true then
		r, g, b = 0.32, 1.0, 0.42
	end

	if type(DrawBodyOutline) == "function" then
		pcall(DrawBodyOutline, bodyId, r, g, b, 1.0)
		return
	end

	if type(GetBodyShapes) == "function" and type(DrawShapeOutline) == "function" then
		local ok, shapes = pcall(GetBodyShapes, bodyId)
		if ok and type(shapes) == "table" then
			for i = 1, #shapes do
				pcall(DrawShapeOutline, tonumber(shapes[i]) or 0, r, g, b, 1.0)
			end
		end
	end
end

local function handleMimicAbilityInput(vm, def, cd, armed, now)
	local sel = ensureMimicSelection()
	local keyName = abilityInputKey(def)

	if keyName ~= "" and HS.input and HS.input.keyPressed and HS.input.keyPressed(keyName) then
		beginPressAnim(def.id, now)
		if not sel.active then
			if cd <= 0 and not armed then
				sel.active = true
				sel.keyName = keyName
			end
			return true
		end

		if sel.valid and sel.bodyId > 0 then
			if HS.app and HS.app.commands and HS.app.commands.ability then
				if HS.app.commands.ability(def.id, "use", vm.me.id, nil, {
					mimicBodyId = sel.bodyId,
					mimicReason = "",
				}) then
					clearMimicSelection()
				end
			end
		else
			local t = tonumber(now) or HS.engine.now()
			if (t - (tonumber(sel.lastInvalidToastAt) or -999)) > 0.35 then
				sel.lastInvalidToastAt = t
				showToastKey(mimicToastKey(sel.reason), 1.25)
			end
			clearMimicSelection()
		end
		return true
	end

	if not sel.active then
		return false
	end

	local bodyId = pickMimicBody(vm and vm.me and vm.me.id)
	local valid, reason = validateMimicBody(bodyId, vm and vm.me and vm.me.id)
	sel.hoverBodyId = bodyId
	sel.bodyId = valid and bodyId or 0
	sel.valid = valid == true
	sel.reason = valid and "" or tostring(reason or "invalid")

	return true
end

function C.init()
	C._vfxQueue = C._vfxQueue or {}
	C._emitters = C._emitters or {}
	C._emitterPool = C._emitterPool or {}
	C._pressAnims = C._pressAnims or {}
	C._predictedArmedUntil = C._predictedArmedUntil or {}
	C._mimicCamera = { active = false, prevThirdPersonKnown = false, prevThirdPerson = false }
	ensureMimicSelection()
end

function C.enqueueVfx(abilityId, pos, dir, pos2, sourcePlayerId)
	C._vfxQueue = C._vfxQueue or {}
	local q = C._vfxQueue
	if #q > 14 then
		table.remove(q, 1)
	end
	q[#q + 1] = { id = tostring(abilityId or ""), pos = pos, dir = dir, pos2 = pos2, pid = tonumber(sourcePlayerId) or 0 }
end

local function addEmitter(em)
	if type(em) ~= "table" then return end
	C._emitters = C._emitters or {}
	C._emitters[#C._emitters + 1] = em
end

local function allocEmitter()
	C._emitterPool = C._emitterPool or {}
	local pool = C._emitterPool
	local em = pool[#pool]
	if em then
		pool[#pool] = nil
		return em
	end
	return {}
end

local function releaseEmitter(em)
	if type(em) ~= "table" then return end
	clearTable(em)
	C._emitterPool = C._emitterPool or {}
	C._emitterPool[#C._emitterPool + 1] = em
end

local function tickEmitters(dt, ctx)
	local list = C._emitters
	if not list or #list == 0 then return end

	local now = tonumber((ctx and ctx.now) or HS.engine.now()) or 0
	dt = tonumber(dt) or 0

	for i = #list, 1, -1 do
		local em = list[i]
		local id = tostring(em and em.id or "")
		local untilT = tonumber(em and em.untilAt) or 0
		if id == "" or untilT <= 0 or now >= untilT then
			releaseEmitter(em)
			table.remove(list, i)
		else
			local impl = C.impl[id]
			local fn = impl and impl.tickFx
			if type(fn) == "function" then
				local ok = pcall(fn, em, dt, now, C.fx, ctx)
				if not ok then
					releaseEmitter(em)
					table.remove(list, i)
				end
			end
		end
	end
end

local function flushVfxQueue()
	local q = C._vfxQueue
	if not q or #q == 0 then return end

	for i = 1, #q do
		local it = q[i]
		local id = tostring(it and it.id or "")
		local pos = it and it.pos
		if id ~= "" and type(pos) == "table" then
			local impl = C.impl[id]
			if impl then
				local inRange = true
				local okRange, res = pcall(C.fx.vfxInRange, pos)
				if okRange then
					inRange = res == true
				end
				if inRange then
					local fn = impl.vfx
					if type(fn) == "function" then
						pcall(fn, it, C.fx)
					end

					local startFx = impl.startFx
					if type(startFx) == "function" then
						local okStart, em = pcall(startFx, it, C.fx, allocEmitter)
						if okStart and type(em) == "table" then
							addEmitter(em)
						end
					end
				end
			end
		end
		q[i] = nil
	end
end

function C.tick(_dt, _ctx, vm)
	flushVfxQueue()
	tickEmitters(_dt, _ctx)
	local now = tonumber(vm and vm.now) or HS.engine.now()
	updateMimicCamera(vm, now)

	if not vm or not vm.ready then
		clearMimicSelection()
		return
	end
	if not isActivePhase(vm.phase) then
		clearMimicSelection()
		return
	end
	if not isLocalHider(vm) then
		clearMimicSelection()
		return
	end
	if not hiderAbilitiesEnabled(vm) then
		clearMimicSelection()
		return
	end

	local mimicId = mimicAbilityId()

	for _, def in ipairs(HS.abilities.list()) do
		local st = abilityVm(vm, def) or {}
		local readyAt = tonumber(st.readyAt) or 0
		local serverArmedUntil = tonumber(st.armedUntil) or 0
		local predictedArmedUntil = getPredictedArmedUntil(def.id, now)
		local armedUntil = math.max(serverArmedUntil, predictedArmedUntil)
		local cd = HS.abilities.cooldownLeft(now, readyAt)
		local armed = HS.abilities.isArmed(now, armedUntil)
		local keyName = abilityInputKey(def)
		local sentUseThisTick = false

		local handledByMimic = false
		if tostring(def and def.id or "") == mimicId then
			handledByMimic = handleMimicAbilityInput(vm, def, cd, armed, now)
		end

		if handledByMimic ~= true then
			if keyName ~= "" and HS.input and HS.input.keyPressed and HS.input.keyPressed(keyName) then
				beginPressAnim(def.id, now)
				if cd <= 0 and not armed then
					if HS.app and HS.app.commands and HS.app.commands.ability then
						if HS.app.commands.ability(def.id, "use", vm.me.id) then
							setPredictedArmed(def, now)
							sentUseThisTick = true
						end
					end
				end
			end
		end

		if (armed or sentUseThisTick) and type(def.trigger) == "table" then
			local action = tostring(def.trigger.action or "")
			local event = tostring(def.trigger.event or "")
			if action ~= "" and event ~= "" then
				local pressed = false
				if HS.input and HS.input.pressed then
					pressed = HS.input.pressed(action)
				elseif HS.engine and HS.engine.inputPressed then
					pressed = HS.engine.inputPressed(action)
				end
				if pressed then
					if HS.app and HS.app.commands and HS.app.commands.ability then
						if HS.app.commands.ability(def.id, event, vm.me.id) then
							clearPredictedArmed(def.id)
						end
					end
				end
			end
		end
	end
end

local function drawAbilityIcon(path, size, alpha)
	path = tostring(path or "")
	if path == "" then return end

	C._resolvedIcons = C._resolvedIcons or {}
	local resolved = C._resolvedIcons[path]
	if resolved == nil then
		if type(UiHasImage) ~= "function" then
			resolved = path
			C._resolvedIcons[path] = resolved
		else
			local found = nil
			if HS.engine.uiHasImage(path) then
				found = path
			else
				local alt = ""
				if string.sub(path, -4) == ".jpg" then
					alt = string.sub(path, 1, -5) .. ".png"
				elseif string.sub(path, -4) == ".png" then
					alt = string.sub(path, 1, -5) .. ".jpg"
				end
				if alt ~= "" and HS.engine.uiHasImage(alt) then
					found = alt
				else
					local fallback = (HS.ui and HS.ui.icons and HS.ui.icons.tag) or "ui/hud/crosshair-hand.png"
					if HS.engine.uiHasImage(fallback) then
						found = fallback
					end
				end
			end
			if found == nil then
				return
			end
			resolved = found
			C._resolvedIcons[path] = resolved
		end
	end

	if resolved == false then return end

	local dim = (HS.ui.primitives and HS.ui.primitives.iconDim and HS.ui.primitives.iconDim(resolved)) or 1
	dim = math.max(1, tonumber(dim) or 1)

	UiPush()
	UiAlign("center middle")
	UiColor(1, 1, 1, alpha)
	UiScale(size / dim)
	UiImage(resolved)
	UiPop()
end

local function abilityKeyText(def, slot)
	local keyName = abilityInputKey(def, slot)
	if keyName == "" then return "" end
	local key = tostring(HS.input and HS.input.keys and HS.input.keys[keyName] or keyName)
	if key == "" then return "" end
	return string.upper(key)
end

local function slotAbilityMap(defs, slotCount)
	local out = {}
	local nextAuto = 1
	for i = 1, #defs do
		local def = defs[i]
		local slot = math.floor(tonumber(def and (def.slot or (def.ui and def.ui.slot))) or 0)
		if slot < 1 or slot > slotCount or out[slot] ~= nil then
			while nextAuto <= slotCount and out[nextAuto] ~= nil do
				nextAuto = nextAuto + 1
			end
			slot = nextAuto
		end
		if slot >= 1 and slot <= slotCount then
			out[slot] = def
		end
	end
	return out
end

local function drawSidebarKeycap(label, keySize, teamColor, alpha)
	label = tostring(label or "")
	if label == "" then return end
	local r = tonumber(teamColor and teamColor[1]) or 0.85
	local g = tonumber(teamColor and teamColor[2]) or 0.85
	local b = tonumber(teamColor and teamColor[3]) or 0.95
	local cr, cg, cb = C.fx.lightenColor({ r, g, b, 1 })

	UiPush()
	UiAlign("center middle")
	UiColor(0, 0, 0, 0.35 * alpha)
	UiRoundedRect(keySize, keySize, 4)
	UiColor(r, g, b, 0.50 * alpha)
	UiRoundedRectOutline(keySize, keySize, 4, 2)
	UiTextShadow(0, 0, 0, 0.75 * alpha, 2.0, 0.75)
	UiColor(cr, cg, cb, 0.95 * alpha)
	UiFont(FONT_BOLD, keySize >= 24 and FONT_SIZE_20 or FONT_SIZE_18)
	UiText(label)
	UiPop()
end

function C.draw(_ctx, vm)
	if not vm or not vm.ready then return end
	if not isActivePhase(vm.phase) then return end
	if not isLocalHider(vm) then return end
	if not hiderAbilitiesEnabled(vm) then return end

	local now = tonumber(vm.now) or HS.engine.now()
	local localTeam = tonumber(vm.me and vm.me.team) or 0
	local teamC = HS.engine.teamColor(localTeam)
	local tr = tonumber(teamC and teamC[1]) or 0.85
	local tg = tonumber(teamC and teamC[2]) or 0.85
	local tb = tonumber(teamC and teamC[3]) or 0.95

	local slotCount = SIDEBAR_SLOT_COUNT
	local margin = 24
	local size = 78
	local gap = 10
	local radius = 9
	local keySize = 26
	local keyProtrusion = keySize * 0.60

	UiPush()
	UiAlign("left top")
	local defs = HS.abilities.list()
	local bySlot = slotAbilityMap(defs, slotCount)
	local totalHeight = slotCount * size + (slotCount - 1) * gap
	local x = UiWidth() - margin - size
	local y = UiHeight() * 0.5 - totalHeight * 0.5
	local minX = margin + keyProtrusion
	x = math.max(minX, x)

	local minY = margin
	local maxY = UiHeight() - margin - totalHeight
	if maxY < minY then
		y = minY
	else
		y = clamp(y, minY, maxY)
	end
	UiTranslate(x, y)

	for slot = 1, slotCount do
		local def = bySlot[slot]
		local st = def and (abilityVm(vm, def) or {}) or nil
		local readyAt = tonumber(st and st.readyAt) or 0
		local serverArmedUntil = tonumber(st and st.armedUntil) or 0
		local predictedArmedUntil = def and getPredictedArmedUntil(def.id, now) or 0
		local armedUntil = math.max(serverArmedUntil, predictedArmedUntil)
		local cdLeft = def and HS.abilities.cooldownLeft(now, readyAt) or 0
		local cdTotal = clamp(def and def.cooldownSeconds or 1, 0.1, 999)
		local armed = def and HS.abilities.isArmed(now, armedUntil) or false
		local hasAbility = def ~= nil
		local pressAmount = hasAbility and pressAnimAmount(def.id, now) or 0

		local alpha = hasAbility and ((cdLeft > 0) and 0.78 or 1.0) or 0.72
		local keyText = abilityKeyText(def, slot)

		UiPush()
		UiAlign("left top")

		UiColor(0, 0, 0, 0.34 * alpha)
		UiRoundedRect(size, size, radius)
		UiColor(tr, tg, tb, (hasAbility and 0.18 or 0.10) * alpha)
		UiRoundedRect(size, size, radius)
		UiColor(tr, tg, tb, (hasAbility and 0.55 or 0.30) * alpha)
		UiRoundedRectOutline(size, size, radius, 3)

		if armed then
			UiColor(COLOR_YELLOW[1], COLOR_YELLOW[2], COLOR_YELLOW[3], 0.72)
			UiRoundedRectOutline(size, size, radius, 3)
		end

		if hasAbility then
			UiPush()
			UiTranslate(size * 0.5, size * (0.5 + 0.03 * pressAmount))
			drawAbilityIcon(def.icon, size * (0.52 - 0.08 * pressAmount), alpha * (1.0 - 0.06 * pressAmount))
			UiPop()

			if pressAmount > 0 then
				UiColor(0, 0, 0, 0.18 * pressAmount * alpha)
				UiRoundedRect(size, size, radius)
			end

			if cdLeft > 0 then
				local p = clamp(cdLeft / cdTotal, 0, 1)
				if p > 0 then
					local h = size * p
					UiPush()
					UiAlign("left top")
					UiTranslate(0, size - h)
					UiClipRect(size, h)
					UiColor(0, 0, 0, 0.52)
					UiTranslate(0, -(size - h))
					UiRoundedRect(size, size, radius)
					UiPop()
				end

				UiPush()
				UiTranslate(size * 0.5, size * 0.5)
				UiAlign("center middle")
				UiColor(1, 1, 1, 0.95)
				UiTextShadow(0, 0, 0, 0.75, 2.0, 0.75)
				UiFont(FONT_BOLD, FONT_SIZE_22)
				UiText(tostring(math.ceil(cdLeft)))
				UiPop()
			end
		end

		UiPush()
		UiTranslate(-keyProtrusion, size * 0.5)
		drawSidebarKeycap(keyText, keySize, teamC, hasAbility and 1.0 or 0.55)
		UiPop()

		UiPop()
		UiTranslate(0, size + gap)
	end

	UiPop()

	local sel = C._mimicSelection
	if type(sel) == "table" and sel.active == true then
		local hoverBodyId = tonumber(sel.hoverBodyId) or 0
		if hoverBodyId > 0 then
			drawMimicHighlight(hoverBodyId, sel.valid == true)
		end

		local keyName = tostring(sel.keyName or "abilitySlot3")
		local keyLabel = tostring(HS.input and HS.input.keys and HS.input.keys[keyName] or keyName)
		keyLabel = string.upper(keyLabel)
		local line1 = HS.t("hs.ui.mimic.active")
		local line2 = (sel.valid == true) and HS.t("hs.ui.mimic.confirm", { key = keyLabel }) or HS.t(mimicToastKey(sel.reason))
		local line3 = HS.t("hs.ui.mimic.cancel", { key = keyLabel })

		UiPush()
		UiAlign("center top")
		UiTranslate(UiCenter(), math.floor(UiHeight() * 0.18))
		UiColor(0, 0, 0, 0.60)
		UiRoundedRect(560, 88, 10)
		UiColor(1, 1, 1, 0.14)
		UiRoundedRectOutline(560, 88, 10, 2)

		UiPush()
		UiAlign("center top")
		UiTranslate(0, 10)
		UiTextShadow(0, 0, 0, 0.75, 2.0, 0.75)
		UiColor(1, 1, 1, 1.0)
		UiFont(FONT_BOLD, FONT_SIZE_22)
		UiText(line1)
		UiTranslate(0, 24)
		if sel.valid == true then
			UiColor(0.56, 0.98, 0.63, 1.0)
		else
			UiColor(1.0, 0.58, 0.58, 1.0)
		end
		UiFont("regular.ttf", FONT_SIZE_20)
		UiText(line2)
		UiTranslate(0, 22)
		UiColor(0.84, 0.84, 0.84, 1.0)
		UiFont("regular.ttf", FONT_SIZE_18)
		UiText(line3)
		UiPop()
		UiPop()
	end
end

#include "abilities/dash.lua"
#include "abilities/superjump.lua"
#include "abilities/mimic_prop.lua"
