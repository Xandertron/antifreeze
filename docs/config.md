documentation for config.lua
---

loads inital values and limits into the cache
```lua
config.init(configName, configData)
```

---

saves the config with the given name to disk
```lua
config.save(name)
```

---

returns the full config with inital limits intact unless loadUserLimits is specified
```lua
config.load(configName, loadUserLimits)
```

---

example usage:
```lua
local config = lje.require("service/config.lua")
config.init("esp", {
	maxDistance = { value = 15000, min = 0, max = 30000 },
	transparency = { value = 0.2, min = 0, max = 1 },
	playerMat = { value = "models/shiny" },
})
```
value can be anything serializable by gmod's json encoder and decoder

---

doing:
```lua
local espConfig = conf.load("esp")
```

will give you:
```lua
espConfig = {
	maxDistance = { value = 15000, min = 0, max = 30000 },
	transparency = { value = 0.2, min = 0, max = 1 },
	playerMat = { value = "models/shiny" },
}
```

---

if you change the value in a ui or in a similar matter, call `config.save("esp")` to save it to disk

changing limits on disk does not change what is actually loaded