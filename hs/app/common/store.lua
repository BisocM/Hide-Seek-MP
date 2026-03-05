HS = HS or {}
HS.app = HS.app or {}
HS.app.store = HS.app.store or {}

local S = HS.app.store

S._server = S._server or nil

function S.initServer(state)
	S._server = state
end

function S.getServer()
	return S._server
end

function S.setServer(state)
	S._server = state
	return S._server
end
