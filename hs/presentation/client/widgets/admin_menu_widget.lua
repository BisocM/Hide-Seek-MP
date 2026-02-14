HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.admin_menu = HS.cli.admin_menu or {}

local A = HS.cli.admin_menu

A._state = A._state or {
	open = false,
	scroll = 0, -- negative numbers scroll down (UiTranslate(0, scroll))
	lastContentHeight = 0,
	edit = nil,
	nameCache = {},
	dirty = false,
	lastChangeAt = 0,
	lastPushAt = 0,
	pushDelay = 0.25,
}

local function isFn(f) return type(f) == "function" end

local function clamp(x, a, b)
	if HS.util and HS.util.math and HS.util.math.clamp then
		return HS.util.math.clamp(x, a, b)
	end
	if x < a then return a end
	if x > b then return b end
	return x
end

local function hsT(key, params)
	if HS and HS.t then
		return HS.t(key, params)
	end
	return tostring(key)
end

local function safeHasKey(key)
	if not isFn(HasKey) then return false end
	local ok, v = pcall(HasKey, key)
	return ok and v == true
end

local function safeGetString(key, default)
	if not isFn(GetString) then return default end
	local ok, v = pcall(GetString, key)
	if ok and v ~= nil then
		local s = tostring(v)
		if s ~= "" then return s end
	end
	return default
end

local function toolDisplayName(toolId)
	toolId = tostring(toolId or "")
	if toolId == "" then return "?" end
	if A._state.nameCache and A._state.nameCache[toolId] then
		return A._state.nameCache[toolId]
	end
	local k = "game.tool." .. toolId .. ".name"
	if safeHasKey(k) then
		local v = safeGetString(k, toolId)
		if A._state.nameCache then
			A._state.nameCache[toolId] = v
		end
		return v
	end
	if A._state.nameCache then
		A._state.nameCache[toolId] = toolId
	end
	return toolId
end

local function ensureEditState(vm)
	local base = (vm and vm.settings and vm.settings.loadout) or nil
	local lo = (HS.loadout and HS.loadout.normalize and HS.loadout.normalize(base or {})) or { enabled = false, tools = {}, assign = {} }

	-- If server has no tool list yet, prefer host's persisted config (including discovery).
	if type(lo.tools) ~= "table" or #lo.tools == 0 then
		if HS.loadout and HS.loadout.readPersist then
			local persisted = HS.loadout.readPersist(HS.persist, { discoverIfMissing = true })
			if persisted and type(persisted.tools) == "table" and #persisted.tools > 0 then
				lo.enabled = persisted.enabled == true
				lo.tools = persisted.tools
				lo.assign = persisted.assign
			end
		end
	end

	-- Final fallback: discover locally so the UI has something to render.
	if type(lo.tools) ~= "table" or #lo.tools == 0 then
		if HS.loadout and HS.loadout.discoverTools then
			lo.tools = HS.loadout.discoverTools()
		else
			lo.tools = {}
		end
	end

	lo = (HS.loadout and HS.loadout.normalize and HS.loadout.normalize(lo)) or lo
	A._state.edit = lo
	A._state.scroll = 0
	A._state.lastContentHeight = 0
	A._state.nameCache = {}
	A._state.dirty = false
	A._state.lastChangeAt = 0
end

local function markDirty()
	A._state.dirty = true
	A._state.lastChangeAt = (HS.util and HS.util.now and HS.util.now()) or 0
end

local function pushToServer(vm)
	if not vm or not vm.me or vm.me.isHost ~= true then return end
	if not (HS.loadout and HS.loadout.normalize) then return end
	if not (HS.engine and HS.engine.serverCall) then return end

	local lo = HS.loadout.normalize(A._state.edit or {})
	A._state.edit = lo

	if HS.app and HS.app.commands and HS.app.commands.updateLoadout then
		HS.app.commands.updateLoadout(lo, vm.me.id)
	end
	if HS.loadout and HS.loadout.writePersist then
		HS.loadout.writePersist(HS.persist, lo)
	end

	A._state.dirty = false
	A._state.lastPushAt = (HS.util and HS.util.now and HS.util.now()) or 0
end

