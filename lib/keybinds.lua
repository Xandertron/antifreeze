-- bare global, not `local` - see the note in commands.lua for why
keybinds = keybinds or {}
keybinds.registry = keybinds.registry or {} -- key -> command string
keybinds.keyCodes = keybinds.keyCodes or {} -- key -> resolved KEY_* constant
keybinds.state = keybinds.state or {} -- key -> was it down last frame (for rising-edge detection)

local STORAGE_KEY = "antifreeze_keybinds"

local function persist()
	lje.data.write(STORAGE_KEY, util.TableToJSON(keybinds.registry, true))
end

local function resolveKeyCode(key)
	return _G["KEY_" .. string.upper(key)]
end

do
	local json = lje.data.read(STORAGE_KEY)
	keybinds.registry = (json and util.JSONToTable(json)) or {}

	keybinds.keyCodes = {}
	for key in pairs(keybinds.registry) do
		keybinds.keyCodes[key] = resolveKeyCode(key)
	end
end

function keybinds.bind(key, command)
	key = string.lower(key)

	local keyCode = resolveKeyCode(key)
	if not keyCode then
		return false, "not a recognized key name: " .. key
	end

	keybinds.registry[key] = command
	keybinds.keyCodes[key] = keyCode
	keybinds.state[key] = false
	persist()

	return true
end

function keybinds.unbind(key)
	key = string.lower(key)

	if not keybinds.registry[key] then
		return false
	end

	keybinds.registry[key] = nil
	keybinds.keyCodes[key] = nil
	keybinds.state[key] = nil
	persist()

	return true
end
hook.Add("Think", "antifreeze.keybinds.poll", function()
	if vgui.CursorVisible() then return end
	for key, keyCode in pairs(keybinds.keyCodes) do
		local isDown = input.IsKeyDown(keyCode)
		if isDown and not keybinds.state[key] then
			af.commands.run(keybinds.registry[key])
		end
		keybinds.state[key] = isDown
	end
end)

af.commands.register(
	"bind",
	"Binds a key to a console command, polled locally each frame - e.g. \"bind p toggle fullbright\". Not a real engine bind, so it never touches config.cfg.",
	function(argsStr)
		local key, command = argsStr:match("^(%S+)%s+(.+)$")
		if not key or not command then
			return "Usage: bind <key> <command...>"
		end

		local ok, err = keybinds.bind(key, command)
		if not ok then
			return err
		end

		return string.format("bound %s -> %s", key, command)
	end
)

af.commands.register("unbind", "Removes an antifreeze bind from a key, e.g. \"unbind p\".", function(argsStr)
	local key = argsStr:match("^%S+")
	if not key or not keybinds.unbind(key) then
		return "No antifreeze bind on " .. tostring(key)
	end

	return "unbound " .. key
end)

af.commands.register("binds", "Lists all antifreeze-managed keybinds.", function()
	local keys = {}
	for key in pairs(keybinds.registry) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	if #keys == 0 then
		af.commands.print("No antifreeze binds set.")
		return
	end

	for _, key in ipairs(keys) do
		af.commands.print(string.format("  %s -> %s", key, keybinds.registry[key]))
	end
end)

return keybinds
