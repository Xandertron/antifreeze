-- Net message logger. LJE v2 removed the Lua-level lje.detour() primitive
-- the pre-v2 antifreeze net logger relied on (see docs/session notes),
-- so this hooks net.Start/net.ReadHeader and every net.ReadXxx/WriteXxx
-- function with real C-level detours instead.
--
-- Each of those ~32 functions gets its own independently-compiled TCC
-- program via its own ffi.detour.create call, so a plain C global inside
-- any one of them isn't visible to the others. To reconstruct which
-- fields belong to which message, every detour instead pushes into ONE
-- shared ring buffer, allocated up front with ffi.mem.alloc. Each
-- program gets the ring's address wired in *after* compiling via
-- detourObj:get() + ffi.mem.try_write_ptr (same mechanism http.c already
-- uses for its own url_ring), not baked into the C source as a literal -
-- that was tried first and crashed the game, twice, even after fixing an
-- unrelated address-truncation bug on the Lua side. Insertion order into
-- that single ring is the real call order, so message/field grouping
-- falls out naturally on the Lua side (same idea as the old nog.lua's
-- beginMessage/logField).
--
-- net.WriteEntity/net.ReadEntity/net.WriteBool/net.ReadBool/
-- net.WriteColor/net.ReadColor/net.WriteTable/net.ReadTable/
-- net.WriteType/net.ReadType are intentionally not in the spec table at
-- all. Per Facepunch's actual net.lua (github.com/Facepunch/garrysmod,
-- lua/includes/extensions/net.lua), every one of these is a pure-Lua
-- convenience wrapper around the real primitives (e.g. WriteColor just
-- calls WriteUInt four times), not a genuine engine C function.
-- getFnAddr's upvalue-unwrapping trick assumes a C closure's first
-- upvalue is a wrapped function pointer - for an actual Lua closure it's
-- just whatever local that closure happens to capture, so the resulting
-- "address" is meaningless. MinHook cleanly rejected that garbage for
-- Entity ("failed to create detour hook"); for Color it was accepted
-- without error, which is worse, not better - it almost certainly hooked
-- some unrelated real function by coincidence rather than Color's own
-- logic. Their underlying WriteUInt/ReadUInt/WriteType/ReadType calls are
-- still captured individually by the real hooks below regardless.
--
-- Vector/Angle/Normal all get real values via the "vector" category
-- (userdata wrapping a pointer to 3 floats, confirmed one type at a
-- time - these ARE genuine engine C functions, unlike the wrappers
-- above). Matrix is logged with a fixed "<unknown>" value instead of
-- fake data - it's a real function too, just with an unverified layout
-- not worth the crash risk to confirm for a diagnostic logger.

local function getFnAddr(fn)
	return ffi.mem.unwrap_userdata(ffi.mem.upvalue(fn, 1))
end

local RING_CAPACITY = 256
local NAME_MAX = 24
local LEN_FIELD_SIZE = 2 -- u16: the TRUE value length, even if it exceeds VALUE_MAX
local VALUE_MAX = 128
local ENTRY_SIZE = NAME_MAX + LEN_FIELD_SIZE + VALUE_MAX

-- Hot-reload: free the previous ring and remove all previous detours
-- before creating new ones (same idea as modules/antiscreengrab.lua -
-- a detour/allocation must be torn down before replacing it, or it just
-- leaks / conflicts with the new one on the same address).
if netRing then
	if netRing.headPtr then
		ffi.mem.free(netRing.headPtr)
	end
	if netRing.entriesPtr then
		ffi.mem.free(netRing.entriesPtr)
	end
end

netRing = {
	headPtr = ffi.mem.alloc(4),
	entriesPtr = ffi.mem.alloc(RING_CAPACITY * ENTRY_SIZE),
}
ffi.mem.try_write_u32(netRing.headPtr, 0)

netDetours = netDetours or {}
for name, detourObj in pairs(netDetours) do
	detourObj:remove()
	netDetours[name] = nil
end

--------------------------------------------------------------------------
-- C source generation
--------------------------------------------------------------------------

