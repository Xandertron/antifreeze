local af = af or {}

af.debug = false --debug prints, etc

af.info = {}
af.info.version = "1.1.0"
af.info.name = "Antifreeze"

af.brand = {}
af.brand.watermark = [[
  /$$$$$$  /$$   /$$ /$$$$$$$$ /$$$$$$ /$$$$$$$$ /$$$$$$$  /$$$$$$$$ /$$$$$$$$ /$$$$$$$$ /$$$$$$$$
 /$$__  $$| $$$ | $$|__  $$__/|_  $$_/| $$_____/| $$__  $$| $$_____/| $$_____/|_____ $$ | $$_____/
| $$  \ $$| $$$$| $$   | $$     | $$  | $$      | $$  \ $$| $$      | $$           /$$/ | $$      
| $$$$$$$$| $$ $$ $$   | $$     | $$  | $$$$$   | $$$$$$$/| $$$$$   | $$$$$       /$$/  | $$$$$   
| $$__  $$| $$  $$$$   | $$     | $$  | $$__/   | $$__  $$| $$__/   | $$__/      /$$/   | $$__/   
| $$  | $$| $$\  $$$   | $$     | $$  | $$      | $$  \ $$| $$      | $$        /$$/    | $$      
| $$  | $$| $$ \  $$   | $$    /$$$$$$| $$      | $$  | $$| $$$$$$$$| $$$$$$$$ /$$$$$$$$| $$$$$$$$
|__/  |__/|__/  \__/   |__/   |______/|__/      |__/  |__/|________/|________/|________/|________/
]]
af.brand.name = "Antifreeze"
af.brand.color = Color(127, 255, 255)
--[[af.brand.gluiStyle = {
	other = {
		titleHeight = 20,
		border = col(255, 255, 255, 255),
		helpText = col(255, 255, 255, 255),
	},

	text = {
		normal = col(255, 255, 255, 255),
		disabled = col(128, 128, 128, 255),
	},

	button = {
		frame = col(35, 35, 35, 255),
		hover = col(50, 50, 50, 255),
		press = col(80, 80, 80, 255),
		text = col(215, 215, 215, 255),
	},

	tab = {
		frame = col(35, 35, 35, 255),
		hover = col(50, 50, 50, 255),
		press = col(80, 80, 80, 255),
		btn_frame = col(143, 1, 20, 255),
		text = col(215, 215, 215, 255),
	},

	title = {
		frame = col(82, 146, 146, 127),
		hover = col(50, 50, 50, 255),
		press = col(80, 80, 80, 255),
		text = col(215, 215, 215, 255),
	},

	window = {
		frame = col(127, 255, 255, 127),
	},
}]]
--

lje.include("service/concommand.lua")

local function coerce(str)
	if type(str) ~= "string" then
		return str
	end

	local lower = string.lower(str)

	if lower == "true" then
		return true
	end
	if lower == "false" then
		return false
	end
	if lower == "nil" then
		return nil
	end

	local num = tonumber(str)
	if num ~= nil then
		return num
	end

	return str
end

local function getKeys(tbl)
	local keys = {}
	local id = 1

	for k, v in pairs(tbl) do
		keys[id] = k
		id = id + 1
	end

	return keys
end

af.commands = af.commands or lje.include("service/commands.lua")
af.commands.tree = {
	info = function()
		print(string.format("%s (version %s)", af.info.name, af.info.version))
	end,
	modules = {
		toggle = function(moduleName)
			switchModule(moduleName)
		end,

		enable = function(moduleName)
			switchModule(moduleName, true)
		end,

		disable = function(moduleName)
			switchModule(moduleName, false)
		end,

		["config"] = {
			set = function(moduleName, key, value)
				local value = coerce(value)
				local ret = config.set(moduleName, key, value)
				if type(ret) ~= type(value) then
					print("[AF] Wrong type, expected: " .. type(ret))
				elseif ret ~= value and ret and value and type(ret) == "number" then
					print("[AF] Number was either too large or too small, please try again")
				end
			end,

			list = function(moduleName)
				if not moduleName then
					print(
						string.format(
							"[AF] Configurable modules available:\n%s",
							table.concat(getKeys(config.cache), ", ")
						)
					)
				else
					local output = ""
					for optionName, optionData in pairs(config.cache[moduleName]) do
						output = output .. string.format("\n%s: %s", optionName, tostring(optionData.value))
					end
					print(string.format("[AF] Options available:%s", output))
				end
			end,
		},
	},
}
af.commands.attachHelp(af.commands.tree, {})

