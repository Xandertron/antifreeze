local P = cloned_mts.Player
local E = cloned_mts.Entity
local V = cloned_mts.Vector
local sub = V.__sub
local add = V.__add
local mul = V.__mul
local A = cloned_mts.Angle

local pid = lje.include("util/pid.lua")

local conf = lje.require("service/config.lua")
conf.init("aimbot", {
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
local config = conf.read("aimbot")

local aimbot = {}
aimbot.target = nil
-- integrals aren't used, because of steady state error not being an issue in aimbot
aimbot.pitch_pid = pid.new(config.pitchResponseP, config.pitchResponseD, config.pitchResponseI, -360, 360)
aimbot.yaw_pid = pid.new(config.yawResponseP, config.yawResponseD, config.yawResponseI, -360, 360)
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
	aimbot.pitch_pid.kp = config.pitchResponseP
	aimbot.yaw_pid.kp = config.yawResponseP
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
				(not E.__eq(ply, LocalPlayer()))
				and V.Distance(E.GetPos(LocalPlayer()), E.GetPos(ply)) <= config.minDistance
				and P.Alive(ply)
			then
				table.insert(qualifiedPlayers, ply)
			end
		end

		if #qualifiedPlayers > 0 then
			local aimVectorForward = P.GetAimVector(LocalPlayer())
			table.sort(qualifiedPlayers, function(a, b)
				local distA = V.Distance(E.GetPos(LocalPlayer()), E.GetPos(a))
				local distB = V.Distance(E.GetPos(LocalPlayer()), E.GetPos(b))

				-- Check dot product to also factor in who we're aiming at
				local toA = E.GetPos(a)
				V.Sub(toA, P.GetShootPos(LocalPlayer()))
				V.Normalize(toA)
				local dotA = V.Dot(aimVectorForward, toA)

				local toB = E.GetPos(b)
				V.Sub(toB, P.GetShootPos(LocalPlayer()))
				V.Normalize(toB)
				local dotB = V.Dot(aimVectorForward, toB)

				distA = distA * (1 - dotA)
				distB = distB * (1 - dotB)
				return distA < distB
			end)

			aimbot.target = qualifiedPlayers[1]
		end
	end

	if aimbot.target and P.Alive(aimbot.target) then
		local lp = LocalPlayer()
		local targetPos = E.GetBonePosition(aimbot.target, E.GetHitBoxBone(aimbot.target, 0, 0))
		local selfVelPredict = mul(E.GetVelocity(lp), config.selfVelocityCompensation)
		targetPos = sub(targetPos, selfVelPredict)

		local targetVelPredict = mul(E.GetVelocity(aimbot.target), config.targetVelocityCompensation)
		targetPos = add(targetPos, targetVelPredict)

		local startPos = P.GetShootPos(lp)
		local aimAngle = (sub(targetPos, startPos)):Angle()

		-- compute PID outputs
		local currentViewAngles = E.EyeAngles(lp)
		local currentPitch, currentYaw, _ = A.Unpack(currentViewAngles)
		local pitchTarget, yawTarget, _ = A.Unpack(aimAngle)
		currentPitch = normalizeAngle(currentPitch)
		currentYaw = normalizeAngle(currentYaw)
		pitchTarget = normalizeAngle(pitchTarget)
		yawTarget = normalizeAngle(yawTarget)

		local pitchOutput = aimbot.pitch_pid:compute(pitchTarget, currentPitch, dt)
		local yawOutput = aimbot.yaw_pid:compute(yawTarget, currentYaw, dt)
		A.SetUnpacked(currentViewAngles, currentPitch + pitchOutput * dt, currentYaw + yawOutput * dt, 0)
		P.SetEyeAngles(lp, currentViewAngles)
	end
end

return aimbot, {draw = draw}
