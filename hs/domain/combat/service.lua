HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.combat = HS.domain.combat or {}

local C = HS.domain.combat

function C.tagOnlyEnabled(state)
	return type(state) == "table" and type(state.settings) == "table" and state.settings.tagOnlyMode == true
end

function C.hidersCanKillSeekers(state)
	return type(state) == "table" and type(state.settings) == "table" and state.settings.allowHidersKillSeekers == true
end
