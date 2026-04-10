--this file is both ran by preinit and main, so probably safe

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

local function captureHk(tbl)
  screengrab.last_screengrab_time = os.clock()
  return origCapture(tbl)
end

_G.render.Capture = lje.detour(origCapture, captureHk)

return antiscreengrab
