HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.feed = HS.cli.feed or {}

local MAX_ITEMS = 6
local ITEM_TIME = 4.2
local FADE_OUT = 0.65
local FADE_IN = 0.14

local function clamp(v, a, b)
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

local function teamColor(teamId)
	return HS.engine.teamColor(teamId)
end

local function safePlayerName(playerId)
	return HS.engine.playerName(playerId)
end

local function isUsableName(name)
	name = tostring(name or "")
	if name == "" or name == "?" then return false end
	return string.upper(name) ~= "UNKNOWN"
end

local function iconForMethod(_method)
	local icons = HS.ui and HS.ui.icons or nil
	-- Keep a single "caught" visual language for both tags and kills.
	return (icons and icons.tag) or "ui/hud/crosshair-hand.png"
end

function HS.cli.feed.init()
	HS.cli.feed._items = HS.cli.feed._items or {}
end

function HS.cli.feed.push(attackerId, victimId, method, attackerName, victimName)
	local a = tonumber(attackerId) or 0
	local v = tonumber(victimId) or 0
	local aName = tostring(attackerName or "")
	local vName = tostring(victimName or "")
	if not isUsableName(aName) then
		aName = safePlayerName(a)
	end
	if not isUsableName(vName) then
		vName = safePlayerName(v)
	end

	local item = {
		attackerId = a,
		victimId = v,
		attackerName = aName,
		victimName = vName,
		method = tostring(method or "tag"),
		t = 0.0,
		dur = ITEM_TIME,
	}

	HS.cli.feed._items = HS.cli.feed._items or {}
	table.insert(HS.cli.feed._items, 1, item)
	while #HS.cli.feed._items > MAX_ITEMS do
		table.remove(HS.cli.feed._items, #HS.cli.feed._items)
	end
end

function HS.cli.feed.tick(dt)
	if not HS.cli.feed._items or #HS.cli.feed._items == 0 then return end
	for i = #HS.cli.feed._items, 1, -1 do
		local it = HS.cli.feed._items[i]
		it.t = (it.t or 0) + dt
		if it.t >= (it.dur or ITEM_TIME) then
			table.remove(HS.cli.feed._items, i)
		end
	end
end

function HS.cli.feed.draw()
	local items = HS.cli.feed._items
	if not items or #items == 0 then return end

	local margin = 24
	local top = 150

	local maxW = math.max(220, UiWidth() - margin * 2)
	local rowW = math.min(430, maxW)
	local rowH = 40
	local gapY = 10
	local padX = 14
	local iconSize = 18
	local gapX = 10

	local seekerC = teamColor(HS.const.TEAM_SEEKERS)
	local hiderC = teamColor(HS.const.TEAM_HIDERS)

	UiPush()
	UiAlign("right top")
	UiTranslate(UiWidth() - margin, top)

	for i = 1, #items do
		local it = items[i]
		local t = it.t or 0
		local dur = it.dur or ITEM_TIME

		local alpha = (HS.ui.primitives and HS.ui.primitives.fadeAlpha and HS.ui.primitives.fadeAlpha(t, dur, FADE_IN, FADE_OUT)) or 1.0

		local slide = 0.0
		if t < FADE_IN then
			local p = clamp(t / FADE_IN, 0, 1)
			slide = (1.0 - p) * 22
		end

		UiPush()
		UiTranslate(slide, 0)

		if HS.ui.primitives and HS.ui.primitives.glassPill then
			HS.ui.primitives.glassPill(rowW, rowH, 14, alpha)
		else
			uiDrawPanel(rowW, rowH, 14)
		end

		local avail = rowW - padX * 2 - iconSize - gapX * 2
		local nameW = math.max(60, math.floor(avail / 2))

		local attackerName = it.attackerName or "?"
		local victimName = it.victimName or "?"
		local resolvedAttacker = safePlayerName(it.attackerId)
		local resolvedVictim = safePlayerName(it.victimId)
		if isUsableName(resolvedAttacker) then
			attackerName = resolvedAttacker
			it.attackerName = resolvedAttacker
		end
		if isUsableName(resolvedVictim) then
			victimName = resolvedVictim
			it.victimName = resolvedVictim
		end
		local _f1, attackerText = uiTextConstrained(attackerName, FONT_BOLD, FONT_SIZE_20, nameW, 1)
		local _f2, victimText = uiTextConstrained(victimName, FONT_BOLD, FONT_SIZE_20, nameW, 1)

		local leftX = -rowW + padX
		local attackerX = leftX + nameW
		local iconX = attackerX + gapX + iconSize / 2
		local victimX = attackerX + gapX + iconSize + gapX

		UiTextShadow(0, 0, 0, 0.65 * alpha, 2.0, 0.75)

		UiPush()
		UiAlign("right middle")
		UiTranslate(attackerX, rowH / 2)
		UiFont(FONT_BOLD, FONT_SIZE_20)
		UiColor(seekerC[1], seekerC[2], seekerC[3], 1.0 * alpha)
		UiText(attackerText)
		UiPop()

		local icon = iconForMethod(it.method)
		UiPush()
		UiAlign("center middle")
		UiTranslate(iconX, rowH / 2)
		if HS.ui.primitives and HS.ui.primitives.iconBadge then
			HS.ui.primitives.iconBadge(icon, iconSize, alpha)
		end
		UiPop()

		UiPush()
		UiAlign("left middle")
		UiTranslate(victimX, rowH / 2)
		UiFont(FONT_BOLD, FONT_SIZE_20)
		UiColor(hiderC[1], hiderC[2], hiderC[3], 1.0 * alpha)
		UiText(victimText)
		UiPop()

		UiPop()

		UiTranslate(0, rowH + gapY)
	end

	UiPop()
end

function client.hs_feedCaught(attackerId, victimId, method, attackerName, victimName)
	if HS.cli.feed and HS.cli.feed.push then
		HS.cli.feed.push(attackerId, victimId, method, attackerName, victimName)
	end
end
