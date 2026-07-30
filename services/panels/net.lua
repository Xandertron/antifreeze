local panel = {
	label = "Net Log",
	title = "Antifreeze | Net Log",
	visible = false,
}

local netAutoScroll = false
local netFilter = ""
local netFilterInvert = false

local function accent()
	local c = af.brand.color
	return c.r / 255, c.g / 255, c.b / 255
end

function panel.render()
	if not af.nog then
		imgui.text_colored(1, 0.6, 0.6, 1, "Net logging is disabled.")
		imgui.text("Enable the \"net\" key under [log] in settings.default.toml (or your user settings override) and reload.")
		return
	end

	local ar, ag, ab = accent()

	imgui.begin_child("log", 0, -58, imgui.ChildFlags_AutoResizeY)

	imgui.push_font(af.lucidaFont)

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
		imgui.text_colored(ar, ag, ab, 1, line.name)
		if imgui.is_item_hovered() then
			imgui.set_tooltip(line.time)
		end
		for _, field in ipairs(line.fields) do
			imgui.text_colored(ar * 0.7, ag * 0.7, ab * 0.7, 1, "    " .. field.fn)

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
end

return panel
