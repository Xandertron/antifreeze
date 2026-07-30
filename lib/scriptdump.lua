-- Captures every Lua chunk the game state loads (via lje.util's script hook)
-- and lets you zip up what's been seen so far to a real .zip on disk.
--
-- This only ever sees code that's already been sent to your own client to
-- run locally - the same plaintext GMod itself downloads and caches. It's a
-- personal-review tool: it writes locally and does nothing to help you share
-- or redistribute what it captures. Don't use it to that end.
--
-- Note: LJE only allows one script-hook callback process-wide (registering a
-- new one silently replaces whatever was registered before). Nothing else in
-- this repo uses lje.util.set_script_hook_callback, so this claims that slot
-- for the life of the script - keep that in mind if you ever add something
-- else that needs it.

-- deliberately a bare global, not `local` - see the note in commands.lua
-- for why that's the part that actually makes this survive a hot-reload
scriptdump = scriptdump or {}

-- Some chunknames get reused across many, entirely different executions -
-- e.g. admin "run this Lua" console commands typically RunString every
-- command under the same fixed chunkname (like "luacmd"), so without this
-- you'd only ever see whichever one happened to run last. Keyed by
-- sanitized name -> ordered array of every distinct source seen under it;
-- collapsed back into one entry per name (joined by a divider) at dump time.
scriptdump.history = scriptdump.history or {} -- sanitized name -> array of source strings, execution order
scriptdump.order = scriptdump.order or {} -- sanitized names in first-seen order, for stable zip ordering

--------------------------------------------------------------------------
-- capture
--------------------------------------------------------------------------

local function sanitizeName(chunkname)
	-- file chunks are conventionally prefixed with "@"; strip it and normalize
	-- separators so the result is a clean, zip-friendly relative path
	local name = chunkname:gsub("^@", ""):gsub("^[/\\]+", ""):gsub("\\", "/")

	-- RunString/CompileString chunks loaded without an explicit chunkname
	-- (common for packed/bundled addons) fall back to Lua's `[string "..."]`
	-- source preview instead of a real path - swap out characters Windows
	-- can't have in a filename (besides "/", which real paths use for
	-- folder structure) so every entry actually extracts cleanly.
	name = name:gsub('[%c"<>|%?%*:]', "_")

	if #name > 80 then
		name = name:sub(1, 80)
	end

	if name == "" then
		name = "unnamed"
	end

	-- real file-based chunks already carry .lua from their path; anonymous
	-- RunString/CompileString chunks generally don't - normalize so every
	-- entry opens with correct syntax highlighting either way
	if not name:lower():match("%.lua$") then
		name = name .. ".lua"
	end

	return name
end

