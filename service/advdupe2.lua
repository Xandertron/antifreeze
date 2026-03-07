--fake file object
local function stringBuffer()
	local self = {}
	local chunks = {}
	local size = 0

	local function push(str)
		size = size + #str
		chunks[#chunks + 1] = str
	end

	function self:WriteByte(b)
		push(string.char(b))
	end

	function self:WriteBool(b)
		push(b and "\1" or "\0")
	end

	function self:WriteShort(n)
		local lo = n % 256
		local hi = math.floor(n / 256) % 256
		push(string.char(lo, hi))
	end

	function self:WriteULong(n)
		local b1 = n % 256
		local b2 = math.floor(n / 256) % 256
		local b3 = math.floor(n / 65536) % 256
		local b4 = math.floor(n / 16777216) % 256
		push(string.char(b1, b2, b3, b4))
	end

	function self:WriteDouble(n)
		-- IEEE-754 double, little endian
		local sign = n < 0 and 1 or 0
		n = math.abs(n)

		if n == 0 then
			push("\0\0\0\0\0\0\0\0")
			return
		end

		local mantissa, exponent = math.frexp(n)
		exponent = exponent + 1022

		mantissa = (mantissa * 2 - 1) * 2 ^ 52

		local bytes = {}

		for i = 1, 6 do
			bytes[i] = mantissa % 256
			mantissa = math.floor(mantissa / 256)
		end

		local hi = mantissa % 16
		bytes[7] = hi + (exponent % 16) * 16
		bytes[8] = math.floor(exponent / 16) + sign * 128

		push(string.char(bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8]))
	end

	function self:Write(str)
		push(str)
	end

	function self:GetString()
		return table.concat(chunks)
	end

	function self:Size()
		return size
	end

	return self
end

--[[
	Title: Adv. Dupe 2 Codec

	Desc: Dupe encoder/decoder.

	Author: emspike

	Version: 2.0
]]

local AD2 = {}

local REVISION = 5
AD2.CodecRevision = REVISION
AD2.MaxDupeSize = 32e6 -- 32 MB

local pairs = pairs
local error = error
local Vector = Vector
local Angle = Angle
local format = string.format
local char = string.char
local concat = table.concat
local compress = util.Compress
local decompress = util.Decompress

--[[
	Name:	GenerateDupeStamp
	Desc:	Generates an info table.
	Params:	<player> ply
	Return:	<table> stamp
]]
function AD2.GenerateDupeStamp()
	local stamp = {}
	stamp.name = ""
	stamp.time = os.date("%I:00 %p")
	stamp.date = os.date("%d %B %Y")
	stamp.timezone = os.date("%z")
	return stamp
end

function AD2.SanitizeFilename(filename)
	filename = string.gsub(filename, '[":]', "_")
	filename = string.gsub(filename, "%s+", " ")
	filename = string.gsub(filename, "%s*([\\/%.])%s*", "%1")
	return filename
end

local function makeInfo(tbl)
	local info = ""
	for k, v in pairs(tbl) do
		info = concat({ info, k, "\1", v, "\1" })
	end
	return info .. "\2"
end

local AD2FF = "AD2F%s\n%s\n%s"

local tables, buff

local function noserializer() end

local enc = {}
for i = 1, 255 do
	enc[i] = noserializer
end

local function isArray(tbl)
	local ret = true
	local m = 0

	for k, v in pairs(tbl) do
		m = m + 1
		if k ~= m or enc[TypeID(v)] == noserializer then
			ret = false
			break
		end
	end

	return ret
end

local function write(obj)
	enc[TypeID(obj)](obj)
end

local len, tables, tablesLookup

enc[TYPE_TABLE] = function(obj) --table
	if not tablesLookup[obj] then
		tables = tables + 1
		tablesLookup[obj] = tables
	else
		buff:WriteByte(247)
		buff:WriteShort(tablesLookup[obj])
		return
	end

	if isArray(obj) then
		buff:WriteByte(254)
		for i, v in pairs(obj) do
			write(v)
		end
	else
		buff:WriteByte(255)
		for k, v in pairs(obj) do
			if enc[TypeID(k)] ~= noserializer and enc[TypeID(v)] ~= noserializer then
				write(k)
				write(v)
			end
		end
	end
	buff:WriteByte(246)
