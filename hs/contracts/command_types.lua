HS = HS or {}
HS.contracts = HS.contracts or {}
HS.contracts.commandTypes = HS.contracts.commandTypes or {}

local T = HS.contracts.commandTypes

T.START_MATCH = "start_match"
T.REQUEST_TAG = "request_tag"
T.ABILITY = "ability"
T.TIME_SYNC = "time_sync"
T.UPDATE_LOADOUT = "update_loadout"
T.TEAM_JOIN = "team_join"

function T.isKnown(v)
	v = tostring(v or "")
	return v == T.START_MATCH
		or v == T.REQUEST_TAG
		or v == T.ABILITY
		or v == T.TIME_SYNC
		or v == T.UPDATE_LOADOUT
		or v == T.TEAM_JOIN
end
