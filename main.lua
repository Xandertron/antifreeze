local lje = lje or {}
local environment = lje.env.get()

local glui = glui

local af = af or {}

af.brand = af.brand or {}
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
af.brand.gluiStyle = {
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
}

environment.af = af

-- Hooks are always disabled during the execution of this script.
-- They re-enable as soon as this script finishes.

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

local function toggleValue(value, enabled)
	if enabled ~= nil then
		return enabled
	else
		return not value
	end
	return false
end

local config = lje.require("service/config.lua")
config.init("main", {
	enabledModules = { value = {
		esp = true,
		aimbot = true,
		bhop = true,
		freecam = false,
	} },
	keybinds = { value = {} },
})

local modulesToLoad = {
	"aimbot",
	"esp",
	"bhop",
	"antiscreengrab", --doesnt function like a normal module, just for gui hints
	"freecam",
}

local modules = {}

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

lje.con_print("modules:")
printTable(modules)
lje.con_print("module hooks:")
printTable(moduleHooks)
lje.con_print("config cache:")
printTable(config.cache)

local acculmativeMenuSize = 0

hook.pre("ljeutil/render", "antifreeze.ui", function()
	local mx, my = glui.beginInput()

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

	glui.style(af.brand.gluiStyle)
	glui.draw.beginWindow("mainWindow", "Utility Mod", 10, curY, 400, acculmativeMenuSize)
	local menuY = -10
	for moduleName, data in pairs(config.cache) do
		if modules[moduleName] then
			local id = "configmenu." .. tostring(moduleName) .. ".toggle"
			menuY = menuY + 20
			local checked = glui.draw.checkbox(id, moduleName, 20, menuY, nil, nil)
			modules[moduleName].enabled = checked
			config.cache["main"].enabledModules[moduleName] = checked
			for optionName, optionData in pairs(config.cache[moduleName]) do
				local id = "configmenu." .. tostring(moduleName) .. "." .. optionName
				if type(optionData.value) == "boolean" then
					menuY = menuY + 20
					config.cache[moduleName][optionName].value = glui.draw.checkbox(id, optionName, 40, menuY, nil, nil)
				elseif type(optionData.value) == "number" then
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

lje.con_printf("$cyan{Antifreeze} initialized successfully.")

return af
