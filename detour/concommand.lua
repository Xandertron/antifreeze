af.concmds = af.concmds or {}

function af.concmdAdd(name, desc, flags, func)
	AddConsoleCommand(name, desc or "", flags or 0)
	af.concmds[name] = {}
	af.concmds[name].func = func
end

lje.vm.add_engine_call_hook(function(func, nargs, nresults, ...)
	if nargs > 0 then
		if func == lje.get_global("concommand", "Run") then
			local ply, cmd, args, argStr = ...
			if af.concmds[cmd] and af.concmds[cmd].func then
				lje.con_print("[AF] Executing console command: " .. cmd)
				af.concmds[cmd].func(ply, cmd, args, argStr)
				return false, true -- Block the original function call.
			end
		end
	end
	return true
end)

local function escape_pattern(str)
	return string.gsub(str, "([^%w])", "%%%1")
end

local function containsAFCmd(cmd)
	if not cmd then
		return false
	end
	for commandName in pairs(af.concmds) do
		local pattern = "^" .. escape_pattern(commandName) .. "%f[%s%z]"
		if string.match(cmd, pattern) then
			return true
		end
	end
	return false
end

_G.input.LookupKeyBinding = lje.detour(_G.input.LookupKeyBinding, function(key, ...)
	if key == nil then
		return input.LookupKeyBinding(key, ...)
	end
	if containsAFCmd(input.LookupKeyBinding(key, ...)) then
		return ""
	end
	return input.LookupKeyBinding(key, ...)
end)

_G.input.LookupBinding = lje.detour(_G.input.LookupBinding, function(bind, exact, ...)
	if bind == nil then
		return input.LookupBinding(bind, exact, ...)
	end
	if containsAFCmd(bind) then
		return nil
	end
	return input.LookupBinding(bind, exact, ...)
end)

af.concmdAdd("lua_run_lje", "Runs lua in LJE's environment", 0, function(_, _, _, argsStr)
	local func = lje.func.compile(argsStr)
	if func then
		local success, err = pcall(func)
		if not success then
			lje.con_print(err)
		end
	end
end)
