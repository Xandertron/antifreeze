# Creating a module

Example module:

```lua
local esp = esp or {}

esp.name = "ESP"
esp.description = "See the living beyond walls."

local config = af.config
config.init("esp", {
	maxDistance = { value = 15000, min = 0, max = 30000 },
	transparency = { value = 0.2, min = 0, max = 1 },
	playerMaterial = { value = "models/shiny" },
})

local function draw()
    --ljeutil/render hook
end

return esp, {draw = draw}
```

Valid hooks:
---
  * draw: before `ljeutil/render` (2d/3d)
  * think: before `Think`
  * move: before `CreateMove`