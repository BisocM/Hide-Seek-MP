HS = HS or {}
HS.state = HS.state or {}
HS.state.snapshot = HS.state.snapshot or {}

local S = HS.state.snapshot

S.VERSION = S.VERSION or 1
S.SCHEMA = S.SCHEMA or "hs.match.v1"
S._revision = S._revision or 0
S._syncSource = S._syncSource or nil

local function clampRev(v)
	v = math.floor(tonumber(v) or 0)
	if v < 0 then return 0 end
	return v
end

function S.installSyncSource(fn)
	if type(fn) == "function" then
		S._syncSource = fn
	end
end

function S.bump()
	S._revision = S._revision + 1
	return S._revision
end

function S.touch()
	local sh = shared and shared.hs or nil
	if type(sh) ~= "table" then return nil end
	sh.version = S.VERSION
	sh.schema = S.SCHEMA
	sh.revision = math.max(clampRev(sh.revision), S._revision)
	if sh.revision == 0 then
		sh.revision = 1
		S._revision = 1
	end
	return sh
end

function S.syncFromSource(state)
	if type(S._syncSource) == "function" then
		S._syncSource(state)
	end

	local sh = shared and shared.hs or nil
	if type(sh) ~= "table" then return end
	S.bump()
	sh.version = S.VERSION
	sh.schema = S.SCHEMA
	sh.revision = S._revision
end
