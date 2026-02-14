HS = HS or {}
HS.contracts = HS.contracts or {}
HS.contracts.abilityErrors = HS.contracts.abilityErrors or {}

local E = HS.contracts.abilityErrors

function E.mimicToastKey(reason)
	reason = tostring(reason or "")
	if reason == "no_pick" or reason == "world_body" or reason == "not_dynamic" then
		return "hs.toast.mimicNeedDynamicProp"
	end
	if reason == "player_body" or reason == "vehicle_body" or reason == "tag_blocked" then
		return "hs.toast.mimicInvalidTarget"
	end
	if reason == "target_in_use" then
		return "hs.toast.mimicInvalidTarget"
	end
	if reason == "too_many_shapes" or reason == "too_many_voxels" or reason == "too_heavy" or reason == "too_large" then
		return "hs.toast.mimicTooComplex"
	end
	return "hs.toast.mimicUnavailable"
end
