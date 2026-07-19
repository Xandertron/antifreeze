local freecam = {}

freecam.moduleInfo = {
	name = "Freecam",
	description = "Detach from your body, and fly through walls. (Potentionally detectable)",
	section = "render",
}

local cfg = af.config.register("freecam", {
	camSpeed = { value = 500, min = 0, max = 2000 },
	fov = { value = 75, min = 1, max = 360 },
	redrawEntities = { value = false },
	redrawDistance = { value = 4096, min = 1, max = 30000 },
})

freecam.currentPosition = Vector()
freecam.currentAngles = Angle()
freecam.startAngles = Angle()
freecam.enabled = false
freecam.lastScroll = 0

local function lerp(a, b, t)
	return a + (b - a) * t
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

		freecam.currentAngles[1] = math.clamp(freecam.currentAngles[1] + y / 50, -89, 89)
		freecam.currentAngles[2] = freecam.currentAngles[2] - x / 50
	end
end)

local w = ScrW()
local h = ScrH()

local function randomString(length)
    length = length or 32
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local result = {}
    for i = 1, length do
        local idx = math.random(1, #chars)
        result[i] = chars:sub(idx, idx)
    end
    return table.concat(result)
end

math.randomseed(os.time())
local freecamRTIndex = randomString(24)
local freecamMatIndex = randomString(24)

local freecamRT = GetRenderTarget(freecamRTIndex, ScrW(), ScrH())
local freecamMat = CreateMaterial(freecamMatIndex, "UnlitGeneric", {
	["$basetexture"] = freecamRTIndex,
})

function freecam:prerender()
	render.PushRenderTarget(freecamRT)
	render.Clear(0, 0, 0, 255, true, true)
	render.SetViewPort(0, 0, ScrW(), ScrH())
	render.RenderView({
		origin = freecam.lerpTargetPosition,
		angles = freecam.currentAngles,
		fov = cfg.fov,
		drawviewer = true,
		w = w,
		h = h,
	})
	render.PopRenderTarget()

	if cfg.redrawEntities then
		render.SetBlend(1)
		render.SetColorModulation(1, 1, 1)

		for _, ent in ipairs(ents.GetAll()) do
			if ent:IsValid() then
				local dist = ent:GetPos():DistToSqr(freecam.lerpTargetPosition)
				if dist < cfg.redrawDistance ^ 2 then
					ent:DrawModel()
				end
			end
		end
	end
    
	surface.SetMaterial(freecamMat)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end

return freecam
