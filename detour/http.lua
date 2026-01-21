-- No state necessary for this module, just needs a detour
local HWL = lje.require("service/http_whitelist.lua")
local origHttp = HTTP

local function httpHk(params)
	lje.hooks.disable()
	lje.env.disable_metatables()

	local url = rawget(params, "url") or ""

	if type(url) ~= "string" then
		url = tostring(url)
	end

	lje.con_printf("[AF] [HTTP] HTTP request to URL: $yellow{%s}", url)

	if not HWL.isWhitelisted(url) then
		lje.con_printf("[AF] [HTTP] Blocked HTTP request to URL: $red{%s}", url)
		lje.env.enable_metatables()
		lje.hooks.enable()
		return true -- make them think it was queued
	end

	lje.env.enable_metatables()
	lje.hooks.enable()

	return origHttp(params)
end

rawset(_G, "HTTP", lje.detour(origHttp, httpHk))

local origPanelOpenURL = FindMetaTable("Panel").OpenURL
local function panelOpenUrlHk(self, url)
	lje.hooks.disable()
	lje.env.disable_metatables()
	lje.con_printf("[AF] [Panel:OpenURL] Attempt to open URL: $yellow{%s}", url)
	if HWL.isWhitelisted(url) then
		lje.con_printf("[AF] [Panel:OpenURL] Allowing URL: $yellow{%s}", url)
		lje.env.enable_metatables()
		lje.hooks.enable()
		return origPanelOpenURL(self, url)
	else
		lje.con_printf("[AF] [Panel:OpenURL] Blocking URL: $red{%s}", url)
		lje.env.enable_metatables()
		lje.hooks.enable()
		return
	end
end

FindMetaTable("Panel").OpenURL = lje.detour(origPanelOpenURL, panelOpenUrlHk)

local origGuiOpenURL = gui.OpenURL
local function guiOpenUrlHk(url)
	lje.hooks.disable()
	lje.env.disable_metatables()
	lje.con_printf("[AF] [gui.OpenURL] Attempt to open URL: $yellow{%s}", url)
	if HWL.isWhitelisted(url) then
		lje.con_printf("[AF] [gui.OpenURL] Allowing URL: $yellow{%s}", url)
		lje.env.enable_metatables()
		lje.hooks.enable()
		return origGuiOpenURL(url)
	else
		lje.con_printf("[AF] [gui.OpenURL] Blocking URL: $red{%s}", url)
		lje.env.enable_metatables()
		lje.hooks.enable()
		return
	end
end

_G.gui.OpenURL = lje.detour(origGuiOpenURL, guiOpenUrlHk)
