local screengrab = {}
local origCapture = render.Capture

screengrab.lastGrabbed = 0
screengrab.threshold = 10 -- seconds
screengrab.enabled = true --override setting

function screengrab.isScreengrabRecent()
	return (SysTime() - screengrab.lastGrabbed) <= screengrab.threshold
end

function screengrab.timeSinceScreengrab()
	return SysTime() - screengrab.lastGrabbed
end

local render = rawget(_G, "render")
rawset(
	render,
	"Capture",
	lje.detour(origCapture, function(tbl)
		lje.hooks.disable()
		screengrab.lastGrabbed = SysTime()
		lje.hooks.enable()

		return origCapture(tbl)
	end)
)

return screengrab
