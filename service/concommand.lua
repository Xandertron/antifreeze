hook.pre("PlayerBindPress", "antifreeze.ccmd.pbpblocker", function(ply, bind, pressed)
	--pressed argument is busted in gmod, if you return true if pressed, it will trigger the hook again with false when the keybind is released
	-- split on ';'
	local hide = false
	for segment in string.gmatch(bind, "[^;]+") do
		local trimmed = string.match(segment, "^%s*(.-)%s*$") -- trim whitespace
		local cmd, argStr = string.match(trimmed, "^(%S+)%s*(.*)$") -- extract command + arg string
		if cmd and af.concmds[cmd] then
			hide = true

			-- build argv table
			local argv = {}
			for arg in string.gmatch(argStr, "%S+") do
				argv[#argv + 1] = arg
			end

			-- run command manually
			if pressed then
				af.concmds[cmd].func(ply, cmd, argv, argStr)
			end
		end
	end
	-- swallow the bind so nothing else sees it
	if hide then
		return true
	end
end)