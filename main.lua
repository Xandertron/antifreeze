af = af or {}

af.info = {}
af.info.version = "2.1.0"
af.info.name = "Antifreeze"

local print = lje.con_printf
local inspect = lje.util.inspect
hook._listeners.antifreeze = {}

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

noop = function() end

af.config = lje.include("lib/config.lua")
af.log = lje.include("lib/log.lua")
local drawOverlay = lje.include("service/ui.lua")

local settings = lje.settings.open()
local httpDetour
local openUrlDetour

if settings:get("block.http", true) then
	httpDetour = lje.include("detours/http.lua")
end

if settings:get("block.openurl", true) then
	openUrlDetour = lje.include("detours/openurl.lua")
end

local function getFnAddr(fn)
	return ffi.mem.unwrap_userdata(ffi.mem.upvalue(fn, 1))
end

local renderCapture = getFnAddr(render.Capture)

-- TODO: fix this and put it in a detour module
if renderCaptureDetour then
	renderCaptureDetour:remove()
	renderCaptureDetour = nil
end

renderCaptureDetour, err = ffi.detour.create(
	renderCapture,
	[[
#include <stdio.h>
int (*original)(lua_State* L);
int captureCounter = 0;

int detour(lua_State* L) {
  captureCounter++;
  return original(L);
}
]]
)

local captureCounterPtr = renderCaptureDetour:get("captureCounter")
ffi.mem.try_write_u32(captureCounterPtr, 0) -- Initialize counter to 0

local lastCaptureCount = 0
local lastCaptureTime = 0
local function checkCapture()
	local currentCount = ffi.mem.try_read_u32(captureCounterPtr)
	if currentCount ~= nil and currentCount > lastCaptureCount then
		lastCaptureCount = currentCount
		lastCaptureTime = SysTime()
	end
end

af.modules = af.modules or {}
af.moduleSections = af.moduleSections or {}
local modulesToLoad = lje.env.find_script_files("modules/*")

local cfg = af.config.register("main", {
	enabledModules = { value = {
		esp = true,
		hud = true,
	} },
})

lje.util.inspect(cfg.enabledModules)

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
	cfg.enabledModules[moduleName] = switch
	af.config.set("main", "enabledModules", cfg.enabledModules, temp)
	return switch
end

af.log("Found " .. #modulesToLoad .. " module(s) to load!")

function af.loadModule(name, data)
	if data == nil then
		af.log("Skipping " .. name .. ", no data present!", "error")
		return
	end

	data.enabled = true

	af.modules[name] = data
	af.modules[name].enabled = cfg.enabledModules[name]
	af.modules[name].enabled = data.enabled or false --allow modules to override startup status

	if data.moduleInfo then
		local key = data.moduleInfo.section
		if key ~= "none" then
			key = key or "other" --handle non-defined sections
			af.moduleSections[key] = af.moduleSections[key] or {}
			af.moduleSections[key][name] = true
		end
	end
end

for idx, path in ipairs(modulesToLoad) do
	local moduleName = string.match(path, "^modules/([^/]+)%.lua$")
	data = unpack({ lje.include(path) })
	if data then
		af.log("Loading module: " .. data.moduleInfo.name)
		af.loadModule(moduleName, data)
	else
		af.log("Skipping " .. moduleName .. ", no data present!", "error")
	end
end

--
hook.Add("CreateMove", "move", function(cmd)
	for moduleName, moduleData in pairs(af.modules) do
		if moduleData.move and moduleData.enabled then
			local ccmd = lje.proxy.copy(cmd)
			moduleData:move(ccmd)
		end
	end
end)

hook.Add("PostRender", "render", function()
	if render.IsTakingScreenshot() then
		return
	end

	checkCapture()
	if httpDetour then
		httpDetour:run()
	end

	for moduleName, moduleData in pairs(af.modules) do
		if moduleData.run and moduleData.enabled then
			moduleData:run()
		end
	end

	cam.Start2D()

	for moduleName, moduleData in pairs(af.modules) do
		if moduleData.prerender and moduleData.enabled then
			moduleData:prerender()
		end
	end

	drawOverlay()

	if SysTime() - lastCaptureTime < 5 then
		surface.SetTextColor(255, 255, 100, 255)
		surface.SetTextPos(10, 20)
		surface.DrawText("Screengrab detected!")
	end

	for moduleName, moduleData in pairs(af.modules) do
		if moduleData.render and moduleData.enabled then
			moduleData:render()
		end
	end

	cam.End2D()
end)

hook.Listen(true)

lje.env.on_cleanup(function()
	if renderCaptureDetour then
		renderCaptureDetour:disable()
		renderCaptureDetour = nil
	end

	if httpDetour then
		httpDetour:cleanup()
	end

	if openUrlDetour then
		openUrlDetour:cleanup()
	end

	for moduleName, moduleData in pairs(af.modules) do
		if moduleData.cleanup then
			af.log("Cleaning up " .. moduleName)
			moduleData:cleanup()
		end
	end
end)

lje.con_printf("$cyan{\n" .. af.brand.watermark .. "\n}")