lje.util.set_script_hook_callback(function(chunkname, source)
	local name = sanitizeName(chunkname)

	local history = scriptdump.history[name]
	if not history then
		history = {}
		scriptdump.history[name] = history
		scriptdump.order[#scriptdump.order + 1] = name
	end

	-- skip back-to-back identical reruns (e.g. a plain file that just gets
	-- re-included unchanged) so only genuinely different executions pile up
	if history[#history] ~= source then
		history[#history + 1] = source
	end

	return source -- always pass through unmodified
end)

--------------------------------------------------------------------------
-- crc32 + minimal zip (store method only, no compression)
--------------------------------------------------------------------------

local crcTable

local function crc32(str)
	if not crcTable then
		crcTable = {}
		for i = 0, 255 do
			local c = i
			for _ = 1, 8 do
				if bit.band(c, 1) == 1 then
					c = bit.bxor(0xEDB88320, bit.rshift(c, 1))
				else
					c = bit.rshift(c, 1)
				end
			end
			crcTable[i] = c
		end
	end

	local crc = 0xFFFFFFFF
	for i = 1, #str do
		local byte = string.byte(str, i)
		crc = bit.bxor(crcTable[bit.band(bit.bxor(crc, byte), 0xFF)], bit.rshift(crc, 8))
	end
	return bit.bxor(crc, 0xFFFFFFFF) -- bit.* auto-normalizes negatives, no need to fix up here
end

local function le16(n)
	return string.char(bit.band(n, 0xFF), bit.band(bit.rshift(n, 8), 0xFF))
end

local function le32(n)
	return string.char(
		bit.band(n, 0xFF),
		bit.band(bit.rshift(n, 8), 0xFF),
		bit.band(bit.rshift(n, 16), 0xFF),
		bit.band(bit.rshift(n, 24), 0xFF)
	)
end

-- builds a real, valid PKZIP archive (local file headers + central directory
-- + EOCD) using the store method, so it opens in any normal zip tool.
local function buildZip(entries)
	local localParts = {}
	local centralParts = {}
	local offset = 0

	for _, entry in ipairs(entries) do
		local name, data = entry.name, entry.source
		local crc = crc32(data)
		local size = #data

		local localHeader = table.concat({
			"PK\3\4",
			le16(20), le16(0), le16(0), le16(0), le16(0x21), -- version, flags, method, time, date
			le32(crc), le32(size), le32(size),
			le16(#name), le16(0),
			name,
		})

		localParts[#localParts + 1] = localHeader
		localParts[#localParts + 1] = data

		centralParts[#centralParts + 1] = table.concat({
			"PK\1\2",
			le16(20), le16(20), le16(0), le16(0), le16(0), le16(0x21), -- version made by/needed, flags, method, time, date
			le32(crc), le32(size), le32(size),
			le16(#name), le16(0), le16(0), le16(0), le16(0), le32(0), -- name len, extra len, comment len, disk#, int attrs, ext attrs
			le32(offset),
			name,
		})

		offset = offset + #localHeader + #data
	end

	local localData = table.concat(localParts)
	local centralData = table.concat(centralParts)

	local eocd = table.concat({
		"PK\5\6",
		le16(0), le16(0),
		le16(#entries), le16(#entries),
		le32(#centralData), le32(#localData),
		le16(0),
	})

	return localData .. centralData .. eocd
end

--------------------------------------------------------------------------
-- disk write (real arbitrary path, so lje.data's restricted blob store won't
-- do here). Calls straight into kernel32's real exported addresses via
-- ffi.call.bind - no TCC/compiled-C involved, so there's no import-linking
-- to get wrong. (An earlier version compiled a tiny C helper that called
-- these by name; TCC didn't resolve the WinAPI imports correctly, and the
-- call jumped into garbage that decoded as a privileged instruction and
-- crashed. Resolving the real addresses ourselves sidesteps that entirely.)
--------------------------------------------------------------------------

-- current_script_path() is "<lje root>/scripts/antifreeze" - strip the
-- "scripts/<name>" suffix to get the LJE root (same root .lje/data,
-- .lje/settings, etc. live under) rather than hardcoding a profile path,
-- then dump alongside those as .lje/dumps.
local dumpFolder
do
	local scriptPath = lje.env.current_script_path()
	if scriptPath then
		scriptPath = scriptPath:gsub("[/\\]+$", "")
		local ljeRoot = scriptPath:match("^(.*)[/\\]scripts[/\\][^/\\]+$")
		if ljeRoot then
			dumpFolder = ljeRoot .. "/dumps"
		end
	end
end

local GENERIC_WRITE = 0x40000000
local CREATE_ALWAYS = 2
local FILE_ATTRIBUTE_NORMAL = 0x80
local ERROR_ALREADY_EXISTS = 183

local kernel32 = ffi.module.find("kernel32.dll")

local function bindExport(name, sig)
	if not kernel32 then
		return nil
	end
	local addr = ffi.module.export(kernel32, name)
	if not addr or addr == 0 then
		return nil
	end
	return ffi.call.bind(addr, sig)
end

-- signature chars: v i u l f d b p s (first = return type)
local win32CreateDirectoryA = bindExport("CreateDirectoryA", "isp")
local win32GetLastError = bindExport("GetLastError", "u")
local win32CreateFileA = bindExport("CreateFileA", "psuupuup")
local win32WriteFile = bindExport("WriteFile", "ippupp")
local win32CloseHandle = bindExport("CloseHandle", "ip")

local kernel32Ready = win32CreateDirectoryA
	and win32GetLastError
	and win32CreateFileA
	and win32WriteFile
	and win32CloseHandle

if not kernel32Ready then
	af.log("scriptdump: failed to resolve kernel32 exports", "error")
end

local function lastErrorString()
	local code = win32GetLastError and win32GetLastError()
	return code and ("error " .. tostring(code)) or "unknown error"
end

-- path -> ok, err
local function ensureDir(path)
	if not kernel32Ready then
		return false, "kernel32 functions unavailable"
	end

	local ok = win32CreateDirectoryA(path, 0)
	if ok ~= 0 then
		return true
	end

	if win32GetLastError() == ERROR_ALREADY_EXISTS then
		return true
	end

	return false, "CreateDirectoryA failed (" .. lastErrorString() .. ")"
end

-- path, address, size -> ok, err
local function writeFile(path, address, size)
	if not kernel32Ready then
		return false, "kernel32 functions unavailable"
	end

	local handle = win32CreateFileA(path, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
	if not handle or handle == 0 then
		return false, "CreateFileA failed (" .. lastErrorString() .. ")"
	end

	local writtenPtr = ffi.mem.alloc(4)
	ffi.mem.write_u32(writtenPtr, 0)

	local ok = win32WriteFile(handle, address, size, writtenPtr, 0)
	local written = ffi.mem.try_read_u32(writtenPtr) or 0

	ffi.mem.free(writtenPtr)
	win32CloseHandle(handle)

	if ok == 0 or written ~= size then
		return false, "WriteFile failed or incomplete"
	end

	return true
end

--------------------------------------------------------------------------
-- output filename: "<servername>_<ip-port>_<time>.zip"
--------------------------------------------------------------------------

-- neither is in the default pulled-globals set, so pull them explicitly
local getHostName = lje.secure.pull("GetHostName")
local getIPAddress = lje.secure.pull("game.GetIPAddress")

-- strips anything that isn't ASCII alnum/dash/dot/underscore (covers both
-- "prune non-ASCII" and Windows filename-illegal characters in one pass -
-- server hostnames routinely carry Unicode, color codes, emoji, etc.)
local function sanitizeForFilename(str, maxLen)
	str = tostring(str or "")
	str = str:gsub("[\128-\255]", "")
	str = str:gsub("[^%w%-%._]", "_")
	str = str:gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
	if maxLen then
		str = str:sub(1, maxLen)
	end
	if str == "" then
		str = "unknown"
	end
	return str
end

local function buildDumpFilename()
	local hostname = getHostName and getHostName()
	local ipport = getIPAddress and getIPAddress()

	local serverPart = sanitizeForFilename(hostname, 12)
	-- ":" isn't valid in a Windows filename - swap for "-" before the
	-- generic sanitize pass so it stays readable as "ip-port" instead of
	-- collapsing into an underscore alongside everything else
	local addrPart = sanitizeForFilename(ipport and ipport:gsub(":", "-"))

	return string.format("%s_%s_%d.zip", serverPart, addrPart, os.time())
end

--------------------------------------------------------------------------
-- collapse a captured name's execution history into one displayable string,
-- joining re-runs with a divider - shared by the zip export below and by
-- services/ui.lua's explorer tab code viewer, so both show the same thing
--------------------------------------------------------------------------

function scriptdump.getSource(name)
	local history = scriptdump.history[name]
	if not history then
		return nil
	end

	if #history == 1 then
		return history[1]
	end

	local parts = {}
	for i, source in ipairs(history) do
		if i > 1 then
			parts[#parts + 1] = string.format("\n\n--[[ scriptdump: execution %d/%d ]]\n\n", i, #history)
		end
		parts[#parts + 1] = source
	end
	return table.concat(parts)
end

-- flatten { name -> {history...} } into buildZip's { name, source } entries
local function buildEntries()
	local entries = {}
	for _, name in ipairs(scriptdump.order) do
		entries[#entries + 1] = { name = name, source = scriptdump.getSource(name) }
	end
	return entries
end

--------------------------------------------------------------------------
-- commands
--------------------------------------------------------------------------

af.commands.register(
	"dumpscripts",
	"Zips every script captured so far and writes it to .lje/dumps/.",
	function()
		if not dumpFolder then
			return "scriptdump: not available (no script context at load time)."
		end

		if #scriptdump.order == 0 then
			return "No scripts captured yet."
		end

		local dirOk, dirErr = ensureDir(dumpFolder)
		if not dirOk then
			return "Failed to create the dumps folder (" .. tostring(dirErr) .. ")."
		end

		local entries = buildEntries()
		local zipData = buildZip(entries)
		local path = dumpFolder .. "/" .. buildDumpFilename()

		local buf = ffi.mem.alloc(#zipData)
		ffi.mem.copy_from_string(buf, zipData)
		local ok, err = writeFile(path, buf, #zipData)
		ffi.mem.free(buf)

		if not ok then
			return "Failed to write " .. path .. " (" .. tostring(err) .. ")."
		end

		local totalRuns = 0
		for _, history in pairs(scriptdump.history) do
			totalRuns = totalRuns + #history
		end

		return string.format("Wrote %d file(s) (%d executions total) to %s", #entries, totalRuns, path)
	end
)

af.commands.register("dumpclear", "Clears the in-memory capture buffer used by \"dumpscripts\".", function()
	scriptdump.history = {}
	scriptdump.order = {}
	return "Cleared captured scripts."
end)

return scriptdump
