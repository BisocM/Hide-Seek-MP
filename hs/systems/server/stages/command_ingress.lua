HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.commandIngress = HS.systems.server.commandIngress or {
	name = "command-ingress",
}

function HS.systems.server.commandIngress.tick(_self, _ctx, _dt)
	if HS.net and HS.net.server and HS.net.server.drain then
		HS.net.server.drain()
	end
	return false
end
