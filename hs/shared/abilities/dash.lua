
HS = HS or {}
HS.abilities = HS.abilities or {}

local A = HS.abilities

A.ids = A.ids or {
	dash = "dash",
	superjump = "superjump",
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
	id = A.ids.dash or "dash",
	slot = 1,
	team = HS.const.TEAM_HIDERS,
	icon = "MOD/ui/icons/dash.png",
	key = "abilityDash",
	cooldownSeconds = 8.0,
	cfg = {
		distance = 5.5,
		durationSeconds = 0.25,
	},
})
