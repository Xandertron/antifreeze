local config = config or {}
config.defaults = config.defaults or {} -- configName -> { key = {value=.., min=.., max=..}, ... }
config.raw      = config.raw or {}      -- configName -> live table, same shape as defaults
config.proxies  = config.proxies or {}  -- configName -> ergonomic proxy table

local namespace = "antifreeze"
local dirty = {}

--------------------------------------------------------------------------
-- internals
--------------------------------------------------------------------------

local function deepCopy(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local function storageKey(configName)
	return string.format("%s_%s_config", namespace, configName)
end

local function persist(configName)
	local json = util.TableToJSON(config.raw[configName], true)
	lje.data.write(storageKey(configName), json)
	dirty[configName] = nil
end

local function loadFromDisk(configName)
	local defaults = config.defaults[configName]
	local liveData = deepCopy(defaults) -- never alias the defaults table

	local json = lje.data.read(storageKey(configName))
	if json then
		local saved = util.JSONToTable(json) or {}
		for key, savedEntry in pairs(saved) do
			local defEntry = liveData[key]
			-- only pull in the value; min/max/etc always come from the module's
			-- own defaults, so tightening limits later can't leave a stale
			-- out-of-range value sitting in someone's save file
			if defEntry ~= nil and type(savedEntry) == "table" and savedEntry.value ~= nil
				and type(savedEntry.value) == type(defEntry.value) then
				defEntry.value = savedEntry.value
			end
		end
		af.log("Loaded config: " .. configName)
	else
		af.log("New config, using defaults for: " .. configName)
	end

	config.raw[configName] = liveData
	if not json then persist(configName) end
	return liveData
end

local proxyMeta = {}

proxyMeta.__index = function(proxy, key)
	local entry = config.raw[rawget(proxy, "__name")][key]
	return entry and entry.value
end

proxyMeta.__newindex = function(proxy, key, newValue)
	local configName = rawget(proxy, "__name")
	local entry = config.raw[configName][key]

	if not entry then
		af.log(string.format("config: unknown key '%s' for '%s'", key, configName), "error")
		return
	end

	if entry.value ~= nil and type(entry.value) ~= type(newValue) then
		af.log(string.format("config: type mismatch for '%s.%s', expected/got: %s / %s", configName, key, type(entry.value), type(newValue)), "error")
		return
	end

	if type(newValue) == "number" then
		if entry.max and newValue > entry.max then newValue = entry.max end
		if entry.min and newValue < entry.min then newValue = entry.min end
	end

	entry.value = newValue
	dirty[configName] = true

	if not rawget(proxy, "__deferSave") then
		persist(configName)
	end
end

--------------------------------------------------------------------------
-- public api
--------------------------------------------------------------------------

-- Register a module's config. Call once per module, at the top of the file,
-- with your defaults table. Returns a proxy you can read/write directly:
--
--   local cfg = af.config.register("bhop", {
--       strafingEnabled = { value = false },
--       strafeTurnSpeed = { value = 1, min = 0, max = 10 },
--   })
--
--   if cfg.strafingEnabled then ... end
--   cfg.strafeTurnSpeed = 5   -- clamped, type-checked, auto-saved
--
function config.register(configName, defaults)
	config.defaults[configName] = defaults
	loadFromDisk(configName)

	local proxy = setmetatable({ __name = configName }, proxyMeta)
	config.proxies[configName] = proxy
	return proxy
end

-- String-keyed access, for cases where you don't have the proxy in scope
-- (e.g. a generic settings-menu UI that iterates config names dynamically).
function config.get(configName, key)
	local entry = config.raw[configName] and config.raw[configName][key]
	return entry and entry.value
end

function config.set(configName, key, newValue, temp)
	local proxy = config.proxies[configName]
	if not proxy then return end

	rawset(proxy, "__deferSave", temp or nil)
	proxy[key] = newValue
	rawset(proxy, "__deferSave", nil)

	return config.get(configName, key)
end

-- Metadata access (min/max/etc), useful for building sliders/UI from config.
function config.getMeta(configName, key)
	return config.raw[configName] and config.raw[configName][key]
end

function config.save(configName)
	persist(configName)
end

function config.saveAll()
	local anySaved = false
	for configName, isDirty in pairs(dirty) do
		if isDirty then
			persist(configName)
			anySaved = true
		end
	end
	if anySaved then af.log("Saving all configurations") end
end

function config.getTable()
	return config.raw
end

return config