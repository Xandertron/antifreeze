local font = imgui.load_font("C:/Windows/Fonts/corbelb.ttf")
imgui.set_default_font(font)

af.lucidaFont = imgui.load_font("C:/Windows/Fonts/lucon.ttf")

local themesToLoad = lje.env.find_script_files("services/themes/*")
af.themes = {}
af.themeList = {}

for idx, path in ipairs(themesToLoad) do
	local themeName = string.match(path, "^services/themes/([^/]+)%.lua$")
	af.log("Loading theme: " .. themeName)
	af.themes[themeName] = lje.include(path)
	table.insert(af.themeList, themeName)
end

local config = af.config
local uiConfig = config.register("ui", {
	theme = { value = "sleek" },
	accentColor = { value = { 0.5, 1, 1 } },
}, { "theme", "accentColor" })

local accentR, accentG, accentB = unpack(uiConfig.accentColor)

local themeToRun = uiConfig.theme
if af.themes[themeToRun] then
	af.selectedTheme = themeToRun
	af.themes[themeToRun](accentR, accentG, accentB)
else
	af.selectedTheme = "sleek"
	af.themes["sleek"](accentR, accentG, accentB)
end

-- Each panel is its own file under services/panels/, returning
-- { label, title, visible, render }. `render()` is called between
-- begin_window/end_window - see any file in that folder for the shape.
local panelsToLoad = lje.env.find_script_files("services/panels/*")
local panels = {}