end

enc[TYPE_BOOL] = function(obj) --boolean
	buff:WriteByte(obj and 253 or 252)
end

enc[TYPE_NUMBER] = function(obj) --number
	buff:WriteByte(251)
	buff:WriteDouble(obj)
end

enc[TYPE_VECTOR] = function(obj) --vector
	buff:WriteByte(250)
	buff:WriteDouble(obj.x)
	buff:WriteDouble(obj.y)
	buff:WriteDouble(obj.z)
end

enc[TYPE_ANGLE] = function(obj) --angle
	buff:WriteByte(249)
	buff:WriteDouble(obj.p)
	buff:WriteDouble(obj.y)
	buff:WriteDouble(obj.r)
end

enc[TYPE_STRING] = function(obj) --string
	len = #obj
	if len < 246 then
		buff:WriteByte(len)
		buff:Write(obj)
	else
		buff:WriteByte(248)
		buff:WriteULong(len)
		buff:Write(obj)
	end
end

local function serialize(tbl)
	tables = 0
	tablesLookup = {}

	buff = stringBuffer()

	write(tbl)

	return buff:GetString()
end

--[[
	Name:	Encode
	Desc:	Generates the string for a dupe file with the given data.
	Params:	<table> dupe, <table> info, <function> callback, <...> args
	Return:	runs callback(<string> encoded_dupe, <...> args)
]]
function AD2.Encode(dupe, info, callback, ...)
	local encodedTable = compress(serialize(dupe))
	info.check = "\r\n\t\n"
	info.size = #encodedTable

	callback(string.format(AD2FF, char(REVISION), makeInfo(info), encodedTable), ...)
end

--[[
-------------------------------------
End AdvDupe2 Code
-------------------------------------
]]

--[[
entTable = {
	[234] = {
		worldPos = { x = 0, y = 0, z = 100 },
		worldAng = { p = 90, y = 0, r = 0 },
		color = { r = 255, g = 3, b = 255 },
		model = "models/balloons/balloon_classicheart.mdl",
		material = "sprops/sprops_grid_12x12",
		class = "prop_physics",
		mass = 250,
		frozen = true,
	}
}
]]

function AD2.tableToDupe(entTable)
	local dupe = {
		Entities = {},
		Constraints = {},
		HeadEnt = nil,
	}

	local headIndex
	for k in pairs(entTable) do
		headIndex = k
		break
	end
	assert(headIndex, "entTable is empty")

	local headEnt = entTable[headIndex]
	local headPos = Vector(headEnt.worldPos.x, headEnt.worldPos.y, headEnt.worldPos.z)
	local headAng = Angle(headEnt.worldAng.p or 0, headEnt.worldAng.y or 0, headEnt.worldAng.r or 0)

	dupe.HeadEnt = {
		Index = headIndex,
		Pos = headPos,
		Z = headAng.p,
	}

	for entIndex, ent in pairs(entTable) do
		local worldPos = Vector(ent.worldPos.x, ent.worldPos.y, ent.worldPos.z)
		local worldAng = Angle(
			ent.worldAng and ent.worldAng.p or 0,
			ent.worldAng and ent.worldAng.y or 0,
			ent.worldAng and ent.worldAng.r or 0
		)

		local localPos = worldPos - headPos
		local localAng = worldAng - headAng

		local phys = {
			Pos = localPos,
			Angle = localAng,
			Frozen = ent.frozen ~= nil and ent.frozen or true,
		}

		local entMods = {}

		if ent.color then
			entMods.colour = {
				Color = {
					r = ent.color.r or 255,
					g = ent.color.g or 255,
					b = ent.color.b or 255,
					a = ent.color.a or 255,
				},
				RenderMode = 0,
				RenderFX = 0,
			}
		end

		if ent.material then
			entMods.material = {
				MaterialOverride = ent.material,
			}
		end

		if ent.mass then
			entMods.mass = {
				Mass = ent.mass,
			}
		end

		dupe.Entities[entIndex] = {
			Class = ent.class or "prop_physics",
			Model = ent.model or "models/error.mdl",

			PhysicsObjects = {
				[0] = phys,
			},

			EntityMods = next(entMods) and entMods or nil,
		}
	end

	return dupe
end

return AD2