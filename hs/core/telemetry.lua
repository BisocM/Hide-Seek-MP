
HS = HS or {}
HS.telemetry = HS.telemetry or {}

local T = HS.telemetry

T.enabled = T.enabled == true

function T.setEnabled(v)
	T.enabled = v == true
end

function T.event(name, fields)
	if not T.enabled then return end
	(HS.log and HS.log.debug or print)("telemetry:" .. tostring(name), fields)
end

