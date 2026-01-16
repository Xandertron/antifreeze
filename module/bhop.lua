local bhop = bhop or {}

bhop.name = "Bunny Hop"
bhop.description = "Jumps on contact with ground, while jumping. Like a bunny."

local conf = lje.require("service/config.lua")
conf.init("bhop", {
	strafingEnabled = { value = false, min = 0, max = 10 },
	strafeSpeed = { value = 1, min = 0, max = 10 },
})
local config = conf.read("bhop")

function move(cmd)
	local ply = LocalPlayer()

	if not cmd:KeyDown(IN_JUMP) or ply:GetMoveType() == MOVETYPE_NOCLIP then
		return
	end

	if not ply:IsOnGround(ply) then
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_JUMP)))
		-- Strafing
		if config.strafingEnabled then
			-- Just strafe really, really fast left/right (alternating every frame
			-- So, for left strafe, hold down A, move view angle to the left
			-- For right strafe, hold down D, move view angle to the right
			local velocity = ply:GetVelocity()
			local speed = math.sqrt(velocity[1] * velocity[1] + velocity[2] * velocity[2])

			local viewAngles = cmd:GetViewAngles()
			local yaw = viewAngles[2]
			local strafeSpeed = config.strafeSpeed
			if math.fmod(SysTime() * 4.5, 2) < 1 then
				-- Left strafe
				yaw = yaw - strafeSpeed
				cmd:SetSideMove(1000)
			else
				-- Right strafe
				yaw = yaw + strafeSpeed
				cmd:SetSideMove(-1000)
			end
			viewAngles[2] = yaw
			cmd:SetViewAngles(cmd, viewAngles)
		end
	end
end

return bhop, { move = move }
