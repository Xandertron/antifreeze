local nog = nog or {}
nog.logs = nog.logs or {}
nog.current = nil
nog.maxEntries = 100
nog.blacklistedNames = { "URPC" } --todo, make ui for this

function nog.trimEntries()
    local excess = #nog.logs - nog.maxEntries or 100
    if excess > 0 then
        for i = 1, excess do
            table.remove(nog.logs, 1)
        end
    end
end

local function logField(direction, fn, value)
	if nog.current then
		table.insert(nog.current.fields, { fn = fn, value = value })
	end
end

local function beginMessage(direction, name)
	nog.current = {
		direction = direction,
		name = name,
		fields = {},
		time = os.date("%X"),
	}
	table.insert(nog.logs, nog.current)
	nog.trimEntries()
end

local origNetStart = net.Start
local function netStart(messageName, unreliable)
	beginMessage("send", messageName)
	return origNetStart(messageName, unreliable)
end
_G.net.Start = lje.detour(origNetStart, netStart)

local origNetReadHeader = net.ReadHeader
local function netReadHeader()
	local i = origNetReadHeader()
	beginMessage("receive", util.NetworkIDToString(i))
	return i
end
_G.net.ReadHeader = lje.detour(origNetReadHeader, netReadHeader)

local function hookNet(fnName)
	local orig = net[fnName]
	if not orig then
		return
	end

	local isReading = string.sub(fnName, 1, 4) == "Read"
	local isWriting = string.sub(fnName, 1, 5) == "Write"

	local function hooked(...)
		local result = orig(...)
		local captured = isReading and result or (...)
		logField(isReading, fnName, captured)
		return result
	end

	_G.net[fnName] = lje.detour(orig, hooked)
end

local netFunctions = {
	--writes
	"WriteAngle",
	"WriteBit",
	"WriteBool",
	"WriteColor",
	"WriteData",
	"WriteDouble",
	"WriteEntity",
	"WriteFloat",
	"WriteInt",
	"WriteMatrix",
	"WriteNormal",
	"WriteString",
	"WriteTable",
	"WriteType",
	"WriteUInt",
	"WriteVector",
	--reads
	"ReadAngle",
	"ReadBit",
	"ReadBool",
	"ReadColor",
	"ReadData",
	"ReadDouble",
	"ReadEntity",
	"ReadFloat",
	"ReadInt",
	"ReadMatrix",
	"ReadNormal",
	"ReadString",
	"ReadTable",
	"ReadType",
	"ReadUInt",
	"ReadVector",
}

for _, fnName in ipairs(netFunctions) do
	hookNet(fnName)
end

function nog.dump(entry)
	print(string.format("[%s] %s %s", entry.time, entry.direction and "▼" or "▲", entry.name))
	for _, field in ipairs(entry.fields) do
		local val = field.value
		local display
		if type(val) == "table" then
			display = "[table]"
		elseif val == nil then
			display = "nil"
		else
			display = tostring(val)
		end
		print(string.format("    %s = %s", field.fn, display))
	end
end

function nog.dumpAll()
	for _, entry in ipairs(nog.logs) do
		nog.dump(entry)
	end
end

function nog.clear()
	nog.logs = {}
	nog.current = nil
end

return nog
