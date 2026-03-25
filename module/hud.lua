local hud = hud or {}

hud.moduleInfo = {
	name = "HUD",
	description = "Show some things.",
	section = "render",
}

local config = af.config
config.init("hud", {
	drawBrand = { value = true },
	drawMemory = { value = true },
	drawScreengrabWarning = { value = true },
})

local function draw()
	local curY = 10
	surface.SetFont("ChatFont")

	if config.get("hud", "drawBrand") then
		surface.SetTextPos(10, curY)
		surface.SetTextColor(af.brand.color)
		surface.DrawText("Antifreeze - " .. af.info.version .. " - LJE")
		curY = curY + 20
	end

	if config.get("hud", "drawMemory") then
		surface.SetTextPos(10, curY)
		surface.SetTextColor(af.brand.color)
		surface.DrawText(string.format("GC Memory: %s MB", tostring(math.Round(lje.gc.get_total() / 1000 / 1000, 2))))
		curY = curY + 20
	end

	if config.get("hud", "drawScreengrabWarning") then
		if af.modules.antiscreengrab.isScreengrabRecent() or af.debug then
			local timeSince = af.modules.antiscreengrab.timeSinceScreengrab()
			surface.SetTextPos(10, curY)
			local c = timeSince <= 30 and (math.sin(SysTime() * 15) * 127 + 128) or 127
			surface.SetTextColor(c, 255, 255, 255)
			surface.DrawText(string.format("Screengrabbed %.1f seconds ago!", timeSince))
			curY = curY + 20
		end
	end
end

return hud, { draw = draw }
