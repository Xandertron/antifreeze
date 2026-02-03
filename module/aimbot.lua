local aimbot = aimbot or {}

aimbot.name = "Aimbot"
aimbot.description = "Skill issue."

local pid = lje.include("util/pid.lua")

local config = af.config
config.init("aimbot", {
	minDistance = { value = 1000, min = 0, max = 30000 },

	pitchResponseP = { value = 35, min = -180, max = 180 },
	pitchResponseD = { value = 0.25, min = -180, max = 180 },
	pitchResponseI = { value = 0, min = -180, max = 180 },

	yawResponseP = { value = 42, min = -180, max = 180 },
	yawResponseD = { value = 0, min = -180, max = 180 },
	yawResponseI = { value = 0, min = -180, max = 180 },

	selfVelocityCompensation = { value = 0.028, min = 0, max = 0.1 },
	targetVelocityCompensation = { value = 0.017, min = 0, max = 0.1 },
})

aimbot.target = nil
-- integrals aren't used, because of steady state error not being an issue in aimbot
aimbot.pitch_pid = pid.new(
	config.get("aimbot", "pitchResponseP"),
	config.get("aimbot", "pitchResponseD"),
	config.get("aimbot", "pitchResponseI"),
	-360,
	360
)
aimbot.yaw_pid = pid.new(
	config.get("aimbot", "yawResponseP"),
	config.get("aimbot", "yawResponseD"),
	config.get("aimbot", "yawResponseI"),
	-360,
	360
)
aimbot.last_time = SysTime()

local function normalizeAngle(ang)
	while ang > 180 do
		ang = ang - 360
	end
	while ang < -180 do
		ang = ang + 360
	end
	return ang
end
-- Bind key is specified as the enum name for the corresponding KEY_* enum value
-- This is a little gross so brace yourself
aimbot.bind_code = _L["KEY_H"]
if not aimbot.bind_code then
	lje.con_print("Invalid bind key specified in config/aimbot.lua")
	aimbot.bind_code = KEY_H
end

local function draw()
	-- update pids
	aimbot.pitch_pid.kp = config.get("aimbot", "pitchResponseP")
	aimbot.yaw_pid.kp = config.get("aimbot", "yawResponseP")
	local dt = SysTime() - aimbot.last_time
	aimbot.last_time = SysTime()
	if not input.IsKeyDown(aimbot.bind_code) then
		aimbot.target = nil -- Remove latch on target with key up
	end

	-- Bind key is specified as the enum name for the corresponding KEY_* enum value
	-- This is a little gross so brace yourself
	if not aimbot.target and input.IsKeyDown(aimbot.bind_code) and not vgui.CursorVisible() then
		local qualifiedPlayers = {}
		for _, ply in ipairs(player.GetAll()) do
			if
				ply ~= LocalPlayer()
				and LocalPlayer():GetPos():Distance(ply:GetPos()) <= config.get("aimbot", "minDistance")
				and ply:Alive()
			then
				table.insert(qualifiedPlayers, ply)
			end
		end

		if #qualifiedPlayers > 0 then
			local aimVectorForward = LocalPlayer():GetAimVector()
			table.sort(qualifiedPlayers, function(a, b)
				local distA = LocalPlayer():GetPos():Distance(a:GetPos())
				local distB = LocalPlayer():GetPos():Distance(b:GetPos())

				-- Check dot product to also factor in who we're aiming at
				local toA = a:GetPos()
				toA:Sub(LocalPlayer():GetShootPos())
				toA:Normalize()
				local dotA = aimVectorForward:Dot(toA)

				local toB = b:GetPos()
				toB:Sub(LocalPlayer():GetShootPos())
				toB:Normalize()
				local dotB = aimVectorForward:Dot(toB)

				distA = distA * (1 - dotA)
				distB = distB * (1 - dotB)
				return distA < distB
			end)

			aimbot.target = qualifiedPlayers[1]
		end
	end

	if aimbot.target and aimbot.target:Alive() then
		local lp = LocalPlayer()

		local targetPos = aimbot.target:GetBonePosition(aimbot.target:GetHitBoxBone(0, 0))

		-- If targets have a model we don't have, bones wont be loaded clientside. We're going to have to
		-- just use their origin and lift it a little (constant offset since everything uses the error model)
		if targetPos == aimbot.target:GetPos() then
			targetPos = aimbot.target:GetPos() + Vector(0, 0, 50)
		end

		local selfVelPredict = lp:GetVelocity() * config.get("aimbot", "selfVelocityCompensation")
		targetPos = targetPos - selfVelPredict

		local targetVelPredict = aimbot.target:GetVelocity() * config.get("aimbot", "targetVelocityCompensation")
		targetPos = targetPos + targetVelPredict

		local startPos = lp:GetShootPos()
		local aimAngle = (targetPos - startPos):Angle()

		-- compute PID outputs
		local currentViewAngles = lp:EyeAngles()
		local currentPitch, currentYaw, _ = currentViewAngles:Unpack()
		local pitchTarget, yawTarget, _ = aimAngle:Unpack()
		currentPitch = normalizeAngle(currentPitch)
		currentYaw = normalizeAngle(currentYaw)
		pitchTarget = normalizeAngle(pitchTarget)
		yawTarget = normalizeAngle(yawTarget)

		local pitchOutput = aimbot.pitch_pid:compute(pitchTarget, currentPitch, dt)
		local yawOutput = aimbot.yaw_pid:compute(yawTarget, currentYaw, dt)
		currentViewAngles:SetUnpacked(
			currentPitch + pitchOutput * dt,
			currentYaw + yawOutput * dt,
			0
		)
		lp:SetEyeAngles(currentViewAngles)
	end
end

return aimbot, { draw = draw }
