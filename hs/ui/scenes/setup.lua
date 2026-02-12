HS = HS or {}
HS.ui = HS.ui or {}
HS.ui.scenes = HS.ui.scenes or {}
HS.ui.scenes.setup = HS.ui.scenes.setup or {}

local S = HS.ui.scenes.setup

function S.draw(dt, ctx, vm)
	if not vm or vm.phase ~= HS.const.PHASE_SETUP then return false end
	if HS.cli and HS.cli.pregame and HS.cli.pregame.draw then
		HS.cli.pregame.draw(dt, ctx, vm)
	end
	return true
end
