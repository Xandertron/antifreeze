local freecam = freecam or {}
--todo: make these global, all modules

freecam.moduleInfo = {
	name = "Freecam",
	description = "Detach from your body, and fly through walls. (Screengrabbable)",
	section = "render",
}

local config = af.config
config.init("freecam", {
	camSpeed = { value = 500, min = 0, max = 2000 },
})

freecam.currentPosition = Vector()
freecam.currentAngles = Angle()
freecam.startAngles = Angle()
freecam.enabled = false
freecam.lastScroll = 0

local function lerp(a, b, t)
	return a + (b - a) * t
end

function freecam.onEnable()
	freecam.currentPosition = LocalPlayer():GetPos() + Vector(0, 0, 64) -- Starts at eye level
	freecam.lerpTargetPosition = freecam.currentPosition
	freecam.lerpFOV = config.get("freecam", "FOV")
	freecam.startAngles = LocalPlayer():EyeAngles()
	freecam.currentAngles = Angle(LocalPlayer():EyeAngles())
end

local function think()
	if not freecam.enabled then
		return
	end
	local ft = FrameTime()
	local speed = config.get("freecam", "camSpeed") * ft

	if input.IsKeyDown(KEY_LCONTROL) then
		speed = speed / 10
	end

	if input.IsKeyDown(KEY_LSHIFT) then
		speed = speed * 3
	end

	local w = input.IsKeyDown(KEY_W) and 1 or 0
	local a = input.IsKeyDown(KEY_A) and 1 or 0
	local s = input.IsKeyDown(KEY_S) and 1 or 0
	local d = input.IsKeyDown(KEY_D) and 1 or 0
	local jump = input.IsKeyDown(KEY_SPACE) and 1 or 0

	local move = (
		freecam.currentAngles:Forward() * (w - s)
		+ freecam.currentAngles:Right() * (d - a)
		+ Vector(0, 0, jump)
	)

	freecam.currentPosition = freecam.currentPosition + move * speed

	local lerpFactor = 1 - math.exp(-10 * ft)
	if not freecam.lerpTargetPosition or not freecam.currentPosition then
		freecam.onEnable()
	end

	freecam.lerpTargetPosition = LerpVector(lerpFactor, freecam.lerpTargetPosition, freecam.currentPosition)

	--local scroll = input.GetAnalogValue(ANALOG_MOUSE_WHEEL)
	--local deltaScroll = scroll - freecam.lastScroll
	--freecam.lastScroll = scroll

	--freecam.currentFOV = math.Clamp(freecam.current_fov - (deltaScroll * 10), 30, 120)
	--freecam.lerpFOV = lerp(freecam.lerpFOV, freecam.currentFOV, 0.1)
end

local FREEZE_BUTTONS = 0
	+ IN_FORWARD
	+ IN_BACK
	+ IN_MOVELEFT
	+ IN_MOVERIGHT
	+ IN_JUMP
	+ IN_DUCK
	+ IN_SPEED
	+ IN_WALK
	+ IN_ATTACK
	+ IN_ATTACK2

local function freezeButtons(buttons)
	return bit.band(buttons, bit.bnot(FREEZE_BUTTONS))
end

local function move(cmd)
	if freecam.enabled then
		--clear movement so we're not walking off cliffs while freecaming
		cmd:ClearMovement()
		cmd:SetButtons(freezeButtons(cmd:GetButtons()))
		cmd:SetViewAngles(freecam.startAngles)
	end
end

hook.pre("InputMouseApply", "antifreeze.freecam.freeze", function(cmd, x, y, ang)
	if freecam.enabled then
		cmd:SetMouseX(0)
		cmd:SetMouseY(0)

		freecam.currentAngles[1] = math.Clamp(freecam.currentAngles[1] + y / 50, -89, 89)
		freecam.currentAngles[2] = freecam.currentAngles[2] - x / 50
	end
end)

hook.post("CalcView", "antifreeze.freecam.render", function(ply, pos, angles, fov)
	if freecam.enabled then
		return {
			origin = freecam.lerpTargetPosition,
			angles = freecam.currentAngles,
			fov = fov,
			drawviewer = true,
		}
	end
end)

return freecam, { think = think, move = move }
