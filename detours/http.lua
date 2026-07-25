local client = ffi.module.find("client.dll")
if curl_easy_setopt_detour then
	curl_easy_setopt_detour:remove()
	curl_easy_setopt_detour = nil -- In case of hot-reload, remove the old detour first
end

local curl_easy_setopt = ffi.module.scan(
	client,
	"89 54 24 10 4C 89 44 24 18 4C 89 4C 24 20 48 83 EC 28 48 85 C9 75 08 8D 41 2B 48 83 C4 28 C3 4C 8D 44 24 40 E8 E7 D2 FF FF 48 83 C4 28 C3"
)

local detour = {}

if curl_easy_setopt then
	local whitelist = lje.include("lib/http_whitelist.lua")
	local entries = {}
	for _, domain in ipairs(whitelist) do
		table.insert(entries, string.format("%q", domain))
	end

	-- http.c is a template: bake the whitelist in as a literal C array before
	-- compiling, rather than trying to call back into Lua per-request.
	local source = lje.env.read_script_file("detours/http.c")
	source = source:gsub("__WHITELIST_COUNT__", tostring(#entries))
	source = source:gsub("__WHITELIST_ENTRIES__", table.concat(entries, ", "))

	local createErr
	curl_easy_setopt_detour, createErr = ffi.detour.create(curl_easy_setopt, source)

	if not curl_easy_setopt_detour then
		lje.con_printf("$red{[http] Failed to create detour: %s}", tostring(createErr))
		return detour
	end

	local ringBase = curl_easy_setopt_detour:get("url_ring") -- &url_ring[0][0]
	local headPtr = curl_easy_setopt_detour:get("url_head")

	if not ringBase or not headPtr then
		lje.con_printf(
			"$red{[http] Failed to resolve ring symbols (url_ring=%s url_head=%s)}",
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
			lje.con_printf("$red{[urls] dropped %d (poller fell behind)}", dropped)
			seen = head - URL_CAP -- skip to oldest still-live slot
		end

		while seen < head do
			local slot = seen % URL_CAP
			local addr = ringBase + slot * URL_MAX
			local entry = ffi.mem.read_string(addr) -- first byte is 'A'/'B' status tag
			local status, url = entry:sub(1, 1), entry:sub(2)
			if status == "A" then
				af.log(string.format("[http] $green{ALLOW} %s", url))
			else
				af.log(string.format("[http] $red{BLOCK} %s", url))
			end
			seen = seen + 1
		end
	end

	function detour:cleanup()
		curl_easy_setopt_detour:disable()
		curl_easy_setopt_detour = nil
	end

	lje.con_printf("Created detour for curl_easy_setopt at address: 0x%X", curl_easy_setopt)
else
	lje.con_printf("$red{Failed to find curl_easy_setopt address}")
end

return detour