-- The shared ring's address is NOT baked into the C source as a literal
-- (tried that, still crashed even after fixing an address-truncation bug
-- in the Lua-side formatting - something about embedding a large 64-bit
-- constant directly in TCC-compiled source is apparently unreliable here
-- too). Instead, each program declares its own uninitialized global
-- pointer variables and this looks them up with detourObj:get() after
-- compiling, writing the real address in with ffi.mem.try_write_ptr -
-- the exact same proven mechanism http.c/antiscreengrab.lua already use
-- to pass values across the Lua/C boundary (detour:get("url_ring") +
-- ffi.mem.try_write_u32/try_read_u32), just for a pointer-sized value.
local function cHeader(spec)
	return string.format(
		[[
#include <stdio.h>
#include <string.h>

#define ENTRY_NAME "%s"
#define ENTRY_NAME_LEN %d
#define RING_CAP %d
#define NAME_MAX %d
#define VALUE_MAX %d
#define ENTRY_SIZE (NAME_MAX + 2 + VALUE_MAX)

volatile unsigned int* g_ring_head = 0;
char* g_ring_base = 0;

/* valueLen is the TRUE length, even if it's longer than what actually
   fits - stored as a u16 right after the name so the Lua-side drain can
   tell a value apart from a truncated one instead of just guessing off
   a NUL terminator (which also breaks for binary data with embedded
   NULs, e.g. net.WriteData). */
static void push_entry(int valueLen, const char* value) {
	if (!g_ring_head || !g_ring_base) return; /* not wired up yet */

	unsigned int slot = (*g_ring_head) %% RING_CAP;
	char* base = g_ring_base + slot * ENTRY_SIZE;

	int nameLen = ENTRY_NAME_LEN;
	if (nameLen > NAME_MAX - 1) nameLen = NAME_MAX - 1;
	memcpy(base, ENTRY_NAME, nameLen);
	base[nameLen] = 0;

	if (valueLen < 0) valueLen = 0;

	unsigned short storedLen = (unsigned short)(valueLen > 65535 ? 65535 : valueLen);
	*(unsigned short*)(base + NAME_MAX) = storedLen;

	int copyLen = valueLen;
	if (copyLen > VALUE_MAX) copyLen = VALUE_MAX;
	char* valuePtr = base + NAME_MAX + 2;
	memcpy(valuePtr, value, copyLen);
	if (copyLen < VALUE_MAX) valuePtr[copyLen] = 0; /* defensive NUL, not relied on for reads */

	*g_ring_head = *g_ring_head + 1; /* publish only after the payload is complete */
}

int (*original)(lua_State* L);
]],
		spec.name,
		#spec.name,
		RING_CAPACITY,
		NAME_MAX,
		VALUE_MAX
	)
end

