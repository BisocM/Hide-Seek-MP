HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.server = HS.systems.server or {}

HS.systems.server.snapshotPublish = HS.systems.server.snapshotPublish or {
	name = "snapshot-publish",
}

function HS.systems.server.snapshotPublish.tick(_self, _ctx, _dt)
	if HS.state and HS.state.snapshot and HS.state.snapshot.touch then
		HS.state.snapshot.touch()
	end
	return false
end
