local aimbot = {}

aimbot.moduleInfo = {
	name = "Aimbot",
	description = "Skill issue.",
	section = "combat",
}

local settings = lje.settings.open()

aimbot.currentTarget = nil
aimbot.key = _G["KEY_" .. lje.settings.get("keybinds.aimbot", "X")]

local mouse = lje.include("helpers/mouse.lua")

local sens = GetConVar_Internal("sensitivity"):GetFloat()
local m_pitch = GetConVar_Internal("m_pitch"):GetFloat()
local m_yaw = GetConVar_Internal("m_yaw"):GetFloat()

local cfg = af.config.register("aimbot", {
	fov = { value = 180, min = 1, max = 180 },
	maxDistance = { value = 0, min = 0, max = 8192 },
	requireLOS = { value = true },
	drawFov = { value = true },
	speedMultiplier = { value = 2, min = 0, max = 10 }, -- how snappy it is, too much and it's obvious!
	ownVelocityComp = { value = 0.055, min = 0, max = 0.5 }, -- compensates for your own movement throwing off the aim point
	targetVelocityComp = { value = 0.06, min = 0, max = 0.5 }, -- leads a moving target by this much of their velocity
}, { "fov", "maxDistance", "requireLOS", "drawFov", "speedMultiplier", "ownVelocityComp", "targetVelocityComp" })

local function inFov(toTargetNormalized)
	if cfg.fov >= 180 then
		return true
	end

	local dot = math.clamp(LocalPlayer():GetAimVector():Dot(toTargetNormalized), -1, 1)
	local angle = math.deg(math.acos(dot))
	return angle <= cfg.fov
end

local function hasLineOfSight(fromPos, targetPos, targetEnt)
	if not cfg.requireLOS then
		return true
	end

	local tr = util.TraceLine({
		start = fromPos,
		endpos = targetPos,
		filter = LocalPlayer(),
	})

	return not tr.Hit or tr.Entity == targetEnt
end

-- thin ring built from quads (surface.DrawPoly can't punch a hole in a
-- filled circle on its own), same approach radar.lua uses for its rings.
local function drawRing(cx, cy, radius, thickness, r, g, b, a, segments)
	segments = segments or 64
	local inner, outer = radius - thickness, radius
	surface.SetDrawColor(r, g, b, a)
	surface.SetTexture(0)
	for i = 0, segments - 1 do
		local d0 = math.rad(360 * (i / segments))
		local d1 = math.rad(360 * ((i + 1) / segments))
		surface.DrawPoly({
			{ x = cx + math.cos(d0) * inner, y = cy + math.sin(d0) * inner },
			{ x = cx + math.cos(d0) * outer, y = cy + math.sin(d0) * outer },
			{ x = cx + math.cos(d1) * outer, y = cy + math.sin(d1) * outer },
			{ x = cx + math.cos(d1) * inner, y = cy + math.sin(d1) * inner },
		})
	end
end

local function fovConeRadiusPx(coneDeg)
	local viewFOV = LocalPlayer():GetFOV()
	local focalLen = (ScrH() / 2) / math.tan(math.rad(viewFOV / 2))
	return focalLen * math.tan(math.rad(coneDeg))
end

function aimbot:render()
	if not cfg.drawFov or cfg.fov >= 90 then
		return
	end

	local ac = af.brand.color
	drawRing(ScrW() / 2, ScrH() / 2, fovConeRadiusPx(cfg.fov), 1, ac.r, ac.g, ac.b, 160)
end

function aimbot:run()
	if vgui.CursorVisible() then return end --dont aimbot while a menu is open
	-- Find closest player and aim at them
	if not input.IsKeyDown(self.key) then -- If we hold it down, we don't want to change targets.
		local players = player.GetAll()
		local closestPlayer = nil
		local closestDistance = math.huge
		local myPos = LocalPlayer():GetPos()
		local myEyePos = LocalPlayer():EyePos()

		for _, ply in ipairs(players) do
			if type(ply) == "number" then
				lje.con_print("??? Got player as number: " .. ply)
			end

			if ply ~= LocalPlayer() and ply:Alive() then
				local rawDist = myPos:Distance(ply:GetPos())
				if cfg.maxDistance > 0 and rawDist > cfg.maxDistance then
					continue
				end

				local toTarget = ply:GetPos() - myPos
				toTarget:Normalize()

				if not inFov(toTarget) then
					continue
				end

				if not hasLineOfSight(myEyePos, ply:GetPos() + Vector(0, 0, 50), ply) then
					continue
				end

				local dist = rawDist
				-- Weight by dot product so if we look at someone they become more likely to be targeted, even if they're slightly farther than someone else. This makes it more likely to target who we're actually aiming at instead of just whoever is closest.
				local dot = LocalPlayer():GetAimVector():Dot(toTarget)
				dist = dist * (1 - dot) -- If dot is 1 (looking directly at them), distance becomes 0. If dot is 0 (looking perpendicular), distance stays the same. If dot is -1 (looking away), distance doubles.

				if dist < closestDistance then
					closestDistance = dist
					closestPlayer = ply
				end
			end
		end

		self.currentTarget = closestPlayer
	end

	if not self.currentTarget or not self.currentTarget:IsValid() or not input.IsKeyDown(self.key) then
		return
	end

	local eyePos = LocalPlayer():EyePos()
	local ourVelocity = LocalPlayer():GetVelocity()
	local theirVelocity = self.currentTarget:GetVelocity()

	ourVelocity = ourVelocity * cfg.ownVelocityComp * 2
	theirVelocity = theirVelocity * cfg.targetVelocityComp * 2

	local targetPos = self.currentTarget:GetPos() + Vector(0, 0, 50) -- Aim at chest for better hit chance

	-- Check if we can use their head for better accuracy
	local headBone = self.currentTarget:GetHitBoxBone(0, 0)

	if headBone then
		local headPos = self.currentTarget:GetBonePosition(headBone)
		if headPos then
			targetPos = headPos
		end
	end

	if not hasLineOfSight(eyePos, targetPos, self.currentTarget) then
		return
	end

	targetPos = targetPos - ourVelocity
	targetPos = targetPos + theirVelocity
	-- Add compensation for velocity

	local delta = (targetPos - eyePos):GetNormalized()
	local targetAng = delta:Angle()

	local curAng = LocalPlayer():EyeAngles()
	local angDiff = (targetAng - curAng)
	angDiff:Normalize() -- wraps

	local effectiveYaw = angDiff[2]
	local effectivePitch = angDiff[1]

	-- if diff is very close to 0, just force it to avoid constant micromovements.
	if math.abs(effectiveYaw) < 0.08 then
		effectiveYaw = 0
	end
	if math.abs(effectivePitch) < 0.08 then
		effectivePitch = 0
	end

	local dx = effectiveYaw * (m_yaw * sens) * cfg.speedMultiplier * 1000 * FrameTime() -- Sinusoidal movement pattern for more human-like movement
	local dy = effectivePitch * (m_pitch * sens) * cfg.speedMultiplier * 1000 * FrameTime()

	-- Flip for windows coordinate system
	dx = -dx

	-- If it's close like -0.98, do -1. Likewise, if 0.98 do 1.
	if dx > 0 then
		dx = math.ceil(dx)
	else
		dx = math.floor(dx)
	end

	if dy > 0 then
		dy = math.ceil(dy)
	else
		dy = math.floor(dy)
	end

	mouse.move(dx, dy)
end

function aimbot:cleanup()
	aimbot.currentTarget = nil
end

return aimbot
