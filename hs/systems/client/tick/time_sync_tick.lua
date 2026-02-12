HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.timeSyncTick = HS.systems.client.timeSyncTick or {
	name = "time-sync",
}

function HS.systems.client.timeSyncTick.tick(_self, ctx, dt)
	if not (HS.cli and HS.cli.timeSync and HS.cli.timeSync.tick) then return false end
	local sh = HS.select and HS.select.shared and HS.select.shared() or nil
	if not sh then return false end
	HS.cli.timeSync.tick(dt, ctx, sh)
	return false
end
