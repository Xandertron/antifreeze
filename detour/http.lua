-- No state necessary for this module, just needs a detour
lje.require("service/http_whitelist.lua")
local origHttp = HTTP

local function checkURL(url, func)
	local allowed = af.http.isWhitelisted(url)
	af.log(
		string.format("[%s] %s request to $yellow{%s}", func, allowed and "$green{Allowing}" or "$red{Dropping}", url),
		af.level.warn
	)
	return allowed
end

local function httpHk(params)
	lje.gc.begin_track()
	if not params then
		lje.gc.end_track()
		return origHttp(params) -- if it's not a table, just call the original function
	end

	local url = rawget(params, "url") or ""

	if type(url) ~= "string" then
		url = tostring(url)
	end

	if not checkURL(url, "HTTP") then
		lje.gc.end_track()
		return true -- make them think it was queued
	end

	lje.gc.end_track()
	return origHttp(params)
end

rawset(_G, "HTTP", lje.detour(origHttp, httpHk))

local origPanelOpenURL = FindMetaTable("Panel").OpenURL
local function panelOpenUrlHk(self, url)
	if checkURL(url, "Panel:OpenURL") then
		return self:OpenURL(url)
	else
		return
	end
end

FindMetaTable("Panel").OpenURL = lje.detour(origPanelOpenURL, panelOpenUrlHk)

local origGuiOpenURL = gui.OpenURL
local function guiOpenUrlHk(url)
	if checkURL(url, "gui.OpenURL") then
		return origGuiOpenURL(url)
	else
		return
	end
end

_G.gui.OpenURL = lje.detour(origGuiOpenURL, guiOpenUrlHk)
