local panel = {
	label = "Net Log",
	title = "Antifreeze | Net Log",
	visible = false,
}

local netAutoScroll = false
local netFilter = ""
local netFilterInvert = false
local netOnlySend = false

-- Lua string literal that round-trips arbitrary bytes (binary WriteData
-- payloads included), escaping anything non-printable as \ddd
local function luaQuote(s)
	-- zero-padded so a following digit can't extend the escape ("\1" .. "2" ~= "\12")
	local escaped = string.gsub(s, "[%c\"\\\128-\255]", function(c)
		if c == "\"" or c == "\\" then
			return "\\" .. c
		end
		return string.format("\\%03d", string.byte(c))
	end)
	return "\"" .. escaped .. "\""
end

local function vectorArgs(raw)
	local x, y, z = string.match(raw, "^(%S+) (%S+) (%S+)$")
	if not x then
		return nil
	end
	return x .. ", " .. y .. ", " .. z
end

local VECTOR_CTOR = {
	WriteVector = "Vector", ReadVector = "Vector",
	WriteNormal = "Vector", ReadNormal = "Vector",
	WriteAngle = "Angle", ReadAngle = "Angle",
}

-- Write* field -> the net.WriteXxx(...) call that reproduces it
local function writeCall(field)
	local fn, raw = field.fn, field.raw or field.value
	local vec = VECTOR_CTOR[fn]

	if fn == "WriteUInt" or fn == "WriteInt" then
		return string.format("net.%s(%s, %d)", fn, raw, field.bits or 32)
	elseif fn == "WriteString" then
		return string.format("net.WriteString(%s)", luaQuote(raw))
	elseif fn == "WriteData" then
		return string.format("net.WriteData(%s, %d)", luaQuote(raw), #raw)
	elseif vec then
		local args = vectorArgs(raw)
		if not args then
			return nil
		end
		return string.format("net.%s(%s(%s))", fn, vec, args)
	elseif fn == "WriteMatrix" then
		return nil
	end
	return string.format("net.%s(%s)", fn, raw)
end

-- Read* field -> the net.ReadXxx(...) call that consumed it
local function readCall(field)
	local fn = field.fn
	if fn == "ReadUInt" or fn == "ReadInt" then
		return string.format("net.%s(%d)", fn, field.bits or 32)
	elseif fn == "ReadData" then
		return string.format("net.ReadData(%d)", #(field.raw or ""))
	end
	return string.format("net.%s()", fn)
end

-- Values were captured as text: numbers via %g (6 significant digits) and
-- strings/data capped at the ring's VALUE_MAX, so lossy fields get flagged
local function fieldNotes(field)
	local notes = {}
	if field.truncated then
		table.insert(notes, "truncated in log")
	end
	if (field.fn == "WriteFloat" or field.fn == "WriteDouble") and string.find(field.raw or "", "[eE.]") then
		table.insert(notes, "logged at %g precision")
	end
	if #notes == 0 then
		return ""
	end
	return " -- " .. table.concat(notes, ", ")
end

local function lineToLua(line)
	local out = {}

	if line.direction == "send" then
		table.insert(out, string.format("net.Start(%s)", luaQuote(line.name)))
		for _, field in ipairs(line.fields) do
			local call = writeCall(field)
			if call then
				table.insert(out, call .. fieldNotes(field))
			else
				table.insert(out, string.format("-- net.%s(<%s>) -- value not reproducible", field.fn, tostring(field.value)))
			end
		end
		table.insert(out, "net.SendToServer()")
	else
		table.insert(out, string.format("net.Receive(%s, function(len)", luaQuote(line.name)))
		for i, field in ipairs(line.fields) do
			local value = tostring(field.value)
			if string.find(value, "\n", 1, true) then
				value = luaQuote(field.raw or value)
			end
			table.insert(out, string.format("\tlocal v%d = %s -- %s", i, readCall(field), value))
		end
		table.insert(out, "end)")
	end

	return table.concat(out, "\n")
end

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
		if netOnlySend and line.direction ~= "send" then continue end
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

		imgui.same_line()
		-- must be stable across frames: a click is press+release on the same ID
		imgui.push_id(tostring(line))
		if imgui.button("Copy") then
			SetClipboardText(lineToLua(line))
			print(lineToLua(line))
		end
		if imgui.is_item_hovered() then
			imgui.set_tooltip("Copy as Lua")
		end
		imgui.pop_id()

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

			if field.bits then
				imgui.same_line()
				imgui.text_colored(0.6, 0.6, 0.6, 1, field.bits .. " bits")
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

	imgui.same_line()

	local _, checked = imgui.checkbox("Only Send", netOnlySend)
	netOnlySend = checked

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
