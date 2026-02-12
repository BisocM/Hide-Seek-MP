HS = HS or {}
HS.systems = HS.systems or {}
HS.systems.client = HS.systems.client or {}

HS.systems.client.bannerDraw = HS.systems.client.bannerDraw or {
	name = "banner-draw",
}

function HS.systems.client.bannerDraw.draw(_self, _ctx, dt)
	hudDrawBanner(dt)
	return false
end
