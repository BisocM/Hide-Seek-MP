HS = HS or {}
HS.ui = HS.ui or {}
HS.ui.viewmodels = HS.ui.viewmodels or {}
HS.ui.viewmodels.match = HS.ui.viewmodels.match or {}

local V = HS.ui.viewmodels.match

function V.build(ctx)
	local sh = HS.select and HS.select.shared and HS.select.shared() or nil
	if HS.select and HS.select.matchVm then
		return HS.select.matchVm(ctx, sh)
	end
	return nil
end
