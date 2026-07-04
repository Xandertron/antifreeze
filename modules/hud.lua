local hud = {}

hud.moduleInfo = {
	name = "HUD",
	description = "Show some things.",
	section = "render",
}

local cfg = af.config.register("hud", {
	drawBrand = { value = true },
	drawMemory = { value = true },
	drawVelocity = { value = true },
	drawModules = { value = true },
	drawScreengrabWarning = { value = true },

	drawColor = { value = { 0.5, 1, 1 }, type = "color" },
})

function hud:render()
	surface.SetFont("ChatFont")
	surface.SetTextColor(af.brand.color)

	local curY = 10
	if cfg.drawBrand then
		surface.SetTextPos(10, curY)
		surface.DrawText("Antifreeze - " .. af.info.version .. " - LJE")
		curY = curY + 20
	end

	if cfg.drawMemory then
		surface.SetTextPos(10, curY)
		surface.DrawText(string.format("GC Memory: %s MB", tostring(math.ceil(lje.gc.get_total() / 1000 / 1000, 2))))
		curY = curY + 20
	end

	if cfg.drawVelocity then
		surface.SetTextPos(10, curY)
		surface.DrawText(string.format("Velocity: %s u/s", tostring(math.ceil(LocalPlayer():GetVelocity():Length()))))
		curY = curY + 20
	end

	if cfg.drawScreengrabWarning then
		if af.debug then
			local timeSince = af.modules.antiscreengrab.timeSinceScreengrab()
			surface.SetTextPos(10, curY)
			local c = timeSince <= 30 and (math.sin(SysTime() * 15) * 127 + 128) or 127
			surface.SetTextColor(c, 255, 255, 255)
			surface.DrawText(string.format("Screengrabbed %.1f seconds ago!", timeSince))
			curY = curY + 20
		end
	end

	if cfg.drawModules then
		local anyEnabled = false
		for name, data in pairs(af.modules) do
			if name == "hud" then
				continue
			end
			if data.enabled then
				if not anyEnabled then
					anyEnabled = true
					surface.SetDrawColor(255, 255, 255)
					surface.DrawLine(10, curY+5, 150, curY+5)
					curY = curY + 10
				end
				surface.SetTextPos(10, curY)
				surface.DrawText(data.moduleInfo.name)
				curY = curY + 20
			end
		end
	end
end

return hud, { draw = draw }
