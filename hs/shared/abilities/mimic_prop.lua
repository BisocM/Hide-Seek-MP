HS = HS or {}
HS.abilities = HS.abilities or {}

local A = HS.abilities

A.ids = A.ids or {
	dash = "dash",
	superjump = "superjump",
	mimicProp = "mimic_prop",
}

local function register(def)
	if type(A.register) == "function" then
		return A.register(def)
	end
	A._pendingDefs = A._pendingDefs or {}
	A._pendingDefs[#A._pendingDefs + 1] = def
	return true
end

register({
	id = A.ids.mimicProp or "mimic_prop",
	slot = 3,
	team = HS.const.TEAM_HIDERS,
	icon = "MOD/ui/icons/mimic_prop.png",
	key = "abilitySlot3",
	cooldownSeconds = 18.0,
	cfg = {
		durationSeconds = 10.0,
		walkSpeedScale = 0.62,
		maxShapes = 20,
		maxVoxels = 32000,
		maxMass = 450,
		maxExtent = 4.5,
	},
})
