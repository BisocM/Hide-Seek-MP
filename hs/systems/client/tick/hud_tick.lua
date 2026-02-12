HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.hudTick = HS.systems.client.hudTick or {
	name = "hud-tick",
}

function HS.systems.client.hudTick.tick(_self, _ctx, dt)
	hudTick(dt)
	if HS.cli and HS.cli.toast and HS.cli.toast.tick then HS.cli.toast.tick(dt) end
	if HS.cli and HS.cli.feed and HS.cli.feed.tick then HS.cli.feed.tick(dt) end
	return false
end
