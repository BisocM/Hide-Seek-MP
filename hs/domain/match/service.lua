HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.match = HS.domain.match or {}

local M = HS.domain.match

function M.phaseName(state)
	if type(state) ~= "table" then
		return (HS.const and HS.const.PHASE_SETUP) or "setup"
	end
	return tostring(state.phase or ((HS.const and HS.const.PHASE_SETUP) or "setup"))
end

function M.isActivePhase(phase)
	phase = tostring(phase or "")
	return phase == HS.const.PHASE_HIDING or phase == HS.const.PHASE_SEEKING
end
