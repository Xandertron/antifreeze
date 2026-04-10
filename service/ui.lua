local font = imgui.load_font("C:/Windows/Fonts/corbelb.ttf")
imgui.set_default_font(font)

local themesToLoad = lje.env.find_script_files("service/themes/*")
af.themes = {}
af.themeList = {}

for idx, path in ipairs(themesToLoad) do
	local themeName = string.match(path, "^service/themes/([^/]+)%.lua$")
	af.log("Loading theme: " .. themeName)
	af.themes[themeName] = lje.include(path)
	table.insert(af.themeList, themeName)
end

local config = af.config
config.init("ui", {
	theme = { value = "sleek" },
	accentColor = { value = { 0.5, 1, 1 } },
})

local accentR, accentG, accentB = unpack(config.get("ui", "accentColor"))

local themeToRun = config.get("ui", "theme")
if af.themes[themeToRun] then
	af.selectedTheme = themeToRun
	af.themes[themeToRun](accentR, accentG, accentB)
else
	af.selectedTheme = "sleek"
	af.themes["sleek"](accentR, accentG, accentB)
end

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

						if af.config.cache[moduleName] then
							local changed, value = imgui.checkbox("##" .. moduleName, data.enabled)

							imgui.same_line()

							local open = imgui.collapsing_header(data.moduleInfo.name or moduleName)
							if imgui.is_item_hovered() then
								imgui.set_tooltip(data.moduleInfo.description or "")
							end

							if open then
								for optionName, optionData in pairs(af.config.cache[moduleName]) do
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
													config.set(moduleName, optionName, name)
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
						config.set("ui", "theme", name)
						af.themes[name](accentR, accentG, accentB)
					end
				end
				imgui.end_combo()
			end

			local changed, r, g, b = imgui.color_edit4("Accent Color", accentR, accentG, accentB, 1)

			if changed then
				af.themes[af.selectedTheme](accentR, accentG, accentB)
				af.brand.color = Color(accentR * 255, accentG * 255, accentB * 255)
				config.set("ui", "accentColor", { r, g, b }, true)
				accentR, accentG, accentB = r, g, b
			end

			--if imgui.collapsing_header("Settings") then
			--	  imgui.text("Settings content here")
			--end

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

return { drawOverlay = drawOverlay }
