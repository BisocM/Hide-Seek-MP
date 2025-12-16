HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.toast = HS.cli.toast or {}

local DEFAULT_DURATION = 0.8
local MAX_QUEUE = 6
local DUPLICATE_COOLDOWN = 0.55

local function clamp(v, a, b)
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

local function resolveMessage(message, params)
	if type(message) == "table" then
		if message.key ~= nil then
			return HS.t(tostring(message.key), message.params or params)
		end
		if message.text ~= nil then
			return tostring(message.text)
		end
		return tostring(message)
	end
	if type(message) == "string" and string.sub(message, 1, 3) == "hs." then
		return HS.t(message, params)
	end
	return tostring(message)
end

function HS.cli.toast.init()
	HS.cli.toast._queue = HS.cli.toast._queue or {}
	HS.cli.toast._current = HS.cli.toast._current or nil
	HS.cli.toast._lastTextAt = HS.cli.toast._lastTextAt or {}
end

function HS.cli.toast.show(message, seconds)
	if message == nil then return end
	local text = resolveMessage(message)
	if text == "" then return end

	local now = HS.util.now()
	local last = HS.cli.toast._lastTextAt[text] or -999
	if (now - last) < DUPLICATE_COOLDOWN then
		return
	end
	HS.cli.toast._lastTextAt[text] = now

	local dur = clamp(seconds or DEFAULT_DURATION, 0.25, 6.0)
	HS.cli.toast._queue[#HS.cli.toast._queue + 1] = { text = text, t = 0.0, dur = dur }
	if #HS.cli.toast._queue > MAX_QUEUE then
		table.remove(HS.cli.toast._queue, 1)
	end
end

function HS.cli.toast.tick(dt)
	if not HS.cli.toast._current then
		if HS.cli.toast._queue and #HS.cli.toast._queue > 0 then
			HS.cli.toast._current = table.remove(HS.cli.toast._queue, 1)
		else
			return
		end
	end

	local cur = HS.cli.toast._current
	cur.t = (cur.t or 0) + dt
	if cur.t >= (cur.dur or DEFAULT_DURATION) then
		HS.cli.toast._current = nil
	end
end

function HS.cli.toast.draw()
	local cur = HS.cli.toast._current
	if not cur then return end

	local t = cur.t or 0
	local dur = cur.dur or DEFAULT_DURATION

	local fadeIn = 0.12
	local fadeOut = 0.18
	local alpha = (HS.ui.primitives and HS.ui.primitives.fadeAlpha and HS.ui.primitives.fadeAlpha(t, dur, fadeIn, fadeOut)) or 1.0

	local scale = 1.0
	if t < fadeIn then
		local p = clamp(t / fadeIn, 0, 1)
		scale = 0.96 + 0.04 * (p * p)
	end

	local text = cur.text or ""

	local margin = 40
	local maxW = math.max(220, UiWidth() - margin * 2)
	maxW = math.min(maxW, 720)

	UiPush()
	UiAlign("center bottom")
	UiTranslate(UiCenter(), UiHeight() - 110)
	UiScale(scale)

	UiFont("regular.ttf", FONT_SIZE_20)
	local tw, _th = UiGetTextSize(text)
	local w = math.min(maxW, tw + 48)
	local h = 46

	if HS.ui.primitives and HS.ui.primitives.glassPill then
		HS.ui.primitives.glassPill(w, h, 16, alpha)
	else
		uiDrawPanel(w, h, 16)
	end

	local _fits, display = uiTextConstrained(text, "regular.ttf", FONT_SIZE_20, w - 34, 1)

	UiPush()
	UiAlign("center middle")
	UiTranslate(0, -h / 2)
	UiColor(1, 1, 1, 0.92 * alpha)
	UiTextShadow(0, 0, 0, 0.65 * alpha, 2.0, 0.75)
	UiFont("regular.ttf", FONT_SIZE_20)
	UiText(display)
	UiPop()

	UiPop()
end

function client.hs_toast(message, seconds)
	if HS.cli.toast and HS.cli.toast.show then
		HS.cli.toast.show(message, seconds)
	end
end
