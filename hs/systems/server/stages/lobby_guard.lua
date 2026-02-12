HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.lobbyGuard = HS.systems.server.lobbyGuard or {
	name = "lobby-guard",
}

function HS.systems.server.lobbyGuard.tick(_self, _ctx, _dt)
	local st = HS.systems.server.common.state()
	if not st then return false end
	if st.phase == HS.const.PHASE_SETUP then return false end

	local count = tonumber(GetPlayerCount()) or 0
	if count < 2 then
		st.insufficientPlayersSince = st.insufficientPlayersSince or HS.util.now()
		if (HS.util.now() - st.insufficientPlayersSince) >= 1.0 then
			HS.srv.app.resetToSetup(st, "hs.toast.notEnoughPlayers")
			return true
		end
	else
		st.insufficientPlayersSince = nil
	end
	return false
end
