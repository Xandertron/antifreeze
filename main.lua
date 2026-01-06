local lje = lje or {}
local p = cloned_mts.Player

local environment = lje.env.get()
local af = af or {}
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

local modulesToLoad = {
	"aimbot",
	"esp",
	"bhop",
	"screengrab",
}

local modules = {}

--hooks for modules to supply
local moduleHooks = {
	draw = {}, --rendering hooks
	think = {}, --doesnt work? wtf
	move = {},
}

local function loadModule(name)
	lje.con_print("[AF] Loading module: " .. name)
	data, hooks = lje.include("module/" .. name .. ".lua")

	if data == nil then
		lje.con_print("[AF] Failed to load module: " .. name)
		return
	end

	modules[name] = data

	if hooks == nil then
		return
	end

	for hook, func in pairs(hooks) do
		if moduleHooks[hook] then
			table.insert(moduleHooks[hook], func)
		else
			lje.con_print("[AF]" .. name .. " tried to load an invalid hook: " .. hook)
		end
	end
end

for idx, moduleName in ipairs(modulesToLoad) do
	loadModule(moduleName)
end

printTable(modules)
printTable(moduleHooks)

local conf = lje.require("service/config.lua")

printTable(conf.cache)

--local glui = lje.include("library/glui/main.lua")

hook.pre("ljeutil/render", "antifreeze.ui", function()
	lje.env.disable_metatables() -- Prevent anyone from detecting us via metatables
	lje.env.save_random_state() -- Save random state to avoid detection via PRNG state

	--local mx, my = glui.beginInput()

	cam.Start2D()
	render.PushRenderTarget(lje.util.rendertarget)
	surface.SetFont("ChatFont")
	surface.SetTextPos(10, 10)
	surface.SetTextColor(0, 255, 0, 255)
	surface.DrawText("Antifreeze - LJE")

	local curY = 30
	if modules.aimbot.target then
		surface.SetTextPos(10, curY)
		surface.DrawText("Aimbot Target: " .. p.Nick(modules.aimbot.target))
		curY = curY + 20
	end

	if modules.screengrab.isScreengrabRecent() then
		surface.SetTextPos(10, curY)
		surface.SetTextColor(255, math.sin(SysTime() * 15) * 127 + 128, 0, 255)
		surface.DrawText(string.format("Screengrabbed %.1f seconds ago!", modules.screengrab.timeSinceScreengrab()))
		curY = curY + 20
	end

	surface.SetTextPos(10, curY)
	surface.SetTextColor(0, 255, 0, 255)
	surface.DrawText(string.format("GC Memory: %d B", lje.gc.get_total()))
	curY = curY + 20

	for index, renderFunction in ipairs(moduleHooks.draw) do
		renderFunction()
	end

	render.PopRenderTarget()
	cam.End2D()
	lje.env.restore_random_state() -- Restore random state
	lje.env.enable_metatables()
end)

hook.pre("think", "antifreeze.think", function()
	lje.env.disable_metatables() -- Prevent anyone from detecting us via metatables
	lje.env.save_random_state() -- Save random state to avoid detection via PRNG state

	for index, thinkFunction in ipairs(moduleHooks.think) do
		thinkFunction()
	end

	lje.env.restore_random_state() -- Restore random state
	lje.env.enable_metatables()
end)

hook.pre("CreateMove", "antifreeze.move", function(cmd)
	lje.env.disable_metatables() -- Prevent anyone from detecting us via metatables
	lje.env.save_random_state() -- Save random state to avoid detection via PRNG state

	for index, moveFunction in ipairs(moduleHooks.move) do
		moveFunction(cmd)
	end

	lje.env.restore_random_state() -- Restore random state
	lje.env.enable_metatables()
end)

lje.con_printf("$cyan{Antifreeze} initialized successfully.")

return af
