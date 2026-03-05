HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.abilities = HS.cli.abilities or {}

local C = HS.cli.abilities

local function clamp(v, a, b)
	if HS.util and HS.util.math and HS.util.math.clamp then
		return HS.util.math.clamp(tonumber(v) or 0, a, b)
	end
	return HS.util.clamp(tonumber(v) or 0, a, b)
end

local function now()
	if HS.util and HS.util.time and HS.util.time.now then
		return HS.util.time.now()
	end
	return (HS.engine and HS.engine.now and HS.engine.now()) or 0
end

local function configurePulseParticles(fx)
	local tc = teamsGetColor(HS.const.TEAM_HIDERS)
	local r, g, b = fx.lightenColor(tc)

	ParticleReset()
	ParticleType("plain")
	ParticleTile(0)
	ParticleColor(r, g, b, r * 0.95, g * 0.95, b * 0.95)
	ParticleRadius(0.10, 0.02, "easeout", 0.0, 1.0)
	ParticleAlpha(0.9, 0.0, "linear", 0.0, 1.0)
	ParticleEmissive(3.8, 0.0, "linear", 0.0, 1.0)
	ParticleGravity(0.4)
	ParticleDrag(0.15)
	ParticleCollide(0)
end

local function spawnPulse(pos, intensity)
	intensity = clamp(intensity or 1.0, 0.2, 2.0)
	local center = VecAdd(pos, Vec(0, 1.0, 0))
	local count = math.floor(70 * intensity)

	for _i = 1, count do
		local a = math.random() * math.pi * 2
		local radius = 0.18 + math.random() * 0.68
		local h = (math.random() - 0.5) * 1.45
		local off = Vec(math.cos(a) * radius, h, math.sin(a) * radius)
		local dir = VecNormalize(Vec(off[1], off[2] * 0.6, off[3]))
		local speed = 1.2 + math.random() * 2.8
		local vel = VecScale(dir, speed)
		SpawnParticle(VecAdd(center, off), vel, 0.45 + math.random() * 0.35)
	end
end

local Mimic = {}

function Mimic.vfx(ev, fx)
	if not ev or type(ev.pos) ~= "table" then return end
	configurePulseParticles(fx)
	spawnPulse(ev.pos, 1.2)
end

function Mimic.startFx(ev, _fx, allocEmitter)
	if not ev then return nil end
	local pid = tonumber(ev.pid) or 0
	if pid <= 0 then return nil end

	local em = (type(allocEmitter) == "function" and allocEmitter()) or {}
	em.id = (HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop"
	em.pid = pid
	em.untilAt = now() + 0.55
	em.nextAt = now()
	em.interval = 0.04
	em._configuredFrame = -1
	em._intensity = 0.85
	return em
end

function Mimic.tickFx(em, _dt, nowT, fx, ctx)
	local pid = tonumber(em and em.pid) or 0
	if pid <= 0 or not IsPlayerValid(pid) then
		em.untilAt = 0
		return
	end

	local interval = tonumber(em.interval) or 0.04
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
		configurePulseParticles(fx)
	end

	spawnPulse(pos, clamp(em._intensity or 1.0, 0.2, 2.0))

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

register((HS.abilities and HS.abilities.ids and HS.abilities.ids.mimicProp) or "mimic_prop", Mimic)
