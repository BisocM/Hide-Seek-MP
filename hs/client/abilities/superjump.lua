HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.abilities = HS.cli.abilities or {}

local C = HS.cli.abilities

local function clamp(v, a, b)
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

local function now()
	return (HS.engine and HS.engine.now and HS.engine.now()) or 0
end

local function configureGroundPlumeParticles(fx)
	local tc = teamsGetColor(HS.const.TEAM_HIDERS)
	local r, g, b = fx.lightenColor(tc)

	ParticleReset()
	ParticleType("plain")
	ParticleTile(0)
	ParticleColor(r, g, b, r * 0.9, g * 0.9, b * 0.9)
	ParticleRadius(0.14, 0.03, "easeout", 0.0, 1.0)
	ParticleAlpha(0.80, 0.0, "linear", 0.0, 1.0)
	ParticleEmissive(2.8, 0.0, "linear", 0.0, 1.0)
	ParticleGravity(0)
	ParticleDrag(0.30)
	ParticleCollide(0)
end

local function spawnGroundPlume(pos, intensity)
	intensity = clamp(intensity or 1.0, 0.2, 2.0)
	local center = VecAdd(pos, Vec(0, 0.06, 0))

	local count = math.floor(160 * intensity)
	for _i = 1, count do
		local a = math.random() * math.pi * 2
		local radius = 0.2 + math.random() * 0.95
		local off = Vec(math.cos(a) * radius, (math.random() - 0.5) * 0.04, math.sin(a) * radius)
		local out = VecNormalize(Vec(off[1], 0, off[3]))
		local speed = 2.0 + math.random() * 4.8
		local vel = Vec(out[1] * speed, 0.02 + math.random() * 0.08, out[3] * speed)
		SpawnParticle(VecAdd(center, off), vel, 0.55 + math.random() * 0.25)
	end
end

local function configureAirParticles(fx)
	local tc = teamsGetColor(HS.const.TEAM_HIDERS)
	local r, g, b = fx.lightenColor(tc)

	ParticleReset()
	ParticleType("plain")
	ParticleTile(0)
	ParticleColor(r, g, b, r * 0.9, g * 0.9, b * 0.9)
	ParticleRadius(0.11, 0.02, "easeout", 0.0, 1.0)
	ParticleAlpha(0.95, 0.0, "linear", 0.0, 1.0)
	ParticleEmissive(3.4, 0.0, "linear", 0.0, 1.0)
	ParticleGravity(-4.0)
	ParticleDrag(0.18)
	ParticleCollide(0)
end

local function spawnAirBurst(pid, intensity)
	if type(pid) ~= "number" or pid <= 0 or not IsPlayerValid(pid) then return end
	local tr = GetPlayerTransform(pid)
	if type(tr) ~= "table" or type(tr.pos) ~= "table" then return end

	local pos = tr.pos
	local vel = GetPlayerVelocity(pid) or Vec(0, 0, 0)
	local hv = Vec(tonumber(vel[1]) or 0, tonumber(vel[2]) or 0, tonumber(vel[3]) or 0)
	local base = VecScale(hv, -0.12)

	intensity = clamp(intensity or 1.0, 0.2, 2.0)
	local count = math.floor(26 * intensity)
	for _i = 1, count do
		local h = 0.12 + math.random() * 1.58
		local rx = (math.random() - 0.5) * 0.36
		local rz = (math.random() - 0.5) * 0.36
		local spawn = VecAdd(pos, Vec(rx, h, rz))

		local spray = Vec((math.random() - 0.5) * 2.8, 1.4 + math.random() * 2.8, (math.random() - 0.5) * 2.8)
		local pv = VecAdd(base, spray)
		SpawnParticle(spawn, pv, 0.55 + math.random() * 0.25)
	end
end

local Super = {}

function Super.vfx(ev, fx)
	if not ev or type(ev.pos) ~= "table" then return end
	configureGroundPlumeParticles(fx)
	spawnGroundPlume(ev.pos, 1.25)
end

function Super.startFx(ev, _fx, allocEmitter)
	if not ev then return nil end
	local pid = tonumber(ev.pid) or 0
	if pid == 0 then return nil end

	local em = (type(allocEmitter) == "function" and allocEmitter()) or {}
	em.id = (HS.abilities and HS.abilities.ids and HS.abilities.ids.superjump) or "superjump"
	em.pid = pid
	em.untilAt = now() + 0.65
	em.nextAt = now()
	em.interval = 0.03
	em._configuredFrame = -1
	em._intensity = 1.4
	return em
end

function Super.tickFx(em, _dt, nowT, fx, ctx)
	local pid = tonumber(em and em.pid) or 0
	if pid == 0 or not IsPlayerValid(pid) then
		em.untilAt = 0
		return
	end

	local interval = tonumber(em.interval) or 0.03
	local nextAt = tonumber(em.nextAt) or nowT
	if nowT < nextAt then return end

	local tr = GetPlayerTransform(pid)
	local pos = (type(tr) == "table") and tr.pos or nil
	if type(pos) ~= "table" then
		em.untilAt = 0
		return
	end
	local inRange = true
	local okRange, res = pcall(fx.vfxInRange, pos)
	if okRange then inRange = res == true end
	if not inRange then
		em.nextAt = nowT + 0.10
		return
	end

	local frame = (ctx and ctx.frame) or 0
	if em._configuredFrame ~= frame then
		em._configuredFrame = frame
		configureAirParticles(fx)
	end

	local intensity = clamp(em._intensity or 1.0, 0.2, 2.0)
	spawnAirBurst(pid, intensity)

	local catchup = 0
	while nowT >= nextAt and catchup < 3 do
		nextAt = nextAt + interval
		catchup = catchup + 1
	end
	em.nextAt = nextAt
end

local function register(id, impl)
	if type(C.register) == "function" then
		return C.register(id, impl)
	end
	C._pendingImpl = C._pendingImpl or {}
	C._pendingImpl[#C._pendingImpl + 1] = { id = id, impl = impl }
	return true
end

register((HS.abilities and HS.abilities.ids and HS.abilities.ids.superjump) or "superjump", Super)
