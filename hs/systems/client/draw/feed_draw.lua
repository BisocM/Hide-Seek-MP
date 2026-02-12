HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.feedDraw = HS.systems.client.feedDraw or {
	name = "feed-draw",
}

function HS.systems.client.feedDraw.draw(_self, _ctx, _dt)
	if HS.cli and HS.cli.feed and HS.cli.feed.draw then
		HS.cli.feed.draw()
	end
	return false
end
