#version 2

server = server or {}
client = client or {}
shared = shared or {}

local TEAM_START_SIGNAL = -9001

local function safeNow()
	if type(GetTime) == "function" then
		local ok, t = pcall(GetTime)
		if ok then return tonumber(t) or 0 end
	end
	return 0
end

local function safeLocalPlayer()
	if type(GetLocalPlayer) == "function" then
		local ok, pid = pcall(GetLocalPlayer)
		if ok then return tonumber(pid) or 0 end
	end
	return 0
end

local function isHost(pid)
	if type(IsPlayerHost) == "function" then
		local ok, v = pcall(IsPlayerHost, tonumber(pid) or 0)
		return ok and v == true
	end
	return false
end

local function argSummary(v)
	local t = type(v)
	if t == "nil" then
		return "nil"
	end
	if t == "table" then
		local n = 0
		for _ in pairs(v) do
			n = n + 1
		end
		return "table{" .. tostring(n) .. "}"
	end
	return t .. ":" .. tostring(v)
end

local function ensureSharedState()
	shared.repro = shared.repro or {}
	local st = shared.repro
	st.seq = tonumber(st.seq) or 0
	st.counters = st.counters or {}
	st.last = tostring(st.last or "none")
	st.history = st.history or {}
	return st
end

local function pushHistory(st, line)
	st.history[#st.history + 1] = line
	while #st.history > 10 do
		table.remove(st.history, 1)
	end
end

local function serverRecord(handlerName, ...)
	local st = ensureSharedState()
	local args = { ... }
	local argc = #args
	local a1 = argSummary(args[1])
	local a2 = argSummary(args[2])
	local a3 = argSummary(args[3])
	local a4 = argSummary(args[4])

	st.seq = st.seq + 1
	st.counters[handlerName] = (tonumber(st.counters[handlerName]) or 0) + 1
	st.last = string.format(
		"#%d %s argc=%d a1=%s a2=%s a3=%s a4=%s",
		st.seq,
		tostring(handlerName),
		argc,
		a1,
		a2,
		a3,
		a4
	)
	pushHistory(st, st.last)

	if type(DebugPrint) == "function" then
		DebugPrint("[RPC-REPRO][server] " .. st.last)
	end

	if type(ClientCall) == "function" then
		pcall(ClientCall, 0, "client.repro_ack", st.seq, handlerName, argc, a1, a2, a3, a4, safeNow())
	end
end

function server.init()
	ensureSharedState()
	serverRecord("server.init")
end

function server.repro_noargs(...)
	serverRecord("repro_noargs", ...)
end

function server.repro_with_id(...)
	serverRecord("repro_with_id", ...)
end

function server.repro_with_table(...)
	serverRecord("repro_with_table", ...)
end

function server.repro_with_mixed(...)
	serverRecord("repro_with_mixed", ...)
end

function server.repro_teamlike(...)
	local args = { ... }
	local hasSignal = false
	for i = 1, math.min(4, #args) do
		if tonumber(args[i]) == TEAM_START_SIGNAL then
			hasSignal = true
			break
		end
	end
	if hasSignal then
		serverRecord("repro_teamlike_signal", ...)
	else
		serverRecord("repro_teamlike_other", ...)
	end
end

function server.repro_ping(...)
	serverRecord("repro_ping", ...)
end

local C = {
	feed = {},
	lastAck = "none",
	lastSend = "none",
	lastSendAt = 0,
	totalSends = 0,
	totalAcks = 0,
}

local function clientPushFeed(line)
	C.feed[#C.feed + 1] = line
	while #C.feed > 10 do
		table.remove(C.feed, 1)
	end
end

local function payloadForCase(caseName)
	return {
		case = tostring(caseName),
		localId = safeLocalPlayer(),
		t = safeNow(),
		experimental = true,
	}
end

local function sendCall(label, fnName, ...)
	local ok = false
	if type(ServerCall) == "function" then
		ok = pcall(ServerCall, fnName, ...)
	end
	C.totalSends = C.totalSends + 1
	C.lastSendAt = safeNow()
	C.lastSend = string.format("%s -> %s transport=%s", label, fnName, ok and "ok" or "failed")
	clientPushFeed("[SEND] " .. C.lastSend)

	if type(DebugPrint) == "function" then
		DebugPrint("[RPC-REPRO][client] " .. C.lastSend)
	end
	return ok
end

local function sendCaseNoArgs()
	sendCall("A noargs", "server.repro_noargs")
end

local function sendCaseId()
	sendCall("B id", "server.repro_with_id", safeLocalPlayer())
end

local function sendCaseTable()
	sendCall("C table", "server.repro_with_table", payloadForCase("table_only"))
end

local function sendCaseMixed()
	sendCall("D mixed", "server.repro_with_mixed", safeLocalPlayer(), payloadForCase("id_plus_table"))
end

local function sendCaseTeamSignal()
	sendCall("E team-like", "server.repro_teamlike", safeLocalPlayer(), TEAM_START_SIGNAL)
end

local function sendCasePing()
	sendCall("P ping", "server.repro_ping", safeLocalPlayer(), safeNow())
end

function client.repro_ack(seq, handlerName, argc, a1, a2, a3, a4, ts)
	C.totalAcks = C.totalAcks + 1
	C.lastAck = string.format(
		"#%s %s argc=%s a1=%s a2=%s a3=%s a4=%s t=%.3f",
		tostring(seq),
		tostring(handlerName),
		tostring(argc),
		tostring(a1),
		tostring(a2),
		tostring(a3),
		tostring(a4),
		tonumber(ts) or 0
	)
	clientPushFeed("[ACK] " .. C.lastAck)
end

function client.init()
	C.feed = {}
	C.lastAck = "none"
	C.lastSend = "none"
	C.lastSendAt = 0
	C.totalSends = 0
	C.totalAcks = 0
end

function client.tick(_dt)
	if type(InputPressed) == "function" then
		if InputPressed("1") then sendCaseNoArgs() end
		if InputPressed("2") then sendCaseId() end
		if InputPressed("3") then sendCaseTable() end
		if InputPressed("4") then sendCaseMixed() end
		if InputPressed("5") then sendCaseTeamSignal() end
		if InputPressed("p") then sendCasePing() end
	end
end

local function drawButton(label, w, h)
	if UiTextButton(label, w, h) then
		return true
	end
	return false
end

local function drawLine(text, r, g, b, a)
	UiColor(r or 1, g or 1, b or 1, a or 1)
	UiText(tostring(text or ""))
end

function client.draw()
	UiPush()
	UiMakeInteractive()
	UiAlign("left top")
	UiTranslate(24, 24)

	local panelW = 760
	local panelH = 640
	UiColor(0.05, 0.05, 0.06, 0.9)
	UiRoundedRect(panelW, panelH, 12)

	UiTranslate(16, 14)
	UiFont("bold.ttf", 28)
	drawLine("MP ServerCall Repro", 0.95, 0.95, 1.0, 1)

	UiFont("regular.ttf", 20)
	local me = safeLocalPlayer()
	drawLine("Local player: " .. tostring(me) .. " | host=" .. tostring(isHost(me)), 0.8, 0.9, 1.0, 1)
	drawLine("Press 1..5 (or click buttons). P sends ping.", 0.9, 0.9, 0.9, 1)
	UiTranslate(0, 10)

	local bw = 340
	local bh = 38
	if drawButton("1) A: ServerCall(name)", bw, bh) then sendCaseNoArgs() end
	UiTranslate(0, bh + 6)
	if drawButton("2) B: ServerCall(name, localId)", bw, bh) then sendCaseId() end
	UiTranslate(0, bh + 6)
	if drawButton("3) C: ServerCall(name, table)", bw, bh) then sendCaseTable() end
	UiTranslate(0, bh + 6)
	if drawButton("4) D: ServerCall(name, localId, table)", bw, bh) then sendCaseMixed() end
	UiTranslate(0, bh + 6)
	if drawButton("5) E: ServerCall(name, localId, -9001)", bw, bh) then sendCaseTeamSignal() end
	UiTranslate(0, bh + 6)
	if drawButton("P) Ping server", bw, bh) then sendCasePing() end

	UiTranslate(360, -(bh + 6) * 6)
	UiFont("regular.ttf", 18)
	drawLine("Last send: " .. tostring(C.lastSend), 1, 1, 0.75, 1)
	drawLine("Last ack:  " .. tostring(C.lastAck), 0.75, 1, 0.75, 1)
	drawLine("Sends: " .. tostring(C.totalSends) .. " | Acks: " .. tostring(C.totalAcks), 0.9, 0.9, 0.9, 1)

	local st = shared and shared.repro or nil
	if st then
		drawLine("Server seq: " .. tostring(st.seq or 0), 0.8, 0.9, 1, 1)
		local ctr = st.counters or {}
		drawLine("Counters:", 0.95, 0.95, 1.0, 1)
		drawLine("  A noargs:         " .. tostring(ctr.repro_noargs or 0), 0.85, 0.85, 0.85, 1)
		drawLine("  B with_id:        " .. tostring(ctr.repro_with_id or 0), 0.85, 0.85, 0.85, 1)
		drawLine("  C with_table:     " .. tostring(ctr.repro_with_table or 0), 0.85, 0.85, 0.85, 1)
		drawLine("  D with_mixed:     " .. tostring(ctr.repro_with_mixed or 0), 0.85, 0.85, 0.85, 1)
		drawLine("  E teamlike_other: " .. tostring(ctr.repro_teamlike_other or 0), 0.85, 0.85, 0.85, 1)
		drawLine("  E teamlike_signal:" .. tostring(ctr.repro_teamlike_signal or 0), 0.85, 0.85, 0.85, 1)
		drawLine("  P ping:           " .. tostring(ctr.repro_ping or 0), 0.85, 0.85, 0.85, 1)
		drawLine("Server last: " .. tostring(st.last or "none"), 0.75, 0.95, 1.0, 1)
	end

	UiTranslate(-360, 250)
	UiFont("regular.ttf", 17)
	drawLine("Client feed (newest last):", 0.95, 0.95, 1.0, 1)
	for i = 1, #C.feed do
		drawLine(C.feed[i], 0.85, 0.85, 0.85, 1)
	end

	UiPop()
end
