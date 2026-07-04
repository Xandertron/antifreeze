local bhop = {}

bhop.moduleInfo = {
	name = "Bunny Hop",
	description = "Jumps on contact with ground, while jumping. Like a bunny.",
	section = "movement",
}

function bhop:move(cmd)
	local ply = LocalPlayer()

	if not ply:Alive() or ply:GetMoveType() == MOVETYPE_NOCLIP then
		return
	end

	local onGround = bit.band(ply:GetFlags(), FL_ONGROUND) == FL_ONGROUND
	local wantsJump = bit.band(cmd:GetButtons(), IN_JUMP) == IN_JUMP
	if not onGround and wantsJump then
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_JUMP)))
	end
end

return bhop