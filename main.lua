local af = af or {}

af.info = {}
af.info.version = "1.2.0"
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
af.brand.color = Color(127, 255, 255)

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

af.modules = af.modules or {}
af.moduleSections = af.moduleSections or {}

local config = lje.require("service/config.lua")
config.init("main", {
	enabledModules = { value = {
		esp = true,
		aimbot = false,
		bhop = false,
		freecam = false,
	} },
})

af.config = config

--too many sources of truth? main config and af.modules
function af.switchModule(moduleName, switch, temp)
	if not (moduleName and af.modules[moduleName]) then
		print("[AF] That module doesnt exist!")
		return nil
	end

	local moduleTable = af.modules[moduleName]
	local state = moduleTable.enabled or false

	-- toggle if switch is nil
	if switch == nil then
		switch = not state
	end

	-- no state change, nothing to do
	if state == switch then
		return switch
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
	config.set("main", "enabledModules", enabledModules, temp)
	return switch
end

af.commands = af.commands or lje.include("service/commands.lua")
af.commands.tree = {
	info = function()
		print(string.format("%s (version %s)", af.info.name, af.info.version))
	end,
	modules = {
		list = function()
			print(string.format("[AF] Modules:\n%s", table.concat(getKeys(af.modules), ", ")))
		end,
		info = function(moduleName)
			local data = af.modules[moduleName]
			if not data then
				print("[AF] Unknown module!")
			else
				if data.moduleInfo then
					print(
						string.format(
							"[AF] Info for %s:\nDescription: %s\nSection: %s",
							data.moduleInfo.name,
							data.moduleInfo.description,
							data.moduleInfo.section
						)
					)
				else
					print("[AF] No other data for this module.")
				end
			end
		end,
		toggle = function(moduleName)
			af.switchModule(moduleName, nil, true)
		end,

		enable = function(moduleName)
			af.switchModule(moduleName, true, true)
		end,

		disable = function(moduleName)
			af.switchModule(moduleName, false, true)
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

	af.modules[name] = data
	af.modules[name].enabled = data.enabled or false

	if data.moduleInfo then
		local key = data.moduleInfo.section
		if key ~= "none" then
			key = key or "other" --handle non-defined sections
			af.moduleSections[key] = af.moduleSections[key] or {}
			af.moduleSections[key][name] = true
		end
	end

	--enable modules if they were enabled before
	local enabledModules = config.get("main", "enabledModules")
	if enabledModules then
		af.modules[name].enabled = enabledModules[name] or false
	end

	if hooks == nil then
		af.log("No hooks!", af.level.debug)
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

function af.printTable(t, indent, seen)
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
			af.printTable(v, indent + 1, seen)
			af.log(string.rep("  ", indent) .. "}", af.level.debug)
		else
			af.log(prefix .. tostring(v), af.level.debug)
		end
	end
end

if af.debug then
	af.log("modules:", af.level.debug)
	af.printTable(af.modules)
	af.log("module hooks:", af.level.debug)
	af.printTable(moduleHooks)
	af.log("config cache:", af.level.debug)
	af.printTable(config.cache)
end


local ui = lje.include("service/ui.lua")

hook.pre("ljeutil/render", "antifreeze.ui", function()
	if not af.ignoreMainMenu and gui.IsGameUIVisible() then
		return
	end

	cam.Start2D()
	render.PushRenderTarget(lje.util.rendertarget)

	ui.drawOverlay()

	for moduleName, renderFunction in pairs(moduleHooks.draw) do
		if af.modules[moduleName].enabled then
			renderFunction()
		end
	end

	render.PopRenderTarget()
	cam.End2D()
end)

hook.pre("think", "antifreeze.think", function()
	for moduleName, thinkFunction in pairs(moduleHooks.think) do
		if af.modules[moduleName].enabled then
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
	return bit.band(buttons, bit.bnot(FREEZE_BUTTONS))
end

hook.pre("CreateMove", "antifreeze.move", function(cmd)
	for moduleName, moveFunction in pairs(moduleHooks.move) do
		if af.modules[moduleName].enabled then
			moveFunction(cmd)
		end
	end

	--todo: move to freecam module
	if af.modules.freecam.enabled then
		--clear movement so we're not walking off cliffs while freecaming
		cmd:ClearMovement()
		cmd:SetButtons(freezeButtons(cmd:GetButtons()))
		cmd:SetViewAngles(af.modules.freecam.startAngles)
	end
end)

hook.pre("InputMouseApply", "antifreeze.freecam.freeze", function(cmd, x, y, ang)
	if af.modules.freecam.enabled then
		cmd:SetMouseX(0)
		cmd:SetMouseY(0)

		af.modules.freecam.currentAngles[1] = math.Clamp(af.modules.freecam.currentAngles[1] + y / 50, -89, 89)
		af.modules.freecam.currentAngles[2] = af.modules.freecam.currentAngles[2] - x / 50
	end
end)

lje.con_printf("$cyan{\n" .. af.brand.watermark .. "\n}")
