HS = HS or {}
HS.ui = HS.ui or {}
HS.ui.primitives = HS.ui.primitives or {}
HS.ui.icons = HS.ui.icons or {
	tag = "ui/hud/crosshair-hand.png",
	kill = "ui/hud/crosshair-gun.png",
}

local P = HS.ui.primitives

local function clamp(v, a, b)
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

function P.clearArray(t)
	for i = #t, 1, -1 do
		t[i] = nil
	end
end

function P.fadeAlpha(t, dur, fadeIn, fadeOut)
	t = tonumber(t) or 0
	dur = tonumber(dur) or 0
	fadeIn = tonumber(fadeIn) or 0
	fadeOut = tonumber(fadeOut) or 0

	if fadeIn > 0 and t < fadeIn then
		return HS.util.clamp(t / fadeIn, 0, 1)
	end
	if fadeOut > 0 and (dur - t) < fadeOut then
		return HS.util.clamp((dur - t) / fadeOut, 0, 1)
	end
	return 1.0
end

function P.glassPill(width, height, radius, alpha)
	local a = HS.util.clamp(tonumber(alpha) or 1, 0, 1)
	local theme = HS.ui and HS.ui.theme or nil
	local blur = (theme and theme.alpha and theme.alpha.glassBlur) or 0.45
	local fill = (theme and theme.alpha and theme.alpha.glassFill) or 0.20
	local shade = (theme and theme.alpha and theme.alpha.glassShade) or 0.55
	local outline = (theme and theme.alpha and theme.alpha.glassOutline) or 0.08

	UiPush()
	UiColor(1, 1, 1, fill * a)
	UiBackgroundBlur(blur)
	UiRoundedRect(width, height, radius)
	UiPop()

	UiPush()
	UiColor(0, 0, 0, shade * a)
	UiRoundedRect(width, height, radius)
	UiPop()

	UiPush()
	UiColor(1, 1, 1, outline * a)
	UiRoundedRectOutline(width, height, radius, 2)
	UiPop()
end

function P.iconDim(path)
	P._iconDims = P._iconDims or {}
	local d = P._iconDims[path]
	if d then return d end
	local w, h = HS.engine.uiGetImageSize(path)
	d = math.max(0, math.max(w or 0, h or 0))
	if d <= 1 then
		d = 256
	end
	P._iconDims[path] = d
	return d
end

function P.iconBadge(path, size, alpha)
	size = tonumber(size) or 18
	alpha = clamp(alpha or 1, 0, 1)
	if type(UiHasImage) == "function" and not HS.engine.uiHasImage(path) then
		return false
	end

	local dim = P.iconDim(path)

	UiPush()
	UiAlign("center middle")

	UiPush()
	UiColor(0, 0, 0, 0.32 * alpha)
	UiRoundedRect(size + 10, size + 10, (size + 10) / 2)
	UiPop()

	UiColor(1, 1, 1, 0.85 * alpha)
	UiScale(size / dim)
	UiImage(path)

	UiPop()
	return true
end
