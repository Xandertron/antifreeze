local html_chromium = ffi.module.find("html_chromium.dll")
local openUrlThunk = ffi.module.scan(
	html_chromium,
	"4C 8B DC 49 89 5B 08 49 89 73 18 57 48 83 EC 70 48 8B 05 11 A3 06 00 48 33 C4 48 89 44 24 60 33 F6 49 C7 43 E0 0F 00 00 00 48 8D 05 00 A1 FF FF"
)

if not openUrlThunk then
	lje.con_printf("$red{Failed to find OpenURL thunk address}")
	return
end

lje.con_printf("Found OpenURL thunk at address: 0x%X", openUrlThunk)

local detour = {}

if openUrlDetour then
	openUrlDetour:remove()
	openUrlDetour = nil -- In case of hot-reload, remove the old detour first
	lje.con_printf("Removed existing OpenURL detour")
end

lje.con_printf("Creating detour for OpenURL at address: 0x%X", openUrlThunk)
openUrlDetour, openUrlDetourError = ffi.detour.create(openUrlThunk, lje.env.read_script_file("detours/openurl.c"))
if openUrlDetourError then
	lje.con_printf("$red{Failed to create OpenURL detour: %s}", openUrlDetourError)
	return
end
lje.con_printf("Created detour for OpenURL at address: 0x%X", openUrlThunk)

local ringBase = openUrlDetour:get("url_ring") -- &url_ring[0][0]
local headPtr = openUrlDetour:get("url_head")

if not ringBase or not headPtr then
	lje.con_printf(
		"$red{[openurl] Failed to resolve ring symbols (url_ring=%s url_head=%s)}",
		tostring(ringBase),
		tostring(headPtr)
	)
	return detour
end

-- initialize head to be sure
ffi.mem.try_write_u32(headPtr, 0)
local URL_CAP, URL_MAX = 256, 1024
local seen = 0

function detour:run()
	local head = ffi.mem.try_read_u32(headPtr)
	if not head then
		return
	end

	if head - seen > URL_CAP then
		local dropped = head - seen - URL_CAP
		lje.con_printf("$red{[openurl] dropped %d (poller fell behind)}", dropped)
		seen = head - URL_CAP -- skip to oldest still-live slot
	end

	while seen < head do
		local slot = seen % URL_CAP
		local addr = ringBase + slot * URL_MAX
		local entry = ffi.mem.read_string(addr) -- first byte is 'A'/'B' status tag
		local status, url = entry:sub(1, 1), entry:sub(2)
		if status == "A" then
			af.log(string.format("[openurl] $green{ALLOW} %s", url))
		else
			af.log(string.format("[openurl] $red{BLOCK} %s", url))
		end
		seen = seen + 1
	end
end

function detour:cleanup()
	if openUrlDetour then
		openUrlDetour:remove()
		openUrlDetour = nil
		lje.con_printf("Cleaned up OpenURL detour")
	end
end

return detour
