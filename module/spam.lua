local spam = spam or {}

spam.moduleInfo = {
	name = "Spam",
	description = "Spam various things",
	section = "other",
}

local config = af.config
config.init("spam", {
	flashlight = { value = false },
	mouse = { value = false },
    use = { value = false },
})

local useOn = false

local function draw()
	if config.get("spam", "flashlight") and input.IsKeyDown(KEY_F) then
		RunConsoleCommand("impulse", "100")
	end
    if config.get("spam", "use") and input.IsKeyDown(KEY_E) then
        useOn = not useOn
		RunConsoleCommand(useOn and "+use" or "-use")
	end
end

local function move(cmd)
	if config.get("spam", "mouse") then
		if LocalPlayer():KeyDown(IN_ATTACK2) then
			cmd:RemoveKey(IN_ATTACK2)
		end

		if LocalPlayer():KeyDown(IN_ATTACK) then
			cmd:RemoveKey(IN_ATTACK)
		end
	end
end

return spam, { draw = draw, move = move }
