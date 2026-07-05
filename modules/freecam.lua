local freecam =  {}

freecam.moduleInfo = {
	name = "Freecam",
	description = "Detach from your body, and fly through walls. (Potentionally detectable)",
	section = "render",
}

local cfg = af.config.register("freecam", {
	camSpeed = { value = 500, min = 0, max = 2000 },
    fov = { value = 75, min = 1, max = 360}
})

freecam.currentPosition = Vector()
freecam.currentAngles = Angle()
freecam.startAngles = Angle()
freecam.enabled = false
freecam.lastScroll = 0

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp( _in, low, high )
	return math.min( math.max( _in, low ), high )
end

function freecam:onEnable()
	freecam.currentPosition = LocalPlayer():GetPos() + Vector(0, 0, 64) -- Starts at eye level
	freecam.lerpTargetPosition = freecam.currentPosition
	freecam.lerpFOV = cfg.fov
	freecam.startAngles = LocalPlayer():EyeAngles()
	freecam.currentAngles = Angle(LocalPlayer():EyeAngles())
end

function freecam:run()
	local ft = FrameTime()
	local speed = cfg.camSpeed * ft

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

function freecam:move(cmd)
	if freecam.enabled then
		--clear movement so we're not walking off cliffs while freecaming
		cmd:ClearMovement()
		cmd:SetButtons(freezeButtons(cmd:GetButtons()))
		cmd:SetViewAngles(freecam.startAngles)
	end
end

hook.Add("InputMouseApply", "antifreeze.freecam.freeze", function(cmd, x, y, ang)
	cmd = lje.proxy.copy(cmd)
	if freecam.enabled then
		cmd:SetMouseX(0)
		cmd:SetMouseY(0)

		freecam.currentAngles[1] = clamp(freecam.currentAngles[1] + y / 50, -89, 89)
		freecam.currentAngles[2] = freecam.currentAngles[2] - x / 50
	end
end)

local w = ScrW()
local h = ScrH()

local FreecamRT = GetRenderTarget("freecam_rt", ScrW(), ScrH())

local freecamMat = CreateMaterial("freecam_rt_material", "UnlitGeneric", {
    ["$basetexture"] = "freecam_rt",
    ["$vertexcolor"] = 1,
    ["$vertexalpha"] = 1,
    ["$ignorez"] = 1,
})

function freecam:render()
	render.PushRenderTarget(FreecamRT)
	render.Clear(0, 0, 0, 255, true, true)
	render.SetViewPort(0, 0, ScrW(), ScrH())
	render.RenderView({
		origin = freecam.lerpTargetPosition,
		angles = freecam.currentAngles,
		fov = cfg.fov,
		drawviewmodel = false,
        drawhud = true,
        drawviewer = true,
		w = w,
		h = h,
	})
	render.PopRenderTarget()
    surface.SetMaterial(freecamMat)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end

return freecam
