local panel = {
	label = "Explorer",
	title = "Antifreeze | Explorer",
	visible = false,
}

local explorerPath = "" -- "" = root, otherwise ends with "/"
local explorerSelected = nil -- full captured name currently shown in the code pane
local explorerSearch = ""
local explorerPendingScroll = nil -- nil = nothing to do; "top"; or a line number to jump to, consumed on next render
local explorerHighlightLines = nil -- persists (unlike explorerPendingScroll): set of lineNum -> true to mark with a gutter arrow, or nil
local explorerLiveSearch = false -- toggled by the "Live Search" button
local explorerSearchChangedAt = nil -- SysTime() of the last search-box edit; nil = no debounce pending

local function accent()
	local c = af.brand.color
	return c.r / 255, c.g / 255, c.b / 255
end

-- splits af.scriptdump's captured names (flat "a/b/c.lua"-style paths) into
-- the immediate subfolders and files living directly under `prefix` - just
-- enough to drive folder-button navigation, no persistent tree/expand
-- state needed since we only ever look at one level at a time
local function explorerList(prefix)
	local seenFolders = {}
	local folders = {}
	local files = {} 

	for _, name in ipairs(af.scriptdump.order) do
		if name:sub(1, #prefix) == prefix then
			local rest = name:sub(#prefix + 1)
			local slashPos = rest:find("/", 1, true)
			if slashPos then
				local folderName = rest:sub(1, slashPos - 1)
				if not seenFolders[folderName] then
					seenFolders[folderName] = true
					folders[#folders + 1] = folderName
				end
			else
				files[#files + 1] = { name = name, label = rest }
			end
		end
	end

	table.sort(folders)
	table.sort(files, function(a, b)
		return a.label < b.label
	end)

	return folders, files
end

-- flat, case-insensitive substring search across every captured name,
-- ignoring the current folder - a match three levels deep should still
-- show up without having to navigate to it first
local function explorerSearchResults(query)
	local lowerQuery = query:lower()
	local results = {}

	for _, name in ipairs(af.scriptdump.order) do
		if name:lower():find(lowerQuery, 1, true) then
			results[#results + 1] = name
		end
	end

	table.sort(results)
	return results
end

-- searches actual file contents rather than just names - heavier (has to
-- collapse/scan every captured file's full source), so this is triggered
-- by an explicit button rather than running on every keystroke
local function explorerContentSearchResults(query)
	local lowerQuery = query:lower()
	local results = {}

	for _, name in ipairs(af.scriptdump.order) do
		local source = af.scriptdump.getSource(name)
		if source and source:lower():find(lowerQuery, 1, true) then
			results[#results + 1] = name
		end
	end

	table.sort(results)
	return results
end

-- every line number (1-based) where `query` occurs, case-insensitively -
-- uses the exact same line splitting as tokenizeSource() below so the
-- numbers line up with what actually gets rendered
local function findMatchLines(source, query)
	local lowerQuery = query:lower()
	local lines = {}
	local lineNum = 0
	for line in (source .. "\n"):gmatch("([^\n]*)\n") do
		lineNum = lineNum + 1
		if line:lower():find(lowerQuery, 1, true) then
			lines[#lines + 1] = lineNum
		end
	end
	return lines
end

-- total case-insensitive, non-overlapping occurrences of `needle` in `haystack`
local function countOccurrences(haystack, needle)
	local count = 0
	local pos = 1
	while true do
		local s = haystack:find(needle, pos, true)
		if not s then
			break
		end
		count = count + 1
		pos = s + #needle
	end
	return count
end

-- selects a file for the code pane and queues up where the pane should
-- scroll to: the first line matching `query` if we were selected out of a
-- content search, otherwise the top. Also marks every matching line, not
-- just the first, for the gutter arrow below. No-ops if it's already
-- selected, so re-clicking the current file doesn't yank your scroll
-- position back.
local function selectFile(name, query)
	if name == explorerSelected then
		return
	end

	explorerSelected = name

	local matchLines = query and findMatchLines(af.scriptdump.getSource(name) or "", query)

	explorerPendingScroll = (matchLines and matchLines[1]) or "top"

	explorerHighlightLines = nil
	if matchLines and #matchLines > 0 then
		explorerHighlightLines = {}
		for _, lineNum in ipairs(matchLines) do
			explorerHighlightLines[lineNum] = true
		end
	end
end

-- shared by both search modes: a flat list of full names, each with a
-- tooltip showing the full path (long ones get visually cut off in the
-- 220px-wide pane) plus, for content search, how many times it occurs
local function renderResultList(names, emptyMessage, query)
	if #names == 0 then
		imgui.text_colored(0.6, 0.6, 0.6, 1, emptyMessage)
		return
	end

	for _, name in ipairs(names) do
		if imgui.selectable(name, name == explorerSelected) then
			selectFile(name, query)
		end
		if imgui.is_item_hovered() then
			if query then
				local source = af.scriptdump.getSource(name) or ""
				local count = countOccurrences(source:lower(), query:lower())
				imgui.set_tooltip(string.format("%s\n%d occurrence%s", name, count, count == 1 and "" or "s"))
			else
				imgui.set_tooltip(name)
			end
		end
	end
end

--------------------------------------------------------------------------
-- basic Lua syntax highlighting. Tokenizes a whole source string into
-- { line -> { {text, color}, ... } }, cached per selected file (recomputed
-- only when the selection or its capture count changes) so it isn't
-- re-lexed every single frame the window is open.
--------------------------------------------------------------------------

local COLOR_DEFAULT = { 0.85, 0.85, 0.85 }
local COLOR_KEYWORD_LOCAL = { 0.4, 0.6, 1 } -- "local", plus true/false/nil (matches vscode grouping these with it)
local COLOR_KEYWORD_CONTROL = { 0.75, 0.55, 0.95 } -- if/else/for/while/function/etc.
local COLOR_STRING = { 0.85, 0.6, 0.35 } -- soft orange
local COLOR_COMMENT = { 0.5, 0.5, 0.5 }
local COLOR_NUMBER = { 0.65, 0.85, 0.45 } -- light green

local KEYWORDS = {}
for _, kw in ipairs({
	"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto",
	"if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}) do
	KEYWORDS[kw] = true
end

local LOCAL_COLORED_WORDS = { ["local"] = true, ["true"] = true, ["false"] = true, ["nil"] = true }

-- only handles the plain `[[`/`]]` and `--[[`/`]]` forms (no `[=[`-style
-- levels) - covers ordinary code; anything fancier just falls back to
-- being read as a line comment/string instead of crashing or looping
local function tokenizeLine(line, state)
	local spans = {}

	local function push(text, color)
		if text == "" then
			return
		end
		local last = spans[#spans]
		if last and last.color == color then
			last.text = last.text .. text
		else
			spans[#spans + 1] = { text = text, color = color }
		end
	end

	local i = 1
	local n = #line

	if state.inBlockComment or state.inLongString then
		local color = state.inBlockComment and COLOR_COMMENT or COLOR_STRING
		local closeStart, closeEnd = line:find("]]", 1, true)
		if closeStart then
			push(line:sub(1, closeEnd), color)
			i = closeEnd + 1
			state.inBlockComment = false
			state.inLongString = false
		else
			push(line, color)
			return spans
		end
	end

	while i <= n do
		local rest = line:sub(i)

		if rest:sub(1, 4) == "--[[" then
			local closeStart, closeEnd = line:find("]]", i + 4, true)
			if closeStart then
				push(line:sub(i, closeEnd), COLOR_COMMENT)
				i = closeEnd + 1
			else
				push(line:sub(i), COLOR_COMMENT)
				state.inBlockComment = true
				i = n + 1
			end
		elseif rest:sub(1, 2) == "--" then
			push(line:sub(i), COLOR_COMMENT)
			i = n + 1
		elseif rest:sub(1, 2) == "[[" then
			local closeStart, closeEnd = line:find("]]", i + 2, true)
			if closeStart then
				push(line:sub(i, closeEnd), COLOR_STRING)
				i = closeEnd + 1
			else
				push(line:sub(i), COLOR_STRING)
				state.inLongString = true
				i = n + 1
			end
		elseif rest:sub(1, 1) == '"' or rest:sub(1, 1) == "'" then
			local quote = rest:sub(1, 1)
			local j = i + 1
			while j <= n do
				local c = line:sub(j, j)
				if c == "\\" then
					j = j + 2
				elseif c == quote then
					j = j + 1
					break
				else
					j = j + 1
				end
			end
			push(line:sub(i, j - 1), COLOR_STRING)
			i = j
		elseif rest:match("^%d") then
			local numStr = rest:match("^0[xX][%da-fA-F]+") or rest:match("^%d+%.?%d*[eE]?[%+%-]?%d*")
			push(numStr, COLOR_NUMBER)
			i = i + #numStr
		elseif rest:match("^[%a_]") then
			local word = rest:match("^[%a_][%w_]*")
			local color = COLOR_DEFAULT
			if LOCAL_COLORED_WORDS[word] then
				color = COLOR_KEYWORD_LOCAL
			elseif KEYWORDS[word] then
				color = COLOR_KEYWORD_CONTROL
			end
			push(word, color)
			i = i + #word
		else
			-- consume up to the next character that could start a special
			-- token, so plain punctuation/whitespace doesn't emit one span
			-- per character
			local stop = rest:find("[%-\"'%[%d%a_]")
			local chunk = stop and rest:sub(1, stop - 1) or rest
			if chunk == "" then
				chunk = rest:sub(1, 1) -- always make progress
			end
			push(chunk, COLOR_DEFAULT)
			i = i + #chunk
		end
	end

	return spans
end

local function tokenizeSource(source)
	source = source:gsub("\r\n", "\n")
	local state = { inBlockComment = false, inLongString = false }
	local lines = {}
	for line in (source .. "\n"):gmatch("([^\n]*)\n") do
		lines[#lines + 1] = tokenizeLine(line, state)
	end
	return lines
end

local explorerTokenized = nil
local explorerTokenizedFor = nil
local explorerTokenizedCount = 0
local explorerContentResults = nil -- non-nil while showing a "Search Contents" result set

function panel.render()
	if not (af.scriptdump and #af.scriptdump.order > 0) then
		imgui.text_colored(1, 0.6, 0.6, 1, "No scripts captured yet.")
		return
	end

	local ar, ag, ab = accent()

	imgui.begin_child("explorerTree", 220, 0, 0)

	imgui.set_next_item_width(140)
	local changed, search = imgui.input_text("Search", explorerSearch)
	if changed then
		explorerSearch = search
		explorerContentResults = nil -- typing invalidates a stale content search
		explorerSearchChangedAt = SysTime()
	end

	local liveChanged, liveOn = imgui.checkbox("Live Search", explorerLiveSearch)
	if liveChanged then
		explorerLiveSearch = liveOn

		if explorerLiveSearch and explorerSearch ~= "" then
			explorerContentResults = explorerContentSearchResults(explorerSearch)
		elseif not explorerLiveSearch then
			explorerContentResults = nil
		end
	end

	-- debounced auto-search: fires 500ms after the last keystroke while live
	-- search is on, instead of re-scanning every file on every keystroke
	if
		explorerLiveSearch
		and explorerSearch ~= ""
		and not explorerContentResults
		and explorerSearchChangedAt
		and SysTime() - explorerSearchChangedAt >= 0.5
	then
		explorerContentResults = explorerContentSearchResults(explorerSearch)
		explorerSearchChangedAt = nil
	end

	imgui.separator()

	if explorerContentResults then
		renderResultList(explorerContentResults, "No content matches.", explorerSearch)
	elseif explorerSearch ~= "" then
		renderResultList(explorerSearchResults(explorerSearch), "No matches.")
	else
		if explorerPath ~= "" then
			if imgui.button("<- ..") then
				explorerPath = explorerPath:gsub("[^/]+/$", "")
			end
		end

		imgui.text_colored(ar, ag, ab, 1, "/" .. explorerPath)
		imgui.separator()

		local folders, files = explorerList(explorerPath)

		for _, folderName in ipairs(folders) do
			if imgui.button(folderName .. "/") then
				explorerPath = explorerPath .. folderName .. "/"
			end
		end

		if #folders > 0 and #files > 0 then
			imgui.separator()
		end

		for _, file in ipairs(files) do
			if imgui.selectable(file.label, file.name == explorerSelected) then
				selectFile(file.name)
			end
			if imgui.is_item_hovered() then
				imgui.set_tooltip(file.name)
			end
		end
	end

	imgui.end_child()

	imgui.same_line()

	imgui.begin_child("explorerCode", 0, 0, 0)
	imgui.push_font(af.lucidaFont)

	if explorerPendingScroll == "top" then
		imgui.set_scroll_here_y(0)
		explorerPendingScroll = nil
	end

	if explorerSelected then
		local history = af.scriptdump.history[explorerSelected]
		local historyCount = history and #history or 0

		if explorerSelected ~= explorerTokenizedFor or historyCount ~= explorerTokenizedCount then
			explorerTokenized = tokenizeSource(af.scriptdump.getSource(explorerSelected) or "")
			explorerTokenizedFor = explorerSelected
			explorerTokenizedCount = historyCount
		end

		for lineIndex, spans in ipairs(explorerTokenized) do
			-- no background-highlight primitive is exposed (no draw list,
			-- no rect fill), so the closest we can get is a gutter marker
			-- ahead of the line's normal, still-syntax-colored text
			if explorerHighlightLines and explorerHighlightLines[lineIndex] then
				imgui.text_colored(ar, ag, ab, 1, "> ")
				imgui.same_line(0, 0)
			end

			if #spans == 0 then
				imgui.text("")
			else
				for i, span in ipairs(spans) do
					imgui.text_colored(span.color[1], span.color[2], span.color[3], 1, span.text)
					if i < #spans then
						imgui.same_line(0, 0)
					end
				end
			end

			-- jump the scroll to whichever line matched, with a little
			-- headroom above it rather than jamming it right at the top edge
			if explorerPendingScroll == lineIndex then
				imgui.set_scroll_here_y(0.2)
				explorerPendingScroll = nil
			end
		end
	else
		imgui.text_colored(0.6, 0.6, 0.6, 1, "Select a file on the left.")
	end

	imgui.pop_font()
	imgui.end_child()
end

return panel
