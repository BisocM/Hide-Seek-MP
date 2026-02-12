HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.abilities = HS.domain.abilities or {}

local A = HS.domain.abilities

function A.list()
	if HS.abilities and HS.abilities.list then
		return HS.abilities.list()
	end
	return {}
end

function A.def(abilityId)
	if HS.abilities and HS.abilities.def then
		return HS.abilities.def(abilityId)
	end
	return nil
end
