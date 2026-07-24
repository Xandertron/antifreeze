local antiscreengrab = antiscreengrab or {}

antiscreengrab.moduleInfo = {
	name = "Anti Screengrab",
	description = "Detours render.Capture() to detect screenshots and warns on-screen when one is taken.",
	section = "none", -- always-on safety feature, not a toggle in the menu
}

local function getFnAddr(fn)
	return ffi.mem.unwrap_userdata(ffi.mem.upvalue(fn, 1))
end

-- If this module is hot-reloaded, remove the previous detour before creating
-- a new one on the same address (see docs/example-module.lua / detours guide:
-- a detour object must stay alive for the whole time it should be active).
if af.modules.antiscreengrab and af.modules.antiscreengrab.detour then
	af.log("Recreating antiscreengrab detour")
	af.modules.antiscreengrab.detour:remove()
	af.modules.antiscreengrab.detour = nil
end

local renderCapture = getFnAddr(render.Capture)
local detour, err = ffi.detour.create(
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

if not detour then
	af.log("antiscreengrab: failed to create render.Capture detour: " .. tostring(err), "error")
	return antiscreengrab
end

antiscreengrab.detour = detour

local captureCounterPtr = detour:get("captureCounter")
ffi.mem.try_write_u32(captureCounterPtr, 0) -- Initialize counter to 0

local lastCaptureCount = 0
local lastCaptureTime = 0

-- how many seconds ago render.Capture() was last called.
function antiscreengrab.timeSinceScreengrab()
	return SysTime() - lastCaptureTime
end

function antiscreengrab:run()
	local currentCount = ffi.mem.try_read_u32(captureCounterPtr)
	if currentCount ~= nil and currentCount > lastCaptureCount then
		lastCaptureCount = currentCount
		lastCaptureTime = SysTime()
	end
end

function antiscreengrab:cleanup()
	if antiscreengrab.detour then
		antiscreengrab.detour:disable()
		antiscreengrab.detour = nil
	end
end

return antiscreengrab
