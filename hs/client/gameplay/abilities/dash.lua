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

local function normalizeHorizontalDir(dir)
	if type(dir) ~= "table" then return Vec(0, 0, -1) end
	local d = Vec(tonumber(dir[1]) or 0, 0, tonumber(dir[3]) or 0)
	if VecLength(d) < 0.001 then
		return Vec(0, 0, -1)
	end
	return VecNormalize(d)
end

local function configureBackParticles(fx)
	local tc = teamsGetColor(HS.const.TEAM_HIDERS)
	local r, g, b = fx.lightenColor(tc)

	ParticleReset()
	ParticleType("plain")
	ParticleTile(0)
	ParticleColor(r, g, b, r * 0.9, g * 0.9, b * 0.9)
	ParticleRadius(0.12, 0.022, "easeout", 0.0, 1.0)
	ParticleAlpha(0.85, 0.0, "linear", 0.0, 1.0)
	ParticleEmissive(3.2, 0.0, "linear", 0.0, 1.0)
	ParticleGravity(-2.5)
	ParticleDrag(0.22)
	ParticleCollide(0)
end

local function spawnBackColumnAt(baseFeetPos, dir, intensity)
	intensity = clamp(intensity or 1.0, 0.2, 2.0)
	dir = normalizeHorizontalDir(dir)

	local back = VecScale(dir, -1)
	local right = Vec(dir[3], 0, -dir[1])
	if VecLength(right) < 0.001 then right = Vec(1, 0, 0) end
	right = VecNormalize(right)

	local count = math.floor(60 * intensity)
	for _i = 1, count do
		local h = 0.08 + math.random() * 1.75
		local lateral = (math.random() - 0.5) * 0.28
		local behind = 0.18 + math.random() * 0.34
		local jitter = Vec((math.random() - 0.5) * 0.10, (math.random() - 0.5) * 0.06, (math.random() - 0.5) * 0.10)

		local spawn = VecAdd(baseFeetPos, Vec(0, h, 0))
		spawn = VecAdd(spawn, VecAdd(VecScale(right, lateral), VecScale(back, behind)))
		spawn = VecAdd(spawn, jitter)

		local pull = VecScale(back, 3.2 + math.random() * 6.2)
		local spray = Vec((math.random() - 0.5) * 2.6, 0.8 + math.random() * 2.6, (math.random() - 0.5) * 2.6)
		local vel = VecAdd(pull, spray)
		SpawnParticle(spawn, vel, 0.62 + math.random() * 0.26)
	end
end

local function spawnBackColumn(pid, dir, intensity)
	if type(pid) ~= "number" or pid <= 0 or not IsPlayerValid(pid) then return end
	local tr = GetPlayerTransform(pid)
	if type(tr) ~= "table" or type(tr.pos) ~= "table" then return end
	spawnBackColumnAt(tr.pos, dir, intensity)
end

local Dash = {}

function Dash.vfx(ev, fx)
	if not ev then return end
	configureBackParticles(fx)

	local pid = tonumber(ev.pid) or 0
	local dir = normalizeHorizontalDir(ev.dir)
	if pid ~= 0 and IsPlayerValid(pid) then
		spawnBackColumn(pid, dir, 1.6)
	elseif type(ev.pos) == "table" then
		local base = VecAdd(ev.pos, Vec(0, -0.90, 0))
		spawnBackColumnAt(base, dir, 1.35)
	end
end

function Dash.startFx(ev, _fx, allocEmitter)
	if not ev then return nil end
	local pid = tonumber(ev.pid) or 0
	if pid == 0 then return nil end

	local def = (HS.abilities and HS.abilities.def and HS.abilities.def((HS.abilities.ids and HS.abilities.ids.dash) or "dash")) or nil
	local duration = (def and def.cfg and tonumber(def.cfg.durationSeconds)) or 0.25
	duration = clamp(duration, 0.08, 0.60) + 0.10

	local em = (type(allocEmitter) == "function" and allocEmitter()) or {}
	em.id = (HS.abilities and HS.abilities.ids and HS.abilities.ids.dash) or "dash"
	em.pid = pid
	em.untilAt = now() + duration
	em.nextAt = now()
	em.interval = 0.02
	em.dirX = tonumber(ev.dir and ev.dir[1]) or 0
	em.dirZ = tonumber(ev.dir and ev.dir[3]) or -1
	em._configuredFrame = -1
	em._intensity = 1.35
	return em
end

function Dash.tickFx(em, _dt, nowT, fx, ctx)
	local pid = tonumber(em and em.pid) or 0
	if pid == 0 or not IsPlayerValid(pid) then
		em.untilAt = 0
		return
	end

	local interval = tonumber(em.interval) or 0.02
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

	local vel = GetPlayerVelocity(pid) or Vec(0, 0, 0)
	local hv = Vec(tonumber(vel[1]) or 0, 0, tonumber(vel[3]) or 0)
	local dir = nil
	if VecLength(hv) > 0.35 then
		dir = VecNormalize(hv)
	else
		dir = normalizeHorizontalDir(Vec(tonumber(em.dirX) or 0, 0, tonumber(em.dirZ) or -1))
	end

	local frame = (ctx and ctx.frame) or 0
	if em._configuredFrame ~= frame then
		em._configuredFrame = frame
		configureBackParticles(fx)
	end

	spawnBackColumn(pid, dir, clamp(em._intensity or 1.0, 0.2, 2.0))

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

register((HS.abilities and HS.abilities.ids and HS.abilities.ids.dash) or "dash", Dash)
