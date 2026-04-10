local lje = lje or {}
af = af or {}
local environment = lje.env.get()
environment.af = af

af.debug = false

af.level = {
	warn = "[$yellow{WARN}]",
	error = "[$red{ERR} ]",
	info = "[INFO]",
	debug = "[$green{DBG} ]"
}

function af.log(msg, lvl)
	if lvl == af.level.debug and not af.debug then return end
	lje.con_printf(string.format("[AF] %s %s", lvl or af.level.info, msg))
end

--run these scripts before init.lua
lje.require("module/antiscreengrab.lua")
lje.require("detour/concommand.lua")
lje.require("detour/http.lua")