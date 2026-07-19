local spam = spam or {}

spam.moduleInfo = {
	name = "Spam",
	description = "Spam various things",
	section = "other",
}

local cfg = af.config.register("spam", {
	flashlight = { value = false },
	mouse = { value = false },
	use = { value = false },
	cooldown = { value = 0.15, min = 0.01, max = 1 },
})

local cooldownTime = 0

local function canRun()
	local can = CurTime() >= cooldownTime
	if can then
		cooldownTime = CurTime() + cfg.cooldown
	end
	return can
end

local useToggle = false

function spam:run()
	if canRun() then
		if cfg.flashlight and input.IsKeyDown(KEY_F) then
			RunConsoleCommand("impulse", "100")
		end
		if cfg.use and input.IsKeyDown(KEY_E) then
			if canRun then
				useToggle = not useToggle
				RunConsoleCommand(useToggle and "+use" or "-use")
			end
		end
	end
end

function spam:move(cmd)
	if cfg.mouse then
		if LocalPlayer():KeyDown(IN_ATTACK2) then
			cmd:RemoveKey(IN_ATTACK2)
		end

		if LocalPlayer():KeyDown(IN_ATTACK) then
			cmd:RemoveKey(IN_ATTACK)
		end
	end
end

return spam
