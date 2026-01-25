local commands = {}

local function concmdAdd(name, desc, flags, func)
	AddConsoleCommand(name, desc or "", flags or 0)
	commands[name] = {}
	commands[name].func = func
end

lje.vm.add_engine_call_hook(function(func, nargs, nresults, ...)
	if nargs > 0 then
		if func == lje.get_global("concommand", "Run") then
			local ply, cmd, args, argStr = ...
			if commands[cmd] and commands[cmd].func then
				commands[cmd].func(ply, cmd, args, argStr)
				return false, true -- Block the original function call.
			end
		end
	end
	return true
end)

return concmdAdd