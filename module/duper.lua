local duper = duper or {}

duper.moduleInfo = {
	name = "Duplicator",
	description = "{WIP} Duplicate what you can see.",
	section = "none",
}

duper.codec = lje.include("service/advdupe2.lua")

local function colorSeqToKeyed(r, g, b, a)
	return { r = r, g = g, b = b, a = a }
end

local function vecToKeyed(vec)
	return { x = vec[1], y = vec[2], z = vec[3] }
end

local function angToKeyed(ang)
	return { p = ang[1], y = ang[2], r = ang[3] }
end

af.commands.tree.duper = {
	savemap = function()
		print("[AF] Attempting to save map")

		local entTable = {}

		for _, ent in ipairs(ents.GetAll()) do
			if ent:GetClass() == "prop_physics" then
				entTable[ent:EntIndex()] = {
					worldPos = vecToKeyed(ent:GetPos()),
					worldAng = angToKeyed(ent:GetAngles()),
					model = ent:GetModel(),
					material = ent:GetMaterial(),
					color = colorSeqToKeyed(ent:GetColor4Part()),
					class = "prop_physics",
				}
			end
		end

		print(duper.codec.tableToDupe(entTable))

		duper.codec.Encode(duper.codec.tableToDupe(entTable), duper.codec.GenerateDupeStamp(), function(data)
			file.Write("advdupe2/map.txt", data)
		end)
	end,
}
af.commands.attachHelp(af.commands.tree, {})

return duper