local function assignmentOptions()
	return {
		{ label = hsT("hs.common.off"), value = HS.loadout and HS.loadout.ASSIGN_OFF or 0 },
		{ label = hsT("hs.team.seekers"), value = HS.loadout and HS.loadout.ASSIGN_SEEKERS or 1 },
		{ label = hsT("hs.team.hiders"), value = HS.loadout and HS.loadout.ASSIGN_HIDERS or 2 },
		{ label = hsT("hs.ui.loadout.both"), value = HS.loadout and HS.loadout.ASSIGN_BOTH or 3 },
	}
end

local function findOptionIndex(options, value)
	value = tonumber(value) or 0
	for i = 1, #options do
		if tonumber(options[i].value) == value then
			return i
		end
	end
	return 1
end

local function drawInlineStepper(id, options, width, currentValue, focused)
	options = options or {}
	if #options == 0 then return currentValue end

	local h = 24
	local leftArrow = "ui/common/stepper_l_btn_white.png"
	local rightArrow = "ui/common/stepper_r_btn_white.png"
	local arrowW, _arrowH = UiGetImageSize(leftArrow)
	if arrowW <= 0 then arrowW = 24 end

	local idx = findOptionIndex(options, currentValue)
	local isCyclic = true

	UiPush()
	local isInFocus = UiIsMouseInRect(width, h)
	local inFocus = focused == true or isInFocus

	UiPush()
	if inFocus then
		UiColor(COLOR_YELLOW)
	else
		UiColor(COLOR_WHITE)
	end
	UiPop()

	UiPush()
	if inFocus then
		UiColor(COLOR_YELLOW)
	else
		UiColor(0.53, 0.53, 0.53, 1)
	end
	if UiImageButton(leftArrow) then
		UiSound("ui/common/click.ogg")
		idx = idx - 1
		if idx < 1 then
			idx = isCyclic and #options or 1
		end
	end
	UiPop()

	if isInFocus and InputPressed("menu_left") then
		UiSound("ui/common/click.ogg")
		idx = idx - 1
		if idx < 1 then
			idx = isCyclic and #options or 1
		end
	end

	UiPush()
	UiAlign("middle center")
	-- Center the label within the stepper height. (y=0 would clip the first row in UiWindow.)
	UiTranslate(width / 2, h / 2)
	if inFocus then
		UiColor(COLOR_YELLOW)
	else
		UiColor(COLOR_WHITE)
	end
	UiFont(FONT_MEDIUM, FONT_SIZE_22)
	UiText(options[idx].label or "?")
	UiPop()

	UiTranslate(width - arrowW, 0)
	UiPush()
	if inFocus then
		UiColor(COLOR_YELLOW)
	else
		UiColor(0.53, 0.53, 0.53, 1)
	end
	if UiImageButton(rightArrow) then
		UiSound("ui/common/click.ogg")
		idx = idx + 1
		if idx > #options then
			idx = isCyclic and 1 or #options
		end
	end
	UiPop()

	if isInFocus and InputPressed("menu_right") then
		UiSound("ui/common/click.ogg")
		idx = idx + 1
		if idx > #options then
			idx = isCyclic and 1 or #options
		end
	end

	UiPop()

	return options[idx].value
end

local function bulkSetAll(value)
	if not A._state.edit or type(A._state.edit.tools) ~= "table" then return end
	local v = tonumber(value) or 0
	v = (HS.loadout and HS.loadout.clampAssign and HS.loadout.clampAssign(v)) or v
	A._state.edit.assign = A._state.edit.assign or {}
	for i = 1, #A._state.edit.tools do
		local id = A._state.edit.tools[i]
		A._state.edit.assign[id] = v
	end
	markDirty()
end

local function refreshTools()
	if not (HS.loadout and HS.loadout.discoverTools) then return end
	if not A._state.edit then return end
	local discovered = HS.loadout.discoverTools()
	A._state.edit.tools = discovered
	A._state.edit = HS.loadout.normalize(A._state.edit)
	markDirty()
end

