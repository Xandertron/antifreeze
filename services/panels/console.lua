local panel = {
	label = "Console",
	title = "Antifreeze | Console",
	visible = false,
}

local consoleInput = ""
local consoleLastLen = 0

function panel.render()
	imgui.begin_child("consoleLog", 0, -40, imgui.ChildFlags_AutoResizeY)
	imgui.push_font(af.lucidaFont)

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
end

return panel
