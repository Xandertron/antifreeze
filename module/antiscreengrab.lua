local antiscreengrab = {}
local origCapture = render.Capture

antiscreengrab.lastGrabbed = -1
antiscreengrab.threshold = 300 -- seconds

function antiscreengrab.isScreengrabRecent()
	if antiscreengrab.lastGrabbed == -1 then
		return false
	end
	return (SysTime() - antiscreengrab.lastGrabbed) <= antiscreengrab.threshold
end

function antiscreengrab.timeSinceScreengrab()
	return SysTime() - antiscreengrab.lastGrabbed
end

local render = rawget(_G, "render")
rawset(
	render,
	"Capture",
	lje.detour(origCapture, function(tbl)
		lje.hooks.disable()
		antiscreengrab.lastGrabbed = SysTime()
		lje.hooks.enable()

		return origCapture(tbl)
	end)
)

return antiscreengrab