local function drawActionButtons(w, gap)
	local btns = {
		{
			label = hsT("hs.ui.adminMenu.refreshTools"),
			fn = refreshTools,
		},
		{
			label = hsT("hs.ui.adminMenu.disableAll"),
			fn = function() bulkSetAll(HS.loadout and HS.loadout.ASSIGN_OFF or 0) end,
		},
		{
			label = hsT("hs.ui.adminMenu.seekersOnly"),
			fn = function() bulkSetAll(HS.loadout and HS.loadout.ASSIGN_SEEKERS or 1) end,
		},
		{
			label = hsT("hs.ui.adminMenu.hidersOnly"),
			fn = function() bulkSetAll(HS.loadout and HS.loadout.ASSIGN_HIDERS or 2) end,
		},
		{
			label = hsT("hs.ui.adminMenu.both"),
			fn = function() bulkSetAll(HS.loadout and HS.loadout.ASSIGN_BOTH or 3) end,
		},
	}

	local baseW = 170
	local columns = 5
	if w < (baseW * columns + gap * (columns - 1)) then
		columns = 3
	end
	if w < (baseW * columns + gap * (columns - 1)) then
		columns = 2
	end
	local btnW = math.floor((w - gap * (columns - 1)) / columns)
	btnW = math.max(100, btnW)

	local x = 0
	local y = 0
	for i = 1, #btns do
		UiPush()
		-- Some upstream UI paths can leave a non-default alignment active. Buttons assume left/top.
		UiAlign("left top")
		UiTranslate(x, y)
		if uiDrawSecondaryButton(btns[i].label, btnW, false) then
			btns[i].fn()
		end
		UiPop()

		x = x + btnW + gap
		if x + btnW > w + 0.1 then
			x = 0
			y = y + 40 + gap
		end
	end

	return y + 40
end

function A.init()
	-- no-op; state is lazy-initialized on first open
end

function A.toggle(vm)
	if not vm or not vm.me or vm.me.isHost ~= true then return end
	A._state.open = not A._state.open
	if A._state.open then
		ensureEditState(vm)
	else
		if A._state.dirty then
			pushToServer(vm)
		end
	end
end

function A.tick(_dt, _ctx, vm)
	-- Host-only.
	if not vm or not vm.me or vm.me.isHost ~= true then
		if A._state.open then
			A._state.open = false
			A._state.edit = nil
			A._state.dirty = false
		end
		return
	end

	-- Toggle key.
	if HS.input and HS.input.keyPressed and HS.input.keyPressed("adminMenu") then
		A.toggle(vm)
	end

	-- Pause menu hook (host only).
	if isFn(PauseMenuButton) then
		if PauseMenuButton(hsT("hs.ui.adminMenu.pauseButton"), "bottom_bar", false) then
			A.toggle(vm)
		end
	end

	-- Debounced apply while open.
	if A._state.open and A._state.dirty then
		local now = (HS.util and HS.util.now and HS.util.now()) or 0
		if (now - (A._state.lastChangeAt or 0)) >= (A._state.pushDelay or 0.25) then
			pushToServer(vm)
		end
	end
end

