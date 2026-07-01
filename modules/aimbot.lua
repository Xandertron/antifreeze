local aimbot = {}

aimbot.moduleInfo = {
	name = "Aimbot",
	description = "Skill issue.",
	section = "combat",
}

local settings = lje.settings.open()

aimbot.currentTarget = nil
aimbot.speedMultiplier = 1000 -- how snappy it is, too much and it's obvious!
aimbot.key = _G["KEY_" .. lje.settings.get("keybinds.aimbot", "X")]

local mouse = lje.include("helpers/mouse.lua")

local sens = GetConVar_Internal("sensitivity"):GetFloat()
local m_pitch = GetConVar_Internal("m_pitch"):GetFloat()
local m_yaw = GetConVar_Internal("m_yaw"):GetFloat()

function aimbot:run()
	-- Find closest player and aim at them
	if not input.IsKeyDown(self.key) then -- If we hold it down, we don't want to change targets.
		local players = player.GetAll()
		local closestPlayer = nil
		local closestDistance = math.huge
		local myPos = LocalPlayer():GetPos()

		for _, ply in ipairs(players) do
			if type(ply) == "number" then
				lje.con_print("??? Got player as number: " .. ply)
			end

			if ply ~= LocalPlayer() and ply:Alive() then
				local dist = myPos:Distance(ply:GetPos())
				-- Weight by dot product so if we look at someone they become more likely to be targeted, even if they're slightly farther than someone else. This makes it more likely to target who we're actually aiming at instead of just whoever is closest.
				local toTarget = ply:GetPos() - myPos
				toTarget:Normalize()
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

	if not self.currentTarget or not input.IsKeyDown(self.key) then
		return
	end

	local eyePos = LocalPlayer():EyePos()
	local ourVelocity = LocalPlayer():GetVelocity()
	local theirVelocity = self.currentTarget:GetVelocity()

	ourVelocity = ourVelocity * 0.03 -- Compensate
	theirVelocity = theirVelocity * 0.05

	local targetPos = self.currentTarget:GetPos() + Vector(0, 0, 50) -- Aim at chest for better hit chance

	-- Check if we can use their head for better accuracy
	local headBone = self.currentTarget:GetHitBoxBone(0, 0)

	if headBone then
		local headPos = self.currentTarget:GetBonePosition(headBone)
		if headPos then
			targetPos = headPos
		end
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

	local dx = effectiveYaw * (m_yaw * sens) * self.speedMultiplier * FrameTime() -- Sinusoidal movement pattern for more human-like movement
	local dy = effectivePitch * (m_pitch * sens) * self.speedMultiplier * FrameTime()

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
