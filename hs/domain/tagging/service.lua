HS = HS or {}
HS.domain = HS.domain or {}
HS.domain.tagging = HS.domain.tagging or {}

local T = HS.domain.tagging

function T.enabled(state)
	return type(state) == "table" and type(state.settings) == "table" and state.settings.taggingEnabled == true
end

function T.range(state)
	local v = type(state) == "table" and type(state.settings) == "table" and state.settings.tagRangeMeters or 4.0
	return tonumber(v) or 4.0
end
