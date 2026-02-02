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

local modulesToLoad = {
	"aimbot",
	"esp",
	"bhop",
	"antiscreengrab", --doesnt function like a normal module, just for gui hints
	"freecam",
}

--hooks for modules to supply
local moduleHooks = {
	draw = {}, --rendering hooks
	think = {}, --doesnt work? wtf
	move = {},
}

local function loadModule(moduleName)
	lje.con_print("[AF] Loading module: " .. moduleName)
	data, hooks = unpack({ lje.include("module/" .. moduleName .. ".lua") })

	if data == nil then
		lje.con_print("[AF] Failed to load module: " .. moduleName)
		return
	end

	modules[moduleName] = data
	modules[moduleName].enabled = data.enabled or false

	local enabledModules = config.get("main", "enabledModules")
	if enabledModules then
		modules[moduleName].enabled = enabledModules[moduleName] or false
	end

	if hooks == nil then
		lje.con_print("[AF] No hooks!")
		return
	end

	for hook, func in pairs(hooks) do
		if moduleHooks[hook] then
			moduleHooks[hook][moduleName] = func
		else
			lje.con_print("[AF]" .. name .. " tried to use an invalid hook: " .. hook)
		end
	end
end

for idx, moduleName in ipairs(modulesToLoad) do
	loadModule(moduleName)
end

local function switchModule(moduleName, mode)
	if moduleName and af.modules[moduleName] then
		if mode == "enable" then
			af.modules[moduleName].enabled = true
		elseif mode == "disable" then
			af.modules[moduleName].enabled = false
		elseif mode == "toggle" then
			af.modules[moduleName].enabled = not af.modules[moduleName].enabled
		end
		local enabledModules = config.get("main", "enabledModules")
		enabledModules[moduleName] = af.modules[moduleName].enabled
		config.set("main", "enabledModules", enabledModules)
	else
		print("That module doesnt exist!")
	end
end

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

function getKeys(tbl)
	local keys = {}
	local id = 1

	for k, v in pairs(tbl) do
		keys[id] = k
		id = id + 1
	end

	return keys
end

af.commands = lje.include("service/commands.lua")
af.commands.tree = {
	info = function()
		print(string.format("%s (version %s)", af.info.name, af.info.version))
	end,
	modules = {
		toggle = function(moduleName)
			switchModule(moduleName, "toggle")
		end,

		enable = function(moduleName)
			switchModule(moduleName, "enable")
		end,

		disable = function(moduleName)
			switchModule(moduleName, "disable")
		end,

		["config"] = {
			set = function(moduleName, key, value)
				local value = coerce(value)
				local ret = config.set(moduleName, key, value)
				if type(ret) ~= type(value) then
					print("Wrong type, expected: " .. type(ret))
				elseif ret ~= value and ret and value and type(ret) == "number" then
					print("Number was either too large or too small, please try again")
				end
			end,

			list = function(moduleName)
				if not moduleName then
					print(
						string.format("Configurable modules available:\n%s", table.concat(getKeys(config.cache), ", "))
					)
				else
					local output = ""
					for optionName, optionData in pairs(config.cache[moduleName]) do
						output = output .. string.format("\n%s: %s", optionName, tostring(optionData.value))
					end
					print(string.format("Options available:%s", output))
				end
			end,
		},
	},
}
af.commands.attachHelp(af.commands.tree, {})

af.concmdAdd("antifreeze", "Main Antifreeze command", 0, function(_, _, args, argsStr)
	af.commands.dispatch(af.commands.tree, args)
end)

function printTable(t, indent, seen)
	indent = indent or 0
	seen = seen or {}

	if seen[t] then
		lje.con_print(string.rep("  ", indent) .. "*cycle*")
		return
	end
	seen[t] = true

	for k, v in pairs(t) do
		local prefix = string.rep("  ", indent) .. tostring(k) .. ": "
		if type(v) == "table" then
			lje.con_print(prefix .. "{")
			printTable(v, indent + 1, seen)
			lje.con_print(string.rep("  ", indent) .. "}")
		else
			lje.con_print(prefix .. tostring(v))
		end
	end
end

if af.debug then
	lje.con_print("modules:")
	printTable(modules)
	lje.con_print("module hooks:")
	printTable(moduleHooks)
	lje.con_print("config cache:")
	printTable(config.cache)
end

--local acculmativeMenuSize = 0

hook.pre("ljeutil/render", "antifreeze.ui", function()
	if not af.ignoreMainMenu and gui.IsGameUIVisible() then
		return
	end
	--local mx, my = glui.beginInput()

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

	if modules.antiscreengrab.isScreengrabRecent() then
		surface.SetTextPos(10, curY)
		surface.SetTextColor(255, math.sin(SysTime() * 15) * 127 + 128, 255, 255)
		surface.DrawText(string.format("Screengrabbed %.1f seconds ago!", modules.antiscreengrab.timeSinceScreengrab()))
		curY = curY + 20
	end

	surface.SetTextPos(10, curY)
	surface.SetTextColor(af.brand.color)
	surface.DrawText(string.format("GC Memory: %d B", lje.gc.get_total()))
	curY = curY + 20

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

local MOVEMENT_BUTTONS = IN_FORWARD + IN_BACK + IN_MOVELEFT + IN_MOVERIGHT + IN_JUMP + IN_DUCK + IN_SPEED + IN_WALK

local function disableMovement(buttons)
	return bit.band(buttons, bit.bnot(MOVEMENT_BUTTONS))
end

--todo: keybind manager/ui toggle
hook.pre("CreateMove", "antifreeze.move", function(cmd)
	for moduleName, moveFunction in pairs(moduleHooks.move) do
		if modules[moduleName].enabled then
			moveFunction(cmd)
		end
	end

	if modules.freecam.enabled then
		--clear movement so we're not walking off cliffs while freecaming
		cmd:ClearMovement()
		cmd:SetButtons(disableMovement(cmd:GetButtons()))

		--recoil isnt aplied while in freecam, removes a detection vector
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_ATTACK + IN_ATTACK2)))
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

return af
