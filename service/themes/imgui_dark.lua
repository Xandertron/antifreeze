local function applyTheme()
	imgui.set_style({
		colors = {
			text = { 1.00, 1.00, 1.00, 1.00 },
			text_disabled = { 0.50, 0.50, 0.50, 1.00 },

			window_bg = { 0.06, 0.06, 0.06, 0.94 },
			child_bg = { 0.00, 0.00, 0.00, 0.00 },
			popup_bg = { 0.08, 0.08, 0.08, 0.94 },

			border = { 0.43, 0.43, 0.50, 0.50 },
			border_shadow = { 0.00, 0.00, 0.00, 0.00 },

			frame_bg = { 0.16, 0.29, 0.48, 0.54 },
			frame_bg_hovered = { 0.26, 0.59, 0.98, 0.40 },
			frame_bg_active = { 0.26, 0.59, 0.98, 0.67 },

			title_bg = { 0.04, 0.04, 0.04, 1.00 },
			title_bg_active = { 0.16, 0.29, 0.48, 1.00 },
			title_bg_collapsed = { 0.00, 0.00, 0.00, 0.51 },

			menu_bar_bg = { 0.14, 0.14, 0.14, 1.00 },

			scrollbar_bg = { 0.02, 0.02, 0.02, 0.53 },
			scrollbar_grab = { 0.31, 0.31, 0.31, 1.00 },
			scrollbar_grab_hovered = { 0.41, 0.41, 0.41, 1.00 },
			scrollbar_grab_active = { 0.51, 0.51, 0.51, 1.00 },

			check_mark = { 0.26, 0.59, 0.98, 1.00 },

			slider_grab = { 0.24, 0.52, 0.88, 1.00 },
			slider_grab_active = { 0.26, 0.59, 0.98, 1.00 },

			button = { 0.26, 0.59, 0.98, 0.40 },
			button_hovered = { 0.26, 0.59, 0.98, 1.00 },
			button_active = { 0.06, 0.53, 0.98, 1.00 },

			header = { 0.26, 0.59, 0.98, 0.31 },
			header_hovered = { 0.26, 0.59, 0.98, 0.80 },
			header_active = { 0.26, 0.59, 0.98, 1.00 },

			separator = { 0.43, 0.43, 0.50, 0.50 },
			separator_hovered = { 0.10, 0.40, 0.75, 0.78 },
			separator_active = { 0.10, 0.40, 0.75, 1.00 },

			resize_grip = { 0.26, 0.59, 0.98, 0.20 },
			resize_grip_hovered = { 0.26, 0.59, 0.98, 0.67 },
			resize_grip_active = { 0.26, 0.59, 0.98, 0.95 },

			tab = { 0.18, 0.35, 0.58, 0.86 },
			tab_hovered = { 0.26, 0.59, 0.98, 0.80 },
			tab_selected = { 0.20, 0.41, 0.68, 1.00 },
			--tab_selected = { 0.07, 0.10, 0.15, 0.97 },
            --tab_unfocused = { 0.07, 0.10, 0.15, 0.97 },
			--tab_unfocused_active = { 0.14, 0.26, 0.42, 1.00 },

			plot_lines = { 0.61, 0.61, 0.61, 1.00 },
			plot_lines_hovered = { 1.00, 0.43, 0.35, 1.00 },
			plot_histogram = { 0.90, 0.70, 0.00, 1.00 },
			plot_histogram_hovered = { 1.00, 0.60, 0.00, 1.00 },

			table_header_bg = { 0.19, 0.19, 0.20, 1.00 },
			table_border_strong = { 0.31, 0.31, 0.35, 1.00 },
			table_border_light = { 0.23, 0.23, 0.25, 1.00 },
			table_row_bg = { 0.00, 0.00, 0.00, 0.00 },
			table_row_bg_alt = { 1.00, 1.00, 1.00, 0.06 },

			text_selected_bg = { 0.26, 0.59, 0.98, 0.35 },

			drag_drop_target = { 1.00, 1.00, 0.00, 0.90 },

			nav_highlight = { 0.26, 0.59, 0.98, 1.00 },
			nav_windowing_highlight = { 1.00, 1.00, 1.00, 0.70 },
			nav_windowing_dim_bg = { 0.80, 0.80, 0.80, 0.20 },
            
			modal_window_dim_bg = { 0.80, 0.80, 0.80, 0.35 },
		},
		rounding = {
			window = 0,
			child = 0,
			frame = 0,
			popup = 0,
			scrollbar = 9,
			grab = 0,
			tab = 4,
		},
		padding = {
			window = { x = 8, y = 8 },
			frame = { x = 4, y = 3 },
			cell = { x = 4, y = 2 },
		},
	})
end

return applyTheme