HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.teamsSetup = HS.systems.server.teamsSetup or {
	name = "teams-setup",
}

function HS.systems.server.teamsSetup.tick(_self, _ctx, dt)
	local st = HS.systems.server.common.state()
	if not st then return false end
	if st.phase ~= HS.const.PHASE_SETUP then return false end

	teamsTick(dt)
	if teamsIsSetup() then
		local rt = HS.systems.server.common.runtime()
		if rt and type(rt.onTeamsLocked) == "function" then
			rt.onTeamsLocked(st)
		end
		return true
	end
	return false
end
