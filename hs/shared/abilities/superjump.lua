
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
	id = A.ids.superjump or "superjump",
	slot = 2,
	team = HS.const.TEAM_HIDERS,
	icon = "MOD/ui/icons/superjump.png",
	key = "abilitySuperjump",
	cooldownSeconds = 12.0,
	cfg = {
		armSeconds = 6.0,
		jumpBoost = 14.0,
	},
	trigger = {
		action = "jump",
		event = "trigger",
	},
})
