-- Mouse input library, uses FFI to send mouse input to the game such that the engine
-- correctly processes it and we can implement an aimbot without messing with anything that will
-- create observable side effects like view angle changes or engine prediction errors.

local user32 = ffi.module.find("user32.dll")
local SendInput = ffi.module.bind_export(user32, "SendInput", "uupi")

-- INPUT struct, no keyboard inputs because well we really don't have a need for it
-- Matches C's union padding though with 8 bytes of padding at the end.
ffi.struct.define([[
struct INPUT {
  uint32_t type;
  padding[4];

  long dx;
  long dy;
  uint32_t mouseData;
  uint32_t dwFlags;
  uint32_t time;
  uintptr_t dwExtraInfo;
};
]])

local INPUT_SIZE = ffi.struct.sizeof("INPUT")
local INPUT_PTR = ffi.mem.alloc(INPUT_SIZE)
local INPUT_MOUSE = 0
local MOUSEEVENTF_MOVE = 0x0001

local mouse = {}

function mouse.move(dx, dy)
  ffi.struct.write(INPUT_PTR, "INPUT", {
    type = INPUT_MOUSE,
    dx = dx,
    dy = dy,
    mouseData = 0,
    dwFlags = MOUSEEVENTF_MOVE,
    time = 0,
    dwExtraInfo = 0,
  })

  local result = SendInput(1, INPUT_PTR, INPUT_SIZE)
  if result == 0 then
    lje.con_print("SendInput failed.")
  end
end

return mouse
