local taunt = taunt or {}

taunt.moduleInfo = {
	name = "Taunt",
	description = "Taunt players when you kill someone or die",
	section = "other",
}

local config = af.config
config.init("taunt", {
	onDeath = { value = true },
	onKill = { value = true },
	tauntType = { value = "main", options = { "main", "bro", "xbox", "swap", "targeted" }, type = "selection" },
	swapWord = { value = "@target" },
})

taunt.data = lje.include("util/taunt.lua")

local generators = {
	main = function()
		return taunt.data.taunts[math.random(#taunt.data.taunts)]
	end,

	bro = function()
		return taunt.data.broTaunts[math.random(#taunt.data.broTaunts)]
	end,

	xbox = function()
		return taunt.data.xboxTaunts[math.random(#taunt.data.xboxTaunts)]
	end,

	swap = function(swapWith)
		local swapWith = swapWith or taunt.data.swapWords[math.random(#taunt.data.swapWords)]
		return string.format(taunt.data.swapTaunts[math.random(#taunt.data.swapTaunts)], swapWith)
	end,

	targeted = function(swapWith)
		return string.format(taunt.data.targetedTaunts[math.random(#taunt.data.targetedTaunts)], swapWith or "noob")
	end,
}

function taunt.generateTaunt(tauntType, swapWith)
	if not generators[tauntType] then
		return nil
	end
	return generators[tauntType](swapWith)
end

local types = table.concat(
	(function()
		local keys = {}
		local id = 1

		for k, v in pairs(generators) do
			keys[id] = k
			id = id + 1
		end
		return keys
	end)(),
	", "
)

af.commands.tree.taunt = {
	test = function(tauntType, swapWith)
		local ret = taunt.generateTaunt(tauntType or "main", swapWith)
		if not ret then
			print("[AF] Not a valid taunt type! Valid types:\n" .. types)
		end
		print("[AF] " .. ret)
	end,
	types = function()
		print("[AF] Valid types:\n" .. types)
	end,
	say = function(tauntType, swapWith)
		local ret = taunt.generateTaunt(tauntType or "main", swapWith)
		if not ret then
			print("[AF] Not a valid taunt type! Valid types:\n" .. types)
		end
		RunConsoleCommand("say", ret)
	end,
}
af.commands.attachHelp(af.commands.tree, {})

return taunt
