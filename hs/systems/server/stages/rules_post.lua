HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.rulesPost = HS.systems.server.rulesPost or {
	name = "rules-post",
}

function HS.systems.server.rulesPost.tick(_self, _ctx, _dt)
	local st = HS.systems.server.common.state()
	if not st then return false end

	local rt = HS.systems.server.common.runtime()
	if rt and type(rt.enforcePerTickRules) == "function" then
		rt.enforcePerTickRules(st)
	end
	return false
end
