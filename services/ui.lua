local font = imgui.load_font("C:/Windows/Fonts/corbelb.ttf")
imgui.set_default_font(font)

local lucida = imgui.load_font("C:/Windows/Fonts/lucon.ttf")

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

local netAutoScroll = false
local netFilter = ""
local netFilterInvert = false

local consoleInput = ""
local consoleLastLen = 0

local function renderOverlay()
	if imgui.begin_tab_bar("Categories") then
		for groupName, moduleList in pairs(af.moduleSections) do
			--draw tabs
			if imgui.begin_tab_item(groupName) then
				--draw tab content

				for moduleName, enabled in pairs(moduleList) do
					local data = af.modules[moduleName]
					if data and data.moduleInfo then
						--https://github.com/ocornut/imgui/blob/master/docs/FAQ.md#q-how-can-i-have-multiple-windows-with-the-same-label

						if af.config.raw[moduleName] then
							local changed, value = imgui.checkbox("##" .. moduleName, data.enabled)

							imgui.same_line()

							local open = imgui.collapsing_header(data.moduleInfo.name or moduleName)
							if imgui.is_item_hovered() then
								imgui.set_tooltip(data.moduleInfo.description or "")
							end

							if open then

								local optionNames = {}
								for optionName in pairs(af.config.raw[moduleName]) do
									optionNames[#optionNames + 1] = optionName
								end

								local rank = {}
								for i, name in ipairs(af.config.order[moduleName] or {}) do
									rank[name] = i
								end

								table.sort(optionNames, function(a, b)
									local ra, rb = rank[a] or math.huge, rank[b] or math.huge
									if ra ~= rb then
										return ra < rb
									end
									return a < b
								end)

								for _, optionName in ipairs(optionNames) do
									local optionData = af.config.raw[moduleName][optionName]
									imgui.indent(28)
									if type(optionData.value) == "boolean" then
										local changed, value = imgui.checkbox(optionName, optionData.value)
										if changed then
											af.config.set(moduleName, optionName, value)
										end
									elseif type(optionData.value) == "number" then
										local changed, value = imgui.slider_float(
											optionName,
											optionData.value,
											optionData.min or 0,
											optionData.max or 100
										)

										if changed then
											--TODO: write this mf or track changed, its possible its true every frame
											af.config.set(moduleName, optionName, value, true)
										end
									elseif optionData.type == "color" then
										local col = optionData.value
										local changed, r, g, b =
											imgui.color_edit4(optionName, col[1], col[2], col[3], 1)

										if changed then
											af.config.set(moduleName, optionName, { r, g, b }, true)
										end
									elseif optionData.type == "selection" then
										if imgui.begin_combo(optionName, optionData.value) then
											for i, name in ipairs(optionData.options) do
												if imgui.selectable(name) then
													af.config.set(moduleName, optionName, name)
												end
											end
											imgui.end_combo()
										end
									elseif type(optionData.value) == "string" then
										local changed, text = imgui.input_text(optionName, optionData.value)
										if changed then
											af.config.set(moduleName, optionName, text, true)
										end
									end
									imgui.unindent(28)
								end
							end

							if changed then
								af.switchModule(moduleName, value)
							end
						else
							local changed, value = imgui.checkbox(data.moduleInfo.name or moduleName, data.enabled)

							if changed then
								af.switchModule(moduleName, value)
							end

							if imgui.is_item_hovered() then
								imgui.set_tooltip(data.moduleInfo.description or "")
							end
						end
					end
				end
				imgui.end_tab_item()
			end
		end

		--settings tab

		if imgui.begin_tab_item("settings") then
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

			imgui.end_tab_item()
		end

		if imgui.begin_tab_item("console") then
			imgui.begin_child("consoleLog", 0, -40, imgui.ChildFlags_AutoResizeY)
			imgui.push_font(lucida)

			for _, entry in ipairs(af.commands.log) do
				if entry.isError then
					imgui.text_colored(1, 0.4, 0.4, 1, entry.text)
				else
					imgui.text(entry.text)
				end
			end

			-- only pin to the bottom when new output actually arrived, so
			-- scrolling up to read history doesn't get yanked back down
			if #af.commands.log ~= consoleLastLen then
				consoleLastLen = #af.commands.log
				imgui.set_scroll_here_y(1.0)
			end

			imgui.pop_font()
			imgui.end_child()

			local changed, text = imgui.input_text_multiline(
				"##consoleInput",
				consoleInput,
				4096, -105, 26,
				bit.bor(imgui.InputTextFlags_EnterReturnsTrue, imgui.InputTextFlags_CtrlEnterForNewLine)
			)
			consoleInput = text

			if changed then
				af.commands.run(consoleInput)
				consoleInput = ""
				imgui.set_keyboard_focus_here(-1)
			end

			imgui.same_line()

			if imgui.button("Run") then
				af.commands.run(consoleInput)
				consoleInput = ""
				imgui.set_keyboard_focus_here(-2)
			end

			imgui.same_line()

			if imgui.button("Clear") then
				af.commands.clear()
			end

			imgui.end_tab_item()
		end

		if imgui.begin_tab_item("net") then
			if af.nog then
				imgui.begin_child("log", 0, -58, imgui.ChildFlags_AutoResizeY)

				imgui.push_font(lucida)

				for _, line in ipairs(af.nog.logs) do
					local ok, found = pcall(string.find, line.name, netFilter)
					local notFound = (not ok) or (found == nil)
					if notFound ~= netFilterInvert then continue end
					imgui.separator()
					if line.direction == "send" then
						imgui.text_colored(1, 0.945, 0.482, 1, "▲")
					else
						imgui.text_colored(0.592, 0.827, 1, 1, "▼")
					end
					imgui.same_line()
					imgui.text_colored(accentR, accentG, accentB, 1, line.name)
					if imgui.is_item_hovered() then
						imgui.set_tooltip(line.time)
					end
					for _, field in ipairs(line.fields) do
						imgui.text_colored(accentR * 0.7, accentG * 0.7, accentB * 0.7, 1, "    " .. field.fn)

						local value = tostring(field.value)
						if string.find(value, "\n", 1, true) then
							imgui.indent(28)
							imgui.text(value)
							imgui.unindent(28)
						else
							imgui.same_line()
							imgui.text(value)
						end
					end
				end

				imgui.pop_font()

				if netAutoScroll then
					imgui.set_scroll_here_y(1.0) -- scroll to bottom
				end

				imgui.end_child()

				imgui.set_next_item_width(200)
				local changed, text = imgui.input_text("Filter", netFilter)
				netFilter = text
				if imgui.is_item_hovered() then
					imgui.set_tooltip(
						"Matches against the message name. This is a real Lua pattern, not a plain substring search:\n"
							.. "^text   starts with \"text\"\n"
							.. "text$   ends with \"text\"\n"
							.. "%d+   one or more digits\n"
							.. "%a+   one or more letters\n"
							.. "%w+   one or more letters/digits\n"
							.. ".      matches any single character\n"
							.. "%%      literal percent sign (patterns treat % specially)\n"
							.. "Combine with \"Invert\" to show everything that does NOT match instead."
					)
				end

				imgui.same_line()

				local _, checked = imgui.checkbox("Invert", netFilterInvert)
				netFilterInvert = checked

				--next line

				local _, checked = imgui.checkbox("Auto Scroll", netAutoScroll)
				netAutoScroll = checked

				imgui.same_line()

				imgui.set_next_item_width(120)
				local changed, maxEntries = imgui.input_int("Max Entries", af.nog.maxEntries)
				if changed then
					af.nog.maxEntries = maxEntries
					af.nog.trimEntries()
				end

				imgui.same_line()

				if imgui.button("Clear Log") then
					af.nog.clear()
				end
			else
				imgui.text_colored(1, 0.6, 0.6, 1, "Net logging is disabled.")
				imgui.text("Enable the \"net\" key under [log] in settings.default.toml (or your user settings override) and reload.")
			end

			imgui.end_tab_item()
		end

		imgui.end_tab_bar()
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