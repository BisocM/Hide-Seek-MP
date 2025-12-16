#version 2


#include "app.lua"

local function safeCall(label, fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if ok then return end

	HS = HS or {}
	HS._hookErrors = HS._hookErrors or {}
	local t = HS._hookErrors[label]

	local now = (type(GetTime) == "function" and GetTime()) or 0
	local msg = tostring(err or "unknown error")
	local shouldLog = (not t) or (t.msg ~= msg) or ((now - (t.t or -999)) >= 1.0)
	if shouldLog then
		HS._hookErrors[label] = { msg = msg, t = now }
		if HS.log and HS.log.error then
			HS.log.error(label .. " failed", { err = msg })
		elseif type(DebugPrint) == "function" then
			DebugPrint("[HS][error] " .. tostring(label) .. " failed: " .. msg)
		else
			print("[HS][error] " .. tostring(label) .. " failed: " .. msg)
		end
	end
end

function server.init()
	safeCall("server.init", HS.app and HS.app.server and HS.app.server.init)
end

function server.tick(dt)
	safeCall("server.tick", HS.app and HS.app.server and HS.app.server.tick, dt)
end

function client.init()
	safeCall("client.init", HS.app and HS.app.client and HS.app.client.init)
end

function client.tick(dt)
	safeCall("client.tick", HS.app and HS.app.client and HS.app.client.tick, dt)
end

function client.draw()
	safeCall("client.draw", HS.app and HS.app.client and HS.app.client.draw)
end