af.concmdAdd("antifreeze", "Main Antifreeze command", 0, function(_, _, args, argsStr)
	af.commands.dispatch(af.commands.tree, args)
end)

local modules = {}
af.modules = modules

local config = lje.require("service/config.lua")
config.init("main", {
	enabledModules = { value = {
		esp = true,
		aimbot = false,
		bhop = false,
		freecam = false,
	} },
	keybinds = { value = {} },
})

af.config = config

--hooks for modules to supply
local moduleHooks = {
	draw = {}, --rendering hooks
	think = {}, --doesnt work? wtf
	move = {},
}

function af.loadModule(name, data, hooks)
	if data == nil then
		af.log("No data for: " .. name, af.level.WARN)
		return
	end

	modules[name] = data
	modules[name].enabled = data.enabled or false

	local enabledModules = config.get("main", "enabledModules")
	if enabledModules then
		modules[name].enabled = enabledModules[name] or false
	end

	if hooks == nil then
		af.log("No hooks!", af.level.warn)
		return
	end

	for hook, func in pairs(hooks) do
		if moduleHooks[hook] then
			moduleHooks[hook][name] = func
		else
			af.log(name .. " tried to use an invalid hook: " .. hook, af.level.warn)
		end
	end
end

local modulesToLoad = lje.env.find_script_files("module/*")

for idx, path in ipairs(modulesToLoad) do
	local moduleName = string.match(path, "^module/([^/]+)%.lua$")
	af.log("Loading internal module: " .. moduleName)
	data, hooks = unpack({ lje.include(path) })
	af.loadModule(moduleName, data, hooks)
end

local function switchModule(moduleName, switch)
	if not (moduleName and af.modules[moduleName]) then
		print("[AF] That module doesnt exist!")
		return
	end

	local moduleTable = af.modules[moduleName]
	local state = moduleTable.enabled or false

	-- toggle if switch is nil
	if switch == nil then
		switch = not state
	end

	-- no state change, nothing to do
	if state == switch then
		return
	end

	-- rising and falling edge
	if not state and switch then
		if moduleTable.onEnable then
			moduleTable.onEnable()
		end
	elseif state and not switch then
		if moduleTable.onDisable then
			moduleTable.onDisable()
		end
	end

	-- update runtime state
	moduleTable.enabled = switch

	-- persist state
	local enabledModules = config.get("main", "enabledModules")
	enabledModules[moduleName] = switch
	config.set("main", "enabledModules", enabledModules)
end

function printTable(t, indent, seen)
	indent = indent or 0
	seen = seen or {}

	if seen[t] then
		af.log(string.rep("  ", indent) .. "*cycle*", af.level.debug)
		return
	end
	seen[t] = true

	for k, v in pairs(t) do
		local prefix = string.rep("  ", indent) .. tostring(k) .. ": "
		if type(v) == "table" then
			af.log(prefix .. "{", af.level.debug)
			printTable(v, indent + 1, seen)
			af.log(string.rep("  ", indent) .. "}", af.level.debug)
		else
			af.log(prefix .. tostring(v), af.level.debug)
		end
	end
end

if af.debug then
	af.log("modules:", af.level.debug)
	printTable(modules)
	af.log("module hooks:", af.level.debug)
	printTable(moduleHooks)
	af.log("config cache:", af.level.debug)
	printTable(config.cache)
end

--local acculmativeMenuSize = 0
local color = Color(255, 0, 0, 255)