function A.draw(_dt, _ctx, vm)
	if not A._state.open then return end
	if not vm or not vm.me or vm.me.isHost ~= true then return end
	if not A._state.edit then
		ensureEditState(vm)
	end

	local lo = A._state.edit
	local options = assignmentOptions()

	-- Scroll handling (negative scroll pos).
	local wheel = 0
	if isFn(InputValue) then
		local ok, v = pcall(InputValue, "mousewheel")
		if ok then wheel = tonumber(v) or 0 end
	end
	if wheel ~= 0 then
		local sensitivity = 50
		local newScroll = (A._state.scroll or 0) + wheel * sensitivity
		if newScroll > 0 then newScroll = 0 end
		local maxScroll = math.max(0, (A._state.lastContentHeight or 0))
		if newScroll < -maxScroll then newScroll = -maxScroll end
		A._state.scroll = newScroll
	end

	UiMakeInteractive()
	if LastInputDevice() == UI_DEVICE_GAMEPAD then
		UiSetCursorState(UI_CURSOR_HIDE_AND_LOCK)
	end

	-- Underlay
	UiPush()
	UiColor(0, 0, 0, 0.60)
	UiRect(UiWidth(), UiHeight())
	UiPop()

	local panelW = math.min(980, UiWidth() - 120)
	local panelH = math.min(UiHeight() - 120, 860)
	local x = UiCenter() - panelW / 2
	local y = UiMiddle() - panelH / 2

	UiPush()
	UiTranslate(x, y)
	uiDrawPanel(panelW, panelH, 16)

	local pad = 20
	UiTranslate(pad, pad)
	-- Ensure a stable baseline; other HUD code may leave UiAlign in a non-default state.
	UiAlign("left top")

	-- Header
	UiColor(COLOR_WHITE)
	UiFont(FONT_BOLD, FONT_SIZE_30)
	UiText(hsT("hs.ui.adminMenu.title"))

	UiPush()
	UiAlign("right top")
	UiTranslate(panelW - pad * 2, 0)
	if uiDrawSecondaryButton(hsT("hs.ui.adminMenu.close"), 140, false) then
		A.toggle(vm)
	end
	UiPop()

	UiTranslate(0, 44)
	UiColor(0.53, 0.53, 0.53, 1)
	UiRect(panelW - pad * 2, 2)
	UiTranslate(0, 14)

	-- Enabled toggle row (match button height to avoid overlap/clipping at smaller resolutions).
	local toggleRowH = 40
	local toggleGap = 12

	UiPush()
	UiAlign("left middle")
	UiTranslate(0, toggleRowH / 2)
	UiFont(FONT_MEDIUM, FONT_SIZE_22)
	UiColor(COLOR_WHITE)
	UiText(hsT("hs.ui.adminMenu.enforcement"))
	UiPop()

	UiPush()
	UiAlign("right top")
	UiTranslate(panelW - pad * 2, 0)
	local onOffLabel = (lo.enabled == true) and hsT("hs.common.on") or hsT("hs.common.off")
	if uiDrawSecondaryButton(onOffLabel, 140, false) then
		lo.enabled = not (lo.enabled == true)
		markDirty()
	end
	UiPop()

	UiTranslate(0, toggleRowH + toggleGap)

	-- Buttons row
	local gap = 10
	local buttonBlockH = drawActionButtons(panelW - pad * 2, gap)

	UiTranslate(0, buttonBlockH + 14)

	-- List header
	UiFont(FONT_BOLD, FONT_SIZE_22)
	UiColor(COLOR_WHITE)
	UiText(hsT("hs.ui.adminMenu.weaponsTitle"))
	UiTranslate(0, 20)
	UiColor(0.53, 0.53, 0.53, 1)
	UiRect(panelW - pad * 2, 2)
	UiTranslate(0, 10)

	local listW = panelW - pad * 2
	local listH = panelH - (pad * 2) - 44 - 14 - (toggleRowH + toggleGap) - (buttonBlockH + 14) - 22 - 20 - 2 - 10 - 64
	listH = math.max(120, listH)

	UiWindow(listW, listH, true)
	UiTranslate(0, A._state.scroll or 0)

	local rowH = 34
	local rowGap = 8
	local stepperW = math.min(242, math.max(180, math.floor(listW * 0.38)))
	local labelW = math.max(1, listW - stepperW - 14)

	local yCursor = 0
	local tools = (type(lo.tools) == "table") and lo.tools or {}
	lo.assign = lo.assign or {}
	for i = 1, #tools do
		local id = tools[i]
		local display = toolDisplayName(id)

		UiPush()
		UiTranslate(0, yCursor)

		local hovered = UiIsMouseInRect(listW, rowH)
		if hovered then
			UiColor(1, 1, 1, 0.10)
			UiRoundedRect(listW, rowH, 4)
		end

		UiPush()
		UiTranslate(8, 6)
		UiAlign("left top")
		UiColor(COLOR_WHITE)
		uiDrawTextEllipsis(display, FONT_MEDIUM, FONT_SIZE_22, labelW, 1)
		UiPop()

		UiPush()
		UiTranslate(listW - stepperW, 5)
		local cur = lo.assign[id]
		if cur == nil and HS.loadout and HS.loadout.defaultAssignFor then
			cur = HS.loadout.defaultAssignFor(id)
		end
		cur = HS.loadout and HS.loadout.clampAssign and HS.loadout.clampAssign(cur) or (tonumber(cur) or 0)
		local newV = drawInlineStepper(id, options, stepperW, cur, hovered)
		newV = HS.loadout and HS.loadout.clampAssign and HS.loadout.clampAssign(newV) or (tonumber(newV) or 0)
		if newV ~= cur then
			lo.assign[id] = newV
			markDirty()
		end
		UiPop()

		UiPop()

		yCursor = yCursor + rowH + rowGap
	end

	-- Update scroll clamp based on actual content height.
	A._state.lastContentHeight = math.max(0, yCursor - rowGap - listH)
	if (A._state.scroll or 0) > 0 then
		A._state.scroll = 0
	end
	if (A._state.scroll or 0) < -A._state.lastContentHeight then
		A._state.scroll = -A._state.lastContentHeight
	end

	UiPop()
end
