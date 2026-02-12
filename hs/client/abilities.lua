HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.abilities = HS.cli.abilities or {}

local C = HS.cli.abilities

C.impl = C.impl or {}
C.fx = C.fx or {}

local function clamp(v, a, b)
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

function C.init()
	C._vfxQueue = C._vfxQueue or {}
	C._emitters = C._emitters or {}
	C._emitterPool = C._emitterPool or {}
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

	if not vm or not vm.ready then return end
	if not isActivePhase(vm.phase) then return end
	if not isLocalHider(vm) then return end
	if not hiderAbilitiesEnabled(vm) then return end

	local now = tonumber(vm.now) or HS.engine.now()

	for _, def in ipairs(HS.abilities.list()) do
		local st = abilityVm(vm, def) or {}
		local readyAt = tonumber(st.readyAt) or 0
		local armedUntil = tonumber(st.armedUntil) or 0
		local cd = HS.abilities.cooldownLeft(now, readyAt)
		local armed = HS.abilities.isArmed(now, armedUntil)

		if HS.input and HS.input.keyPressed and HS.input.keyPressed(def.key) then
			if cd <= 0 and not armed then
				local rpc = HS.engine and HS.engine.serverRpc
				if rpc and rpc.ability then
					rpc.ability(vm.me.id, def.id, "use")
				end
			end
		end

		if armed and type(def.trigger) == "table" then
			local action = tostring(def.trigger.action or "")
			local event = tostring(def.trigger.event or "")
			if action ~= "" and event ~= "" then
				if HS.engine and HS.engine.inputPressed and HS.engine.inputPressed(action) then
					local rpc = HS.engine and HS.engine.serverRpc
					if rpc and rpc.ability then
						rpc.ability(vm.me.id, def.id, event)
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

local function drawKeycap(keyText, alpha)
	keyText = tostring(keyText or "")
	if keyText == "" then return end

	UiPush()
	UiAlign("center middle")
	UiColor(0, 0, 0, 0.40 * alpha)
	UiRoundedRect(24, 18, 6)
	UiColor(1, 1, 1, 0.14 * alpha)
	UiRoundedRectOutline(24, 18, 6, 2)
	UiTextShadow(0, 0, 0, 0.75 * alpha, 2.0, 0.75)
	UiColor(1, 1, 1, 0.92 * alpha)
	UiFont(FONT_BOLD, FONT_SIZE_18)
	UiText(keyText)
	UiPop()
end

function C.draw(_ctx, vm)
	if not vm or not vm.ready then return end
	if not isActivePhase(vm.phase) then return end
	if not isLocalHider(vm) then return end
	if not hiderAbilitiesEnabled(vm) then return end

	local now = tonumber(vm.now) or HS.engine.now()

	local margin = 26
	local size = 192
	local gap = 18
	local radius = 24

	UiPush()
	UiAlign("left top")
	local defs = HS.abilities.list()
	local count = #defs
	local totalHeight = (count > 0) and (count * size + (count - 1) * gap) or 0
	local x = UiWidth() - margin - size
	local y = UiHeight() * 0.5 - totalHeight * 0.5
	x = math.max(margin, x)
	if totalHeight > 0 then
		local minY = margin
		local maxY = UiHeight() - margin - totalHeight
		if maxY < minY then
			y = minY
		else
			y = clamp(y, minY, maxY)
		end
	end
	UiTranslate(x, y)

	for _, def in ipairs(defs) do
		local st = abilityVm(vm, def) or {}
		local readyAt = tonumber(st.readyAt) or 0
		local armedUntil = tonumber(st.armedUntil) or 0

		local cdLeft = HS.abilities.cooldownLeft(now, readyAt)
		local cdTotal = clamp(def.cooldownSeconds or 1, 0.1, 999)
		local armed = HS.abilities.isArmed(now, armedUntil)

		local alpha = (cdLeft > 0) and 0.72 or 1.0

		UiPush()
		UiAlign("left top")
		if HS.ui.primitives and HS.ui.primitives.glassPill then
			HS.ui.primitives.glassPill(size, size, radius, 0.95)
		else
			uiDrawPanel(size, size, radius)
		end

		if armed then
			UiColor(COLOR_YELLOW[1], COLOR_YELLOW[2], COLOR_YELLOW[3], 0.55)
			UiRoundedRectOutline(size, size, radius, 3)
		end

		UiPush()
		UiTranslate(size * 0.5, size * 0.5)
		drawAbilityIcon(def.icon, size * 0.88, alpha)
		UiPop()

			if cdLeft > 0 then
				local p = clamp(cdLeft / cdTotal, 0, 1)
				if p > 0 then
					local h = size * p
					UiPush()
					UiAlign("left top")
					UiTranslate(0, size - h)
					UiClipRect(size, h)
					UiColor(0, 0, 0, 0.48)
					UiTranslate(0, -(size - h))
					UiRoundedRect(size, size, radius)
					UiPop()
				end

				UiPush()
			UiTranslate(size * 0.5, size * 0.5)
			UiAlign("center middle")
			UiColor(1, 1, 1, 0.92)
			UiTextShadow(0, 0, 0, 0.75, 2.0, 0.75)
			UiFont(FONT_BOLD, FONT_SIZE_22)
			UiText(tostring(math.ceil(cdLeft)))
			UiPop()
		end

		UiPush()
		UiTranslate(size - 20, size - 17)
		local keyText = tostring(HS.input and HS.input.keys and HS.input.keys[def.key] or "")
		keyText = string.upper(keyText)
		drawKeycap(keyText, 0.95)
		UiPop()

		UiPop()
		UiTranslate(0, size + gap)
	end

	UiPop()
end

function client.hs_abilityVfx(abilityId, x, y, z, dx, dy, dz, x2, y2, z2, sourcePlayerId)
	if not HS.cli.abilities or not HS.cli.abilities.enqueueVfx then return end
	local pos = Vec(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
	local dir = Vec(tonumber(dx) or 0, tonumber(dy) or 0, tonumber(dz) or 0)
	local pos2v = Vec(tonumber(x2) or 0, tonumber(y2) or 0, tonumber(z2) or 0)
	HS.cli.abilities.enqueueVfx(tostring(abilityId or ""), pos, dir, pos2v, sourcePlayerId)
end

#include "abilities/dash.lua"
#include "abilities/superjump.lua"