local function cCapture(spec)
	local idx = spec.mode == "arg" and "1" or "-1"

	if spec.category == "string" then
		return string.format(
			[[
	size_t len = 0;
	const char* s = lua_tolstring(L, %s, &len);
	if (s) {
		push_entry((int)len, s);
	} else {
		push_entry(5, "<nil>");
	}
]],
			idx
		)
	elseif spec.category == "number" then
		return string.format(
			[[
	double v = lua_tonumber(L, %s);
	char buf[64];
	int n = snprintf(buf, sizeof(buf), "%%g", v);
	push_entry(n, buf);
]],
			idx
		)
	elseif spec.category == "vector" then
		-- Vector and Angle userdata are both a thin wrapper holding a
		-- POINTER to the real struct (3 floats), confirmed empirically for
		-- each in isolation - Vector first (WriteVector/ReadVector), then
		-- Angle separately once Vector alone was confirmed solid. The
		-- original crash here was actually the ring-wiring bug (see
		-- cHeader's comment), not this dereference - that bug affected
		-- every single detour, so this was never actually at fault.
		return string.format(
			[[
	void* p = lua_touserdata(L, %s);
	char buf[64];
	int n;
	if (p) {
		void* inner = *(void**)p;
		float* v = (float*)inner;
		n = snprintf(buf, sizeof(buf), "%%g %%g %%g", v[0], v[1], v[2]);
	} else {
		n = snprintf(buf, sizeof(buf), "<nil>");
	}
	push_entry(n, buf);
]],
			idx
		)
	else -- "unsupported" - no cheap/safe way to stringify, log that it happened without a value
		return [[
	push_entry(9, "<unknown>");
]]
	end
end

local function generateSource(spec)
	local body = cCapture(spec)
	if spec.mode == "arg" then
		body = body .. "\treturn original(L);\n"
	else
		body = "\tint nres = original(L);\n" .. body .. "\treturn nres;\n"
	end

	return cHeader(spec) .. "\nint detour(lua_State* L) {\n" .. body .. "}\n"
end

--------------------------------------------------------------------------
-- spec table
--------------------------------------------------------------------------

local specs = {
	{ name = "Start", mode = "arg", category = "string" },
	{ name = "ReadHeader", mode = "return", category = "number" },

	{ name = "WriteBit", mode = "arg", category = "number" },
	{ name = "ReadBit", mode = "return", category = "number" },
	{ name = "WriteDouble", mode = "arg", category = "number" },
	{ name = "ReadDouble", mode = "return", category = "number" },
	{ name = "WriteFloat", mode = "arg", category = "number" },
	{ name = "ReadFloat", mode = "return", category = "number" },
	{ name = "WriteInt", mode = "arg", category = "number" },
	{ name = "ReadInt", mode = "return", category = "number" },
	{ name = "WriteUInt", mode = "arg", category = "number" },
	{ name = "ReadUInt", mode = "return", category = "number" },

	{ name = "WriteString", mode = "arg", category = "string" },
	{ name = "ReadString", mode = "return", category = "string" },
	{ name = "WriteData", mode = "arg", category = "string" },
	{ name = "ReadData", mode = "return", category = "string" },

	{ name = "WriteVector", mode = "arg", category = "vector" },
	{ name = "ReadVector", mode = "return", category = "vector" },

	-- Angle confirmed to share Vector's userdata layout (pointer to 3
	-- floats), tested in isolation after Vector alone was confirmed solid.
	{ name = "WriteAngle", mode = "arg", category = "vector" },
	{ name = "ReadAngle", mode = "return", category = "vector" },

	{ name = "WriteMatrix", mode = "arg", category = "unsupported" },
	{ name = "ReadMatrix", mode = "return", category = "unsupported" },

	-- WriteNormal/ReadNormal operate on a plain Vector argument/return
	-- (just a lower-precision wire encoding) - reuses the same validated
	-- "vector" category with zero new risk.
	{ name = "WriteNormal", mode = "arg", category = "vector" },
	{ name = "ReadNormal", mode = "return", category = "vector" },

	-- WriteBool/ReadBool, WriteColor/ReadColor, WriteTable/ReadTable, and
	-- WriteType/ReadType are intentionally NOT in this table at all (not
	-- even with an "unsupported" placeholder). Per Facepunch's actual
	-- net.lua (github.com/Facepunch/garrysmod, lua/includes/extensions/
	-- net.lua), all of these are pure-Lua convenience wrappers around the
	-- real primitives (e.g. WriteColor calls WriteUInt four times), same
	-- as WriteEntity/ReadEntity above. getFnAddr's upvalue-unwrapping
	-- trick assumes a C closure's first upvalue is a wrapped function
	-- pointer - for a genuine Lua closure it's just whatever local that
	-- closure happens to capture, so the "address" is meaningless. Entity
	-- got a garbage address MinHook correctly rejected; Color's hook was
	-- actually created without error, meaning it likely hooked some
	-- unrelated real function by coincidence - worse than a clean
	-- failure, not better. Their underlying WriteUInt/ReadUInt calls are
	-- already captured individually by the hooks above regardless, so
	-- nothing is lost by not hooking the wrappers themselves.
}

for _, spec in ipairs(specs) do
	local fn = net[spec.name]
	if not fn then
		af.log("[net] net." .. spec.name .. " does not exist, skipping", "warn")
	else
		local addr = getFnAddr(fn)
		local detourObj, err = ffi.detour.create(addr, generateSource(spec))
		if detourObj then
			local headSym = detourObj:get("g_ring_head")
			local baseSym = detourObj:get("g_ring_base")
			if headSym and baseSym and ffi.mem.try_write_ptr(headSym, netRing.headPtr) and ffi.mem.try_write_ptr(baseSym, netRing.entriesPtr) then
				netDetours[spec.name] = detourObj
			else
				af.log("[net] failed to wire ring pointers for net." .. spec.name .. ", removing", "warn")
				detourObj:remove()
			end
		else
			af.log("[net] failed to hook net." .. spec.name .. ": " .. tostring(err), "warn")
		end
	end
