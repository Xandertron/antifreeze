--basic lje-coupled config library
--made by xandertron
--docs:
--[[

--loads inital values and limits into the cache
config.init(configName, configData)

--saves the config with the given name to disk
config.save(name)

--returns the full config with inital limits intact unless loadUserLimits is specified
config.readFull(configName, loadUserLimits)

--returns only values, no limits
config.read(configName)

--example usage:
local config = lje.require("service/config.lua")
config.init("esp", {
	maxDistance = { value = 15000, min = 0, max = 30000 },
	transparency = { value = 0.2, min = 0, max = 1 },
	playerMat = { value = "models/shiny" },
})
--value can be anything serializable by gmod's json encoder and decoder

--doing:
local espConfig = config.read("esp")

--will give you:
espConfig = {
	maxDistance = 15000
	transparency = 0.2
	playerMat = "models/shiny"
}

--doing:
local espConfig = conf.readFull("esp")

--will give you:
espConfig = {
	maxDistance = { value = 15000, min = 0, max = 30000 },
	transparency = { value = 0.2, min = 0, max = 1 },
	playerMat = { value = "models/shiny" },
}

--if you change the value in a ui or in a similar matter, call config.save("esp") to save it to disk
--changing limits on disk does not change what is actually loaded
]]

local config = config or {}
config.data = config.data or {}
config.cache = config.cache or {} --active data
local namespace = "antifreeze"

function config.init(configName, configData)
	config.cache[configName] = configData
end

function config.save(configName)
	lje.con_print("[AF] Saving config: " .. configName)
	local configJson = util.TableToJSON(config.cache[configName], true)
	lje.data.write(string.format("%s_%s_config", namespace, configName), configJson)
end

--load values from user's config over default values, or load initial values otherwise
function config.readFull(configName, loadUserLimits)
	if config.cache[configName] then
		return config.cache[configName]
	end
	lje.con_print("[AF] Loading config: " .. configName)
	if config.data[configName] then
		local jsonData = lje.data.read(string.format("%s_%s_config", namespace, configName))
		if jsonData then
			local configData = util.JSONToTable(jsonData)

			--preference data, ie
			--  maxESPDistance = {value = 1000, min = 1, max = 30000}
			--  strafingEnabled = {value = true}
			for prefName, prefData in pairs(configData) do
				if type(prefData) == "table" and config.cache[configName][prefName] then
					if loadUserLimits then
						config.cache[configName][prefName] = prefData
					else
						config.cache[configName][prefName]["value"] = prefData.value
					end
				end
			end
		else
			lje.con_print("[AF] New config using defaults for: " .. configName)
			config.save(configName)
		end
		return config.cache[configName]
	else
		lje.con_print("[AF] Config was not initalized before it was loaded! Offending config/module: " .. configName)
	end
end

--read only values, do not read limits, etc. shallow copy!
function config.read(configName)
	local configData = config.readFull(configName)
	local simpleConfig = {}
	for key, value in pairs(configData) do
		simpleConfig[key] = value["value"]
	end
	return simpleConfig
end

function config.get(configName, key)
	if configName and key and config.cache[configName] and config.cache[configName][key] then
		return config.cache[configName][key].value
	end
end

function config.set(configName, key, newValue)
	local conf = config.cache[configName]
	if key and newValue ~= nil and conf and conf[key] and conf[key].value ~= nil then
		local value = conf[key].value
		if type(value) ~= type(newValue) then
			return value
		end

		if type(value) == "number" then
			local max = conf[key].max
			local min = conf[key].min
			if max and newValue > max then
				newValue = max
			elseif min and newValue < min then
				newValue = min
			end
		end
		
		conf[key].value = newValue
		return newValue
	end
end

function config.getTable()
	return config.cache
end

return config
