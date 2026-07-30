commands = commands or {}
commands.registry = commands.registry or {}
commands.log = commands.log or {}

local MAX_LOG_LINES = 500

local function appendLog(text, isError)
	commands.log[#commands.log + 1] = { text = text, isError = isError or false }
	if #commands.log > MAX_LOG_LINES then
		table.remove(commands.log, 1)
	end
end

function commands.print(text, isError)
	appendLog(text, isError)
end

function commands.register(name, description, func)
	commands.registry[name] = { description = description or "", func = func }
end

function commands.clear()
	commands.log = {}
end

function commands.run(line)
	line = line:match("^%s*(.-)%s*$")

	if line == "" then
		return
	end

	appendLog("> " .. line)

	local name, argsStr = line:match("^(%S+)%s*(.-)$")
	local entry = commands.registry[name]

	if not entry then
		appendLog("Unknown command: " .. name .. " (try \"help\")", true)
		return
	end

	local ok, result = pcall(entry.func, argsStr)
	if not ok then
		appendLog("Error: " .. tostring(result), true)
	elseif result ~= nil then
		appendLog(tostring(result))
	end
end

commands.register("help", "Lists every registered command.", function()
	local names = {}
	for name in pairs(commands.registry) do
		names[#names + 1] = name
	end
	table.sort(names)

	for _, name in ipairs(names) do
		appendLog(string.format("  %s - %s", name, commands.registry[name].description))
	end
end)

commands.register("clear", "Clears this console's output.", function()
	commands.clear()
end)

commands.register("lua", "Runs Lua in this script's environment. Bare expressions auto-return.", function(argsStr)
	if argsStr == "" then
		return "Usage: lua <code>"
	end

	-- try it as-is (statements, e.g. "print('hi')") before falling back to
	-- treating it as a bare expression (e.g. "1 + 1") that needs a return
	local func = lje.func.compile(argsStr) or lje.func.compile("return " .. argsStr)
	if not func then
		return "Compile error (see console)."
	end

	local ok, result = pcall(func)
	if not ok then
		return "Runtime error: " .. tostring(result)
	end

	if result ~= nil then
		return tostring(result)
	end
end)

commands.register("echo", "Prints back whatever you typed.", function(argsStr)
	return argsStr
end)

commands.register("calc", "Evaluates a math expression, e.g. \"calc 2 + 2 * 10\".", function(argsStr)
	if argsStr == "" then
		return "Usage: calc <expression>"
	end

	local func = lje.func.compile("return " .. argsStr)
	if not func then
		return "Couldn't parse that as an expression."
	end

	local ok, result = pcall(func)
	if not ok then
		return "Error: " .. tostring(result)
	end

	return tostring(result)
end)

commands.register("roll", "Rolls a die, e.g. \"roll 20\" for a d20 (default d6).", function(argsStr)
	local sides = tonumber(argsStr) or 6
	if sides < 2 then
		return "Need at least 2 sides."
	end
	return string.format("rolled a d%d: %d", sides, math.random(1, sides))
end)

commands.register("whoami", "Prints info about your current player entity.", function()
	local ply = LocalPlayer()
	local pos = ply:GetPos()
	return string.format(
		"%s | team %d | hp %d | pos (%.0f, %.0f, %.0f)",
		ply:Nick(), ply:Team(), ply:Health(), pos.x, pos.y, pos.z
	)
end)

commands.register("players", "Lists everyone currently on the server.", function()
	for _, ply in ipairs(player.GetAll()) do
		appendLog(string.format(
			"  team %d  %-20s hp %d%s",
			ply:Team(), ply:Nick(), ply:Health(), ply:Alive() and "" or " (dead)"
		))
	end
end)

commands.register("modules", "Lists every loaded module and whether it's enabled.", function()
	local names = {}
	for name in pairs(af.modules) do
		names[#names + 1] = name
	end
	table.sort(names)

	for _, name in ipairs(names) do
		appendLog(string.format("  %-14s %s", name, af.modules[name].enabled and "on" or "off"))
	end
end)

commands.register("toggle", "Enables/disables a module by name, e.g. \"toggle esp\".", function(argsStr)
	if argsStr == "" then
		return "Usage: toggle <module>"
	end

	local newState = af.switchModule(argsStr)
	if newState == nil then
		return "No such module: " .. argsStr
	end

	return argsStr .. " -> " .. (newState and "on" or "off")
end)

commands.register("brand", "Reprints the antifreeze watermark.", function()
	for line in (af.brand.watermark .. "\n"):gmatch("(.-)\n") do
		appendLog(line)
	end
end)

return commands
