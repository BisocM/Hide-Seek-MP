HS = HS or {}
HS.contracts = HS.contracts or {}
HS.contracts.eventTypes = HS.contracts.eventTypes or {}

local T = HS.contracts.eventTypes

T.TOAST = "ui.toast"
T.VICTORY = "ui.victory"
T.FEED_CAUGHT = "ui.feed_caught"
T.ABILITY_VFX = "vfx.ability"
T.TIME_SYNC = "time.sync"

function T.isKnown(v)
	v = tostring(v or "")
	return v == T.TOAST
		or v == T.VICTORY
		or v == T.FEED_CAUGHT
		or v == T.ABILITY_VFX
		or v == T.TIME_SYNC
end
