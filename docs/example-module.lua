-- Antifreeze module contract, annotated.
--
-- This file is DOCUMENTATION, not a real module: it lives in docs/, not
-- modules/, so main.lua's loader (lje.env.find_script_files("modules/*"))
-- never sees it and it can't show up in the live menu or run every frame.
-- If you want to actually try it, copy it into modules/ and give it a
-- real (unique) local name.
--
-- It shows the full shape of what main.lua and services/ui.lua expect a
-- module to return: the moduleInfo fields, every config option type the
-- UI knows how to draw, every lifecycle hook, and when each one fires.

local example = {}

-- moduleInfo is required. `section` groups the module under a tab in the
-- menu (services/ui.lua iterates af.moduleSections). Sections currently
-- in use across the project: "movement", "combat", "render", "other".
-- Use section = "none" to load and run the module without it appearing
-- under any tab at all (still toggled on by default, just invisible).
example.moduleInfo = {
	name = "Example",
	description = "Shown as a tooltip over the module's checkbox in the menu.",
	section = "other",
}

-- af.config.register(name, defaults) registers persisted, auto-UI'd
-- settings for this module. `name` should match the module's own key in
-- af.modules (i.e. the file name without .lua) so the menu can find its
-- option list via af.config.raw[moduleName]. Returns a proxy: read with
-- cfg.key, write with cfg.key = value (validated, clamped, auto-saved).
--
-- services/ui.lua picks a widget per entry based on its shape:
local cfg = af.config.register("example", {
	-- { value = <boolean> }                              -> checkbox
	enableThing = { value = false },

	-- { value = <number>, min = ..., max = ... }          -> slider
	speed = { value = 1, min = 0, max = 10 },

	-- { value = {r,g,b}, type = "color" }                 -> color picker
	tint = { value = { 1, 1, 1 }, type = "color" },

	-- { value = <string>, type = "selection", options = { ... } } -> dropdown
	mode = { value = "a", type = "selection", options = { "a", "b", "c" } },

	-- { value = <string> }                                -> text input
	label = { value = "hello" },
})

-- Optional: called automatically by lib/config.lua's notifyModule()
-- whenever one of this module's cfg keys changes (from the UI or from
-- config.set elsewhere). `self` is this module table.
function example:onConfigChange(key, newValue)
	af.log(string.format("example: %s changed to %s", key, tostring(newValue)))
end

-- Optional: fire on the module's enabled-state rising/falling edge, i.e.
-- when af.switchModule() (main.lua) actually flips example.enabled.
-- Good place to snapshot state you'll need for the rest of the session,
-- the way freecam:onEnable() captures the starting camera position.
function example:onEnable()
	af.log("example: enabled")
end

function example:onDisable()
	af.log("example: disabled")
end

-- Optional: fires from the CreateMove hook in main.lua, once per frame,
-- only while the module is enabled. `cmd` is a proxy (see lje.proxy.copy)
-- into the game's usercmd for this frame — read/mutate it through its
-- methods (GetButtons/SetButtons/SetViewAngles/...), same as bhop.lua or
-- freecam.lua do. Don't store `cmd` past this call; proxies only live
-- for the duration of the engine call that produced them.
function example:move(cmd)
	if not cfg.enableThing then
		return
	end
	-- e.g. cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_JUMP)))
end

-- Optional: fires first in the PostRender hook, before any drawing
-- happens (cam.Start2D hasn't run yet). Use this for per-frame logic
-- that isn't drawing, the way holdundo.lua and spam.lua do.
function example:run()
	-- e.g. poll input, advance timers, run console commands
end

-- Optional: fires in PostRender after cam.Start2D() but before the menu
-- overlay is drawn, the way freecam.lua uses it to render its camera
-- view into a render target before the UI draws on top.
function example:prerender()
end

-- Optional: fires last in PostRender, after the menu overlay, still
-- inside the 2D cam block. This is where you draw with surface/draw,
-- the way esp.lua and hud.lua do.
function example:render()
	if not cfg.enableThing then
		return
	end
	-- e.g. surface.SetTextColor(255, 255, 255, 255)
	-- surface.SetTextPos(10, 10)
	-- surface.DrawText(cfg.label)
end

-- Optional: fires from lje.env.on_cleanup on game shutdown/disconnect.
-- Tear down detours, render targets, materials, timers, etc. here, the
-- way esp.lua and aimbot.lua do.
function example:cleanup()
end

return example
