local level = {
	warn = "[$yellow{WARN}]",
	error = "[$red{ERR} ]",
	info = "[INFO]",
	debug = "[$green{DBG} ]"
}

local function log(msg, lvl)
	if lvl == level.debug and not af.debug then return end
	lje.con_printf(string.format("[AF] %s %s", level[lvl] or level.info, msg))
end

return log, level