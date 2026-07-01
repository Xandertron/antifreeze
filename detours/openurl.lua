local html_chromium = ffi.module.find("html_chromium.dll")
local openUrlThunk = ffi.module.scan(
  html_chromium,
  "4C 8B DC 49 89 5B 08 49 89 73 18 57 48 83 EC 70 48 8B 05 11 A3 06 00 48 33 C4 48 89 44 24 60 33 F6 49 C7 43 E0 0F 00 00 00 48 8D 05 00 A1 FF FF"
)

if not openUrlThunk then
  lje.con_printf("$red{Failed to find OpenURL thunk address}")
  return
end

lje.con_printf("Found OpenURL thunk at address: 0x%X", openUrlThunk)

local detour = {}

if openUrlDetour then
  openUrlDetour:remove()
  openUrlDetour = nil -- In case of hot-reload, remove the old detour first
  lje.con_printf("Removed existing OpenURL detour")
end

lje.con_printf("Creating detour for OpenURL at address: 0x%X", openUrlThunk)
openUrlDetour, openUrlDetourError = ffi.detour.create(openUrlThunk, lje.env.read_script_file("detours/openurl.c"))
if openUrlDetourError then
  lje.con_printf("$red{Failed to create OpenURL detour: %s}", openUrlDetourError)
  return
end
lje.con_printf("Created detour for OpenURL at address: 0x%X", openUrlThunk)

function detour:cleanup()
  if openUrlDetour then
    openUrlDetour:remove()
    openUrlDetour = nil
    lje.con_printf("Cleaned up OpenURL detour")
  end
end

return detour
