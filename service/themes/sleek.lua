local function applyTheme(r, g, b)

	--dim out cyan, yellow, and magenta colors so text is still readable, and smoothly so no sudden jumps
	local y = r * 0.299 + g * 0.587 + b * 0.114
	local t = math.max(0, math.min(1, (y - 0.6) / 0.4))
	local f = 1 - (t * t * (3 - 2 * t)) * 0.25
	r, g, b = r * f, g * f, b * f
	
	imgui.set_style({
		colors = {
			-- Text
			text = { 0.92, 0.92, 0.94, 1.00 },
			text_disabled = { 0.45, 0.45, 0.48, 1.00 },

			-- Base backgrounds
			window_bg = { 0.09, 0.09, 0.10, 0.8 },
			child_bg = { 0.11, 0.11, 0.12, 1.00 },
			popup_bg = { 0.08, 0.08, 0.09, 1.00 },
			border = { 0.20, 0.20, 0.22, 0.60 },
			border_shadow = { 0.00, 0.00, 0.00, 0.00 },

			-- Frames (inputs, checkbox bg, etc)
			frame_bg = { 0.14, 0.14, 0.15, 1.00 },
			frame_bg_hovered = { 0.18, 0.18, 0.20, 1.00 },
			frame_bg_active = { 0.20, 0.20, 0.22, 1.00 },

			-- Title bar
			title_bg = { 0.07, 0.07, 0.08, 1.00 },
			title_bg_active = { 0.10, 0.10, 0.11, 1.00 },
			title_bg_collapsed = { 0.05, 0.05, 0.06, 1.00 },

			menu_bar_bg = { 0.10, 0.10, 0.11, 1.00 },

			-- Scrollbar
			scrollbar_bg = { 0.05, 0.05, 0.06, 1.00 },
			scrollbar_grab = { 0.25, 0.25, 0.28, 1.00 },
			scrollbar_grab_hovered = { 0.35, 0.35, 0.38, 1.00 },
			scrollbar_grab_active = { 0.45, 0.45, 0.48, 1.00 },

			-- Accent elements
			button = { r, g, b, 0.85 },
			button_hovered = { r, g, b, 1.00 },
			button_active = { r * 0.75, g * 0.75, b * 0.75, 1.00 },

			check_mark = { r, g, b, 1.00 },

			slider_grab = { r, g, b, 0.90 },
			slider_grab_active = { r, g, b, 1.00 },

			resize_grip = { r, g, b, 0.25 },
			resize_grip_hovered = { r, g, b, 0.60 },
			resize_grip_active = { r, g, b, 0.90 },

			header = { 0.16, 0.16, 0.18, 1.00 },
			header_hovered = { 0.22, 0.22, 0.25, 1.00 },
			header_active = { r, g, b, 0.85 },

			-- Tabs (only active tab is accent)
			tab = { 0.12, 0.12, 0.13, 1.00 },
			tab_hovered = { r * 0.5, g * 0.5, b * 0.5, 1.00 },
			tab_selected = { r, g, b, 1.00 },

			-- Separators
			separator = { 0.20, 0.20, 0.22, 1.00 },
			separator_hovered = { r, g, b, 0.70 },
			separator_active = { r, g, b, 1.00 },

			-- Tables
			table_header_bg = { 0.11, 0.11, 0.12, 1.00 },
			table_border_strong = { 0.22, 0.22, 0.25, 1.00 },
			table_border_light = { 0.17, 0.17, 0.19, 1.00 },
			table_row_bg = { 0.00, 0.00, 0.00, 0.00 },
			table_row_bg_alt = { 1.00, 1.00, 1.00, 0.03 },

			text_selected_bg = { r, g, b, 0.35 },
			drag_drop_target = { r, g, b, 0.90 },

			nav_highlight = { r, g, b, 1.00 },
			modal_window_dim_bg = { 0.80, 0.80, 0.80, 0.35 },
		},

		rounding = {
			window = 6,
			child = 6,
			frame = 4,
			popup = 4,
			scrollbar = 6,
			grab = 4,
			tab = 6,
		},

		padding = {
			window = { x = 10, y = 10 },
			frame = { x = 6, y = 4 },
			item = { x = 8, y = 6 },
			inner = { x = 6, y = 6 },
		},

		spacing = {
			indent = 20,
			scrollbar = 12,
			grab_min = 10,
		},
	})
end

return applyTheme
