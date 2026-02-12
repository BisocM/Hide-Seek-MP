HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.rulesPre = HS.systems.server.rulesPre or {
	name = "rules-pre",
}

function HS.systems.server.rulesPre.tick(_self, _ctx, _dt)
	local st = HS.systems.server.common.state()
	if not st then return false end

	local rt = HS.systems.server.common.runtime()
	if not rt then return false end

	if type(rt.enforcePerTickRules) == "function" then rt.enforcePerTickRules(st) end
	if type(rt.handleSeekersNotKillableByHiders) == "function" then rt.handleSeekersNotKillableByHiders(st) end
	if type(rt.handleHidersNotKillableBySeekers) == "function" then rt.handleHidersNotKillableBySeekers(st) end
	if type(rt.handleDeaths) == "function" then rt.handleDeaths(st) end
	return false
end
