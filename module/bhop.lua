local U = cloned_mts.CUserCmd
local E = cloned_mts.Entity

local conf = lje.require("service/config.lua")
conf.init("bhop", {
	strafingEnabled = { value = false, min = 0, max = 10 },
	strafeSpeed = { value = 1, min = 0, max = 10 },
})
local config = conf.read("bhop")

local bhop = {}

function move(cmd)
	-- Auto bunnyhop
	if not U.KeyDown(cmd, IN_JUMP) then
		return
	end

	local ply = LocalPlayer()
	if not E.IsOnGround(ply) then
		U.SetButtons(cmd, bit.band(U.GetButtons(cmd), bit.bnot(IN_JUMP)))
		-- Strafing
		if config.strafingEnabled then
			-- Just strafe really, really fast left/right (alternating every frame
			-- So, for left strafe, hold down A, move view angle to the left
			-- For right strafe, hold down D, move view angle to the right
			local velocity = E.GetVelocity(ply)
			local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)

			local viewAngles = U.GetViewAngles(cmd)
			local yaw = viewAngles.y
			local strafeSpeed = config.strafeSpeed
			if math.fmod(SysTime() * 4.5, 2) < 1 then
				-- Left strafe
				yaw = yaw - strafeSpeed
				U.SetSideMove(cmd, 1000)
			else
				-- Right strafe
				yaw = yaw + strafeSpeed
				U.SetSideMove(cmd, -1000)
			end
			viewAngles.y = yaw
			U.SetViewAngles(cmd, viewAngles)
		end
	end
end

return bhop, {move = move}