hook.pre("ljeutil/render", "antifreeze.ui", function()
	if not af.ignoreMainMenu and gui.IsGameUIVisible() then
		return
	end

	cam.Start2D()
	render.PushRenderTarget(lje.util.rendertarget)
	surface.SetFont("ChatFont")
	surface.SetTextPos(10, 10)
	surface.SetTextColor(af.brand.color)
	surface.DrawText("Antifreeze - LJE")

	local curY = 30

	if modules.aimbot.target then
		surface.SetTextPos(10, curY)
		surface.DrawText("Aimbot Target: " .. modules.aimbot.target:Nick())
		curY = curY + 20
	end

	if modules.antiscreengrab.isScreengrabRecent() or af.debug then
		local timeSince = modules.antiscreengrab.timeSinceScreengrab()
		surface.SetTextPos(10, curY)
		local c = timeSince <= 30 and (math.sin(SysTime() * 15) * 127 + 128) or 127
		surface.SetTextColor(c, 255, 255, 255)
		surface.DrawText(string.format("Screengrabbed %.1f seconds ago!", timeSince))
		curY = curY + 20
	end

	surface.SetTextPos(10, curY)
	surface.SetTextColor(af.brand.color)
	surface.DrawText(string.format("GC Memory: %d B", lje.gc.get_total()))
	curY = curY + 20

	----
	--ui shit
	----

	imgui.new_frame()
	if imgui.is_visible() then
		local visible, open = imgui.begin_window("test")

		imgui.text("hello world!")

		imgui.end_window()
	end
	imgui.render()

	--glui.style(af.brand.gluiStyle)
	--[[glui.draw.beginWindow("mainWindow", "Utility Mod", 10, curY, 400, acculmativeMenuSize)
	local menuY = 10
	local showSliders = glui.draw.checkbox("config.sliders.toggle", "Show sliders", 20, menuY, nil, nil)
	for moduleName, data in pairs(config.cache) do
		if modules[moduleName] then
			local id = "config." .. tostring(moduleName) .. ".toggle"
			menuY = menuY + 20
			local checked = glui.draw.checkbox(id, modules[moduleName].name or moduleName, 20, menuY, nil, nil, modules[moduleName].enabled)
			modules[moduleName].enabled = checked
			config.cache["main"].enabledModules[moduleName] = checked
			for optionName, optionData in pairs(config.cache[moduleName]) do
				local id = "config." .. tostring(moduleName) .. "." .. optionName
				if type(optionData.value) == "boolean" then
					menuY = menuY + 20
					config.cache[moduleName][optionName].value = glui.draw.checkbox(id, optionName, 40, menuY, nil, nil)
				elseif type(optionData.value) == "number" and showSliders then
					menuY = menuY + 20
					local sliderValue = glui.draw.slider(
						id,
						40,
						menuY,
						200,
						16,
						optionData.min or 0,
						optionData.max or 100,
						optionData.value
					)
					config.cache[moduleName][optionName].value = sliderValue
					menuY = menuY + 20
					glui.draw.label(optionName .. ": " .. tostring(math.ceil(sliderValue * 100) / 100), 40, menuY)
				end
			end
		end
	end
	menuY = menuY + 40 + 10
	acculmativeMenuSize = menuY
	glui.draw.endWindow()
	]]

	for moduleName, renderFunction in pairs(moduleHooks.draw) do
		if modules[moduleName].enabled then
			renderFunction()
		end
	end

	render.PopRenderTarget()
	cam.End2D()
end)

hook.pre("think", "antifreeze.think", function()
	for moduleName, thinkFunction in pairs(moduleHooks.think) do
		if modules[moduleName].enabled then
			thinkFunction()
		end
	end
end)

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
	return bit.band(buttons, bit.bnot(MOVEMENT_BUTTONS))
end

hook.pre("CreateMove", "antifreeze.move", function(cmd)
	for moduleName, moveFunction in pairs(moduleHooks.move) do
		if modules[moduleName].enabled then
			moveFunction(cmd)
		end
	end

	if modules.freecam.enabled then
		--clear movement so we're not walking off cliffs while freecaming
		cmd:ClearMovement()
		cmd:SetButtons(freezeButtons(cmd:GetButtons()))
		cmd:SetViewAngles(modules.freecam.startAngles)
	end
end)

hook.pre("InputMouseApply", "antifreeze.freecam.freeze", function(cmd, x, y, ang)
	if modules.freecam.enabled then
		cmd:SetMouseX(0)
		cmd:SetMouseY(0)

		modules.freecam.currentAngles[1] = math.Clamp(modules.freecam.currentAngles[1] + y / 50, -89, 89)
		modules.freecam.currentAngles[2] = modules.freecam.currentAngles[2] - x / 50
	end
end)

lje.con_printf("$cyan{\n" .. af.brand.watermark .. "\n}")