for _, path in ipairs(panelsToLoad) do
	af.log("Loading panel: " .. path)
	panels[#panels + 1] = lje.include(path)
end

local DOCK_MOVE_EPSILON = 0.5 -- ignore sub-pixel float jitter when detecting movement
local DOCK_TARGET_EPSILON = 2 -- how close counts as "already there" (skip re-snapping onto itself)
local DOCK_ZONE_FRACTION = 0.1 -- how much of the screen width/height each hot zone spans (was 0.2, a fifth of the screen - this is half that)

local function nearlyEqual(a, b, eps)
	return math.abs(a - b) <= eps
end

local function dockZoneFromMouse(scrW, scrH)
	local mx, my = input.GetCursorPos()

	local zoneW, zoneH = scrW * DOCK_ZONE_FRACTION, scrH * DOCK_ZONE_FRACTION

	local nearLeft = mx < zoneW
	local nearRight = mx > scrW - zoneW
	local nearTop = my < zoneH
	local nearBottom = my > scrH - zoneH

	local isMidCol = mx > scrW / 2 - zoneW / 2 and mx < scrW / 2 + zoneW / 2
	local isMidRow = my > scrH / 2 - zoneH / 2 and my < scrH / 2 + zoneH / 2

	if nearTop and nearLeft then
		return 0, 0, scrW / 2, scrH / 2
	elseif nearTop and nearRight then
		return scrW / 2, 0, scrW / 2, scrH / 2
	elseif nearBottom and nearLeft then
		return 0, scrH / 2, scrW / 2, scrH / 2
	elseif nearBottom and nearRight then
		return scrW / 2, scrH / 2, scrW / 2, scrH / 2
	elseif nearTop and isMidCol then
		return 0, 0, scrW, scrH / 2
	elseif nearBottom and isMidCol then
		return 0, scrH / 2, scrW, scrH / 2
	elseif nearLeft and isMidRow then
		return 0, 0, scrW / 2, scrH
	elseif nearRight and isMidRow then
		return scrW / 2, 0, scrW / 2, scrH
	end

	return nil
end

local DOCK_STOP_FRAMES = 24

local function updateDocking(panel, px, py, pw, ph)
	if panel._dockSkip then
		-- this frame's position is one we just forced via a snap - don't
		-- treat our own snap as a drag event
		panel._dockSkip = false
		panel._dockLastPos = { px, py }
		panel._dockStableFrames = 0
		panel._dragging = false
		panel._dockPreviewSize = nil
		return
	end

	local last = panel._dockLastPos
	local moved = last
		and (math.abs(px - last[1]) > DOCK_MOVE_EPSILON or math.abs(py - last[2]) > DOCK_MOVE_EPSILON)

	if moved then
		if not panel._dragging then
			panel._dragging = true
			panel._dragStartSize = { w = pw, h = ph }
		end
		panel._dockStableFrames = 0
	elseif panel._dragging then
		panel._dockStableFrames = (panel._dockStableFrames or 0) + 1
	end

	if panel._dragging then
		local scrW, scrH = ScrW(), ScrH()
		local tx, ty, tw, th = dockZoneFromMouse(scrW, scrH)
		if tw then
			panel._dockPreviewSize = { w = tw, h = th }
		elseif panel._dragStartSize then
			panel._dockPreviewSize = panel._dragStartSize
		end

		if panel._dockStableFrames >= DOCK_STOP_FRAMES then
			-- settled for a good while after moving - treat as released
			panel._dragging = false
			panel._dockPreviewSize = nil

			if tx then
				local alreadyThere = nearlyEqual(px, tx, DOCK_TARGET_EPSILON)
					and nearlyEqual(py, ty, DOCK_TARGET_EPSILON)
					and nearlyEqual(pw, tw, DOCK_TARGET_EPSILON)
					and nearlyEqual(ph, th, DOCK_TARGET_EPSILON)

				if not alreadyThere then
					panel._dockPending = { x = tx, y = ty, w = tw, h = th }
				end
			end
		end
	end

	panel._dockLastPos = { px, py }
end

local function renderOverlay()
	if imgui.begin_combo("Theme", af.selectedTheme) then
		for i, name in ipairs(af.themeList) do
			if imgui.selectable(name) then
				af.selectedTheme = name
				uiConfig.theme = name
				af.themes[name](accentR, accentG, accentB)
			end
		end
		imgui.end_combo()
	end

	local changed, r, g, b = imgui.color_edit4("Accent Color", accentR, accentG, accentB, 1)

	if changed then
		af.themes[af.selectedTheme](accentR, accentG, accentB)
		af.brand.color = Color(accentR * 255, accentG * 255, accentB * 255)
		config.set("ui", "accentColor", { r, g, b }, true) -- dragged every frame, so defer the save
		accentR, accentG, accentB = r, g, b
	end

	imgui.separator()

	for i, panel in ipairs(panels) do
		if i > 1 then
			imgui.same_line()
		end
		if imgui.button(panel.label) then
			panel.visible = true
		end
	end

	for _, panel in ipairs(panels) do
		if panel.visible then
			if panel._dockPending then
				local d = panel._dockPending
				imgui.set_next_window_pos(d.x, d.y, imgui.Cond_Always)
				imgui.set_next_window_size(d.w, d.h, imgui.Cond_Always)
				panel._dockPending = nil
				panel._dockSkip = true
			elseif panel._dockPreviewSize then
				-- live preview while dragging - size only, position keeps
				-- following the native drag untouched. Not a "skip" frame:
				-- this keeps updating every frame for the rest of the drag.
				local s = panel._dockPreviewSize
				imgui.set_next_window_size(s.w, s.h, imgui.Cond_Always)
			end

			local visible, open = imgui.begin_window(panel.title, panel.visible, 0)

			local px, py = imgui.get_window_pos()
			local pw, ph = imgui.get_window_size()
			updateDocking(panel, px, py, pw, ph)

			panel.render()
			imgui.end_window()
			panel.visible = open
		end
	end
end

local imguiCursorEnabled = false
imgui.set_visible(false) --disable on startup
imgui.set_overlay_bind(0x74) --F5

local function drawOverlay()
	imgui.new_frame()
	if imgui.is_visible() then
		if not imguiCursorEnabled then
			gui.EnableScreenClicker(true)
			imguiCursorEnabled = true
		end
		local visible, open = imgui.begin_window("Antifreeze | " .. af.info.version, nil, imgui.WindowFlags_NoCollapse)

		renderOverlay()

		imgui.end_window()
	else
		if imguiCursorEnabled then
			gui.EnableScreenClicker(false)
			imguiCursorEnabled = false
			af.config.saveAll()
		end
	end
	imgui.render()
end

return drawOverlay
