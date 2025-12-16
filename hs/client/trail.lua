HS = HS or {}
HS.cli = HS.cli or {}
HS.cli.trail = HS.cli.trail or {}

local TRAIL_LIFETIME = 2.00
local TRAIL_INTERVAL = 0.01
local TRAIL_MIN_DIST = 0.11
local TRAIL_MIN_SPEED = 0.75
local TRAIL_MAX_RANGE = 120.0

local function localPlayerId()
	return HS.engine.localPlayerId()
end

local function isLocalSeeker(sh)
	if not sh or not sh.teamOf or not sh.outOf then return false end
	local pid = localPlayerId()
	if sh.outOf[pid] == true then return false end
	return (sh.teamOf[pid] or 0) == HS.const.TEAM_SEEKERS
end

local function isTrailEnabled(sh)
	return sh and sh.settings and sh.settings.hiderTrailEnabled == true
end

local function lightenColor(c)
	if type(c) ~= "table" then
		return 0.85, 0.85, 0.95
	end
	local r = HS.util.clamp((c[1] or 1) * 0.45 + 0.55, 0, 1)
	local g = HS.util.clamp((c[2] or 1) * 0.45 + 0.55, 0, 1)
	local b = HS.util.clamp((c[3] or 1) * 0.45 + 0.55, 0, 1)
	return r, g, b
end

function HS.cli.trail.init()
	HS.cli.trail._lastPos = HS.cli.trail._lastPos or {}
	HS.cli.trail._lastT = HS.cli.trail._lastT or {}
end

local function configureTrailParticles()
	local tc = teamsGetColor(HS.const.TEAM_HIDERS)
	local r, g, b = lightenColor(tc)

	ParticleReset()
	ParticleType("plain")
	ParticleTile(0)
	ParticleColor(r, g, b, r * 0.9, g * 0.9, b * 0.9)
	ParticleRadius(0.055, 0.014, "easeout", 0.0, 1.0)
	ParticleAlpha(0.36, 0.0, "linear", 0.0, 1.0)
	ParticleEmissive(2.0, 0.0, "linear", 0.0, 1.0)
	ParticleGravity(0)
	ParticleDrag(0.35)
	ParticleCollide(0)
end

local function spawnTrailAt(pos, velDir)
	local jitter = Vec((math.random() - 0.5) * 0.18, 0.03, (math.random() - 0.5) * 0.18)
	local p1 = VecAdd(pos, jitter)
	SpawnParticle(p1, Vec(0, 0.10, 0), TRAIL_LIFETIME)
	SpawnParticle(VecAdd(p1, Vec(0, 0.06, 0)), Vec(0, 0.12, 0), TRAIL_LIFETIME * 0.85)

	if velDir and VecLength(velDir) > 0.001 then
		local behind1 = VecSub(pos, VecScale(velDir, 0.30))
		local behind2 = VecSub(pos, VecScale(velDir, 0.55))
		local jitter2 = Vec((math.random() - 0.5) * 0.14, 0.03, (math.random() - 0.5) * 0.14)
		local jitter3 = Vec((math.random() - 0.5) * 0.14, 0.03, (math.random() - 0.5) * 0.14)
		SpawnParticle(VecAdd(behind1, jitter2), Vec(0, 0.08, 0), TRAIL_LIFETIME)
		SpawnParticle(VecAdd(behind2, jitter3), Vec(0, 0.06, 0), TRAIL_LIFETIME * 0.9)
	end
end

function HS.cli.trail.tick(_dt)
	local sh = HS.select.shared()
	if not isTrailEnabled(sh) then return end
	if not isLocalSeeker(sh) then return end
	if sh.phase ~= HS.const.PHASE_SEEKING then return end
	if not sh.teamOf or not sh.outOf then return end

	local now = HS.util.now()
	local localPos = GetPlayerTransform(localPlayerId()).pos

	local particlesReady = false

	for _, pid in ipairs(HS.util.getPlayersSorted()) do
		if pid ~= localPlayerId() and IsPlayerValid(pid) and not IsPlayerDisabled(pid) and GetPlayerHealth(pid) > 0 then
			if sh.outOf[pid] ~= true and sh.teamOf[pid] == HS.const.TEAM_HIDERS then
				local pos = GetPlayerTransform(pid).pos
				if HS.util.vecDist(pos, localPos) <= TRAIL_MAX_RANGE then
					local vel = GetPlayerVelocity(pid)
					local speed = VecLength(vel)
					if speed >= TRAIL_MIN_SPEED then
						local lastPos = HS.cli.trail._lastPos[pid]
						local lastT = HS.cli.trail._lastT[pid] or -999

						local movedEnough = (not lastPos) or (HS.util.vecDist(pos, lastPos) >= TRAIL_MIN_DIST)
						local waitedEnough = (now - lastT) >= TRAIL_INTERVAL
						if movedEnough and waitedEnough then
							if not particlesReady then
								configureTrailParticles()
								particlesReady = true
							end

							local emitPos = pos

							local dir = Vec(0, 0, 0)
							if speed > 0.01 then
								dir = VecNormalize(vel)
							end

							spawnTrailAt(emitPos, dir)

							HS.cli.trail._lastPos[pid] = pos
							HS.cli.trail._lastT[pid] = now
						end
					end
				end
			end
		end
	end
end
