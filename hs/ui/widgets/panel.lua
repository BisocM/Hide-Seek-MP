HS = HS or {}
HS.ui = HS.ui or {}
HS.ui.widgets = HS.ui.widgets or {}
HS.ui.widgets.panel = HS.ui.widgets.panel or {}

local W = HS.ui.widgets.panel

function W.draw(width, height, radius)
	if HS.ui and HS.ui.primitives and HS.ui.primitives.glassPill and radius and radius >= (height or 0) * 0.49 then
		HS.ui.primitives.glassPill(width, height, radius, 1.0)
	else
		uiDrawPanel(width, height, radius)
	end
end
