local function applyTheme(r, g, b)
	imgui.set_style({
		colors = {
			-- Main window
			window_bg = { r = r * 0.15, g = g * 0.15, b = b * 0.15, a = 0.95 },
			border = { r = r * 0.50, g = g * 0.50, b = b * 0.50, a = 0.60 },

			-- Title bar
			title_bg = { r = r * 0.40, g = g * 0.40, b = b * 0.40, a = 1.0 },
			title_bg_active = { r = r * 0.60, g = g * 0.60, b = b * 0.60, a = 1.0 },
			title_bg_collapsed = { r = r * 0.30, g = g * 0.30, b = b * 0.30, a = 0.75 },

			-- Buttons
			button = { r = r * 0.55, g = g * 0.55, b = b * 0.55, a = 1.0 },
			button_hovered = { r = r * 0.75, g = g * 0.75, b = b * 0.75, a = 1.0 },
			button_active = { r = r * 0.40, g = g * 0.40, b = b * 0.40, a = 1.0 },

			-- Frames
			frame_bg = { r = r * 0.25, g = g * 0.25, b = b * 0.25, a = 1.0 },
			frame_bg_hovered = { r = r * 0.40, g = g * 0.40, b = b * 0.40, a = 1.0 },
			frame_bg_active = { r = r * 0.55, g = g * 0.55, b = b * 0.55, a = 1.0 },

			-- Sliders
			slider_grab = { r = r * 0.70, g = g * 0.70, b = b * 0.70, a = 1.0 },
			slider_grab_active = { r = r * 0.90, g = g * 0.90, b = b * 0.90, a = 1.0 },

			-- Checkmark
			check_mark = { r = r, g = g, b = b, a = 1.0 },

			-- Headers
			header = { r = r * 0.40, g = g * 0.40, b = b * 0.40, a = 0.80 },
			header_hovered = { r = r * 0.60, g = g * 0.60, b = b * 0.60, a = 1.0 },
			header_active = { r = r * 0.50, g = g * 0.50, b = b * 0.50, a = 1.0 },

			-- Tabs
			tab = { r = r * 0.35, g = g * 0.35, b = b * 0.35, a = 0.3 },
			tab_hovered = { r = r * 0.65, g = g * 0.65, b = b * 0.65, a = 1.0 },
			tab_selected = { r = r * 0.55, g = g * 0.55, b = b * 0.55, a = 1.0 },

			-- Scrollbar
			scrollbar_bg = { r = r * 0.10, g = g * 0.10, b = b * 0.10, a = 1.0 },
			scrollbar_grab = { r = r * 0.45, g = g * 0.45, b = b * 0.45, a = 1.0 },
			scrollbar_grab_hovered = { r = r * 0.60, g = g * 0.60, b = b * 0.60, a = 1.0 },
			scrollbar_grab_active = { r = r * 0.35, g = g * 0.35, b = b * 0.35, a = 1.0 },

			-- Separator
			separator = { r = r * 0.45, g = g * 0.45, b = b * 0.45, a = 0.80 },
			separator_hovered = { r = r * 0.65, g = g * 0.65, b = b * 0.65, a = 1.0 },
			separator_active = { r = r * 0.85, g = g * 0.85, b = b * 0.85, a = 1.0 },

			-- Resize grip
			resize_grip = { r = r * 0.45, g = g * 0.45, b = b * 0.45, a = 0.50 },
			resize_grip_hovered = { r = r * 0.65, g = g * 0.65, b = b * 0.65, a = 0.80 },
			resize_grip_active = { r = r * 0.85, g = g * 0.85, b = b * 0.85, a = 1.0 },

			-- Popup
			popup_bg = { r = r * 0.18, g = g * 0.18, b = b * 0.18, a = 0.97 },

			-- Text
			text = { r = 0.70 + r * 0.30, g = 0.70 + g * 0.30, b = 0.70 + b * 0.30, a = 1.0 },
			text_disabled = { r = 0.30 + r * 0.20, g = 0.30 + g * 0.20, b = 0.30 + b * 0.20, a = 1.0 },
		},
		rounding = {
			window = 8,
			frame = 6,
			tab = 6,
		},
		padding = {
			window = { x = 10, y = 10 },
			frame = { 5, 4 },
		},
	})
end

local font = imgui.load_font("C:/Windows/Fonts/corbelb.ttf")
imgui.set_default_font(font)

local tr, tg, tb = 0.5, 1, 1
applyTheme(tr, tg, tb)

local function draw()
	imgui.text(af.info.version)
	if imgui.begin_tab_bar("Categories") then
		for groupName, moduleList in pairs(af.moduleSections) do
			--draw tabs
			if imgui.begin_tab_item(groupName) then
				--draw tab content

				for moduleName, enabled in pairs(moduleList) do
					local data = af.modules[moduleName]
					if data and data.moduleInfo then
						changed, value = imgui.checkbox(data.moduleInfo.name or moduleName, data.enabled)

						if imgui.is_item_hovered() then
							imgui.set_tooltip(data.moduleInfo.description or "")
						end

						if changed then
							af.switchModule(moduleName, value)
						end
					end
				end
				imgui.end_tab_item()
			end
		end
		if imgui.begin_tab_item("settings") then
			local changed, r, g, b = imgui.color_edit4("", tr, tg, tb, 1)

			if changed then
				applyTheme(tr, tg, tb)
				af.brand.color = Color(tr * 255, tg * 255, tb * 255)
				tr, tg, tb = r, g, b
			end
			imgui.end_tab_item()
		end
		imgui.end_tab_bar()
	end
end

return { draw = draw }