end

--------------------------------------------------------------------------
-- log table (same shape as the old nog.lua) + drain/grouping
--------------------------------------------------------------------------

local nog = {}
nog.logs = {}
nog.current = nil
nog.maxEntries = 200

function nog.trimEntries()
	local excess = #nog.logs - nog.maxEntries
	if excess > 0 then
		for i = 1, excess do
			table.remove(nog.logs, 1)
		end
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

	--lje.con_printf("[net] %s %s %s", nog.current.time, direction == "receive" and "v" or "^", name)
end

local function logField(fn, value)
	if nog.current then
		table.insert(nog.current.fields, { fn = fn, value = value })
		--lje.con_printf("[net]     %s = %s", fn, tostring(value))
	end
end

function nog.dump(entry)
	lje.con_printf("[%s] %s %s", entry.time, entry.direction == "receive" and "v" or "^", entry.name)
	for _, field in ipairs(entry.fields) do
		--lje.con_printf("    %s = %s", field.fn, tostring(field.value))
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

af.nog = nog

--------------------------------------------------------------------------
-- run / cleanup
--------------------------------------------------------------------------

-- net.WriteData/ReadData (and occasionally String) can carry raw bytes
-- that aren't text at all - rendered as-is in the menu that's mostly
-- tofu/question marks, since most bytes have no glyph in the UI font. If
-- a value has any non-printable byte in it, show the whole thing as hex
-- instead of trying to render it as text.
local function isBinary(s)
	for i = 1, #s do
		local b = string.byte(s, i)
		if b < 32 or b > 126 then
			return true
		end
	end
	return false
end

local HEX_BYTES_PER_LINE = 16

local function toHex(s)
	local lines = {}
	local line = {}
	for i = 1, #s do
		table.insert(line, string.format("%02X", string.byte(s, i)))
		if i % HEX_BYTES_PER_LINE == 0 then
			table.insert(lines, table.concat(line, " "))
			line = {}
		end
	end
	if #line > 0 then
		table.insert(lines, table.concat(line, " "))
	end
	return table.concat(lines, "\n")
end

local detour = {}
local seen = 0

function detour:run()
	local head = ffi.mem.try_read_u32(netRing.headPtr)
	if not head then
		return
	end

	if head - seen > RING_CAPACITY then
		local dropped = head - seen - RING_CAPACITY
		af.log("[net] dropped " .. dropped .. " entries (poller fell behind)", "warn")
		seen = head - RING_CAPACITY
	end

	while seen < head do
		local slot = seen % RING_CAPACITY
		local addr = netRing.entriesPtr + slot * ENTRY_SIZE
		local name = ffi.mem.read_string(addr) -- names are our own short literal identifiers, always plain NUL-terminated ASCII

		local trueLen = ffi.mem.read_u16(addr + NAME_MAX)
		local storedLen = math.min(trueLen, VALUE_MAX)
		local rawValue = ffi.mem.to_binary_string(addr + NAME_MAX + LEN_FIELD_SIZE, storedLen)

		local value = isBinary(rawValue) and toHex(rawValue) or rawValue
		if trueLen > VALUE_MAX then
			value = value .. " ..."
		end

		if name == "Start" then
			beginMessage("send", value)
		elseif name == "ReadHeader" then
			beginMessage("receive", util.NetworkIDToString(tonumber(value) or 0))
		else
			logField(name, value)
		end

		seen = seen + 1
	end
end

function detour:cleanup()
	for name, detourObj in pairs(netDetours) do
		detourObj:remove()
		netDetours[name] = nil
	end

	if netRing.headPtr then
		ffi.mem.free(netRing.headPtr)
		netRing.headPtr = nil
	end

	if netRing.entriesPtr then
		ffi.mem.free(netRing.entriesPtr)
		netRing.entriesPtr = nil
	end
end

local hookedCount = 0
for _ in pairs(netDetours) do
	hookedCount = hookedCount + 1
end
af.log(string.format("[net] hooked %d/%d net functions", hookedCount, #specs))

return detour
