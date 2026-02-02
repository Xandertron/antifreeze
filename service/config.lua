--basic lje-coupled config library
--made by xandertron\
--see docs/config.md

local config = config or {}
config.data = config.data or {}
config.cache = config.cache or {} --active data
local namespace = "antifreeze"

function config.init(configName, configData)
	config.data[configName] = configData
	config.load(configName)
end

function config.save(configName)
	lje.con_print("[AF] Saving config: " .. configName)
	local configJson = util.TableToJSON(config.cache[configName], true)
	lje.data.write(string.format("%s_%s_config", namespace, configName), configJson)
end

function config.load(configName)
	lje.con_print("[AF] Loading config: " .. configName)
	if config.data[configName] then
		local jsonData = lje.data.read(string.format("%s_%s_config", namespace, configName))
		if jsonData then
			local configData = util.JSONToTable(jsonData)
			config.cache[configName] = {}

			--preference data, ie
			--  maxESPDistance = {value = 1000, min = 1, max = 30000}
			--  strafingEnabled = {value = true}

			for prefName, prefData in pairs(configData) do
				if type(prefData) == "table" and config.data[configName][prefName] then
					config.cache[configName][prefName] = config.data[configName][prefName]
					config.cache[configName][prefName]["value"] = prefData.value --load just the value, ignore user limits
				end
			end
		else
			lje.con_print("[AF] New config, using defaults for: " .. configName)
			config.cache[configName] = config.data[configName]
			config.save(configName)
		end
		return config.cache[configName]
	else
		lje.con_print("[AF] Config was not initalized before it was loaded! Offending config/module: " .. configName)
	end
end

--TODO: Might be rather slow, but meh
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
		config.save(configName)
		return newValue
	end
end

function config.getTable()
	return config.cache
end

return config
