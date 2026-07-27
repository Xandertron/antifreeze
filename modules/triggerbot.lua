local triggerbot = {}

triggerbot.moduleInfo = {
	name = "Triggerbot",
	description = "Fires when your crosshair lands on an enemy.",
	section = "combat",
}

local cfg = af.config.register("triggerbot", {
	minDelay = { value = 0.05, min = 0, max = 1 },
	maxDelay = { value = 0.18, min = 0, max = 1 },
}, { "requireKey", "minDelay", "maxDelay" })

triggerbot.key = _G["KEY_" .. lje.settings.get("keybinds.triggerbot", "C")]

local onTargetSince = nil
local fireDelay = nil
local shouldFire = false

local function isEnemy(ent)
	return ent and ent:IsValid() and ent:IsPlayer() and ent ~= LocalPlayer() and ent:Alive()
end

local function eyeTrace()
	local ply = LocalPlayer()
	local eyePos = ply:EyePos()
	local aimVec = ply:GetAimVector()

	return util.TraceLine({
		start = eyePos,
		endpos = eyePos + aimVec * 8192,
		filter = ply,
	})
end

local function randRange(min, max)
	return min + math.random() * (max - min)
end

local function reset()
	onTargetSince = nil
	fireDelay = nil
	shouldFire = false
end

function triggerbot:run()
	local tr = eyeTrace()

	if isEnemy(tr.Entity) then
		if not onTargetSince then
			-- pick the reaction delay once per acquisition, not every tick,
			-- so it doesn't jitter true/false near the threshold
			onTargetSince = CurTime()
			fireDelay = randRange(cfg.minDelay, cfg.maxDelay)
		end

		shouldFire = CurTime() - onTargetSince >= fireDelay
	else
		reset()
	end
end

function triggerbot:move(cmd)
	if shouldFire then
		cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
	end
end

function triggerbot:onDisable()
	reset()
end

function triggerbot:cleanup()
	reset()
end

return triggerbot
