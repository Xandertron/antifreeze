local lje = lje or {}
af = af or {}
local environment = lje.env.get()
environment.af = af
--run these scripts before init.lua

lje.require("module/antiscreengrab.lua")
lje.require("detour/concommand.lua")
lje.require("detour/http.lua")
