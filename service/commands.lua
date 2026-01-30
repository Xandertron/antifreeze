local function helpFor(node, path)
	local cmds = {}
	for k, v in pairs(node) do
		if k ~= "__default" and (type(v) == "table" or type(v) == "function") then
			cmds[#cmds + 1] = k
		end
	end
	table.sort(cmds)

	print("usage:", table.concat(path, " "), "<" .. table.concat(cmds, " | ") .. ">")
end

local function attachHelp(node, path)
	path = path or {}

	if type(node) ~= "table" then
		return
	end

	if not node.__default then
		node.__default = function(bad)
			if bad then
				print("unknown subcommand:", bad)
			end
			helpFor(node, path)
		end
	end

	for k, v in pairs(node) do
		if k ~= "__default" and type(v) == "table" then
			local newPath = { unpack(path) }
			newPath[#newPath + 1] = k
			attachHelp(v, newPath)
		end
	end
end

local function dispatch(node, args, index)
	index = index or 1

	-- If we hit a function, execute it with remaining args
	if type(node) == "function" then
		return node(unpack(args, index))
	end

	-- Invalid command tree
	if type(node) ~= "table" then
		return
	end

	local key = args[index]

	-- No more args → try __default
	if not key then
		local def = node.__default
		if type(def) == "function" then
			return def()
		end
		return
	end

	local nextNode = node[key]

	-- Unknown subcommand
	if not nextNode then
		local def = node.__default
		if type(def) == "function" then
			return def(key)
		end

		-- fallback error message
		print(("unknown subcommand: %s"):format(tostring(key)))
		return
	end

	return dispatch(nextNode, args, index + 1)
end

return { dispatch = dispatch, attachHelp = attachHelp }
