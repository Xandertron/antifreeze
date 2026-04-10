local duper = duper or {}

duper.moduleInfo = {
	name = "Duplicator",
	description = "{WIP} Duplicate what you can see.",
	section = "none",
}

duper.codec = lje.include("util/advdupe2_codec.lua")

local acceptedRisk = false

local WHITELISTED_CLASSES = {
	prop_physics = true,
	prop_ragdoll = true,
	--gmod_wheel = true,
	--gmod_hoverball = true,
	--gmod_thruster = true,
	--gmod_balloon = true,
	--gmod_button = true,
	--gmod_emitter = true,
	--gmod_light = true,
	prop_vehicle_jeep = true,
	prop_vehicle_airboat = true,
	prop_vehicle_prisoner_pod = true,
}

local getem = FindMetaTable("Entity").CPPIGetOwner

local function GetOwner(ent)
	if not IsValid(ent) then
		return nil
	end
	-- CPPI (ULX/FPP/PAC standard)
	if getem then
		local owner = getem(ent)
		if IsValid(owner) then
			return owner
		end
	end
	return nil
end

-- Collect bodygroup data the same way AD2 does (index → value mapping)
local function GetBodygroups(ent)
	local groups = {}
	local count = ent:GetNumBodyGroups()
	if count == 0 then
		return groups
	end
	for i = 0, count - 1 do
		local v = ent:GetBodygroup(i)
		if v ~= 0 then
			groups[i] = v
		end
	end
	return groups
end

-- Build the PhysicsObjects table for an entity.
local function BuildPhysicsObjects(ent, headPos)
	local physObjs = {}
	local entPos = ent:GetPos()

	if ent:GetClass() == "prop_ragdoll" then
		for boneIdx = 0, ent:GetBoneCount() - 1 do
			local physBoneIdx = ent:TranslateBoneToPhysBone(boneIdx)
			if physBoneIdx >= 0 and not physObjs[physBoneIdx] then
				local matrix = ent:GetBoneMatrix(boneIdx)
				if matrix then
					physObjs[physBoneIdx] = {
						Pos = matrix:GetTranslation() - entPos,
						Angle = matrix:GetAngles(),
					}
				end
			end
		end

		if not physObjs[0] then
			physObjs[0] = { Angle = ent:GetAngles() }
		end
	else
		physObjs[0] = { Angle = ent:GetAngles() }
	end

	physObjs[0].Pos = entPos - headPos

	return physObjs
end

-- Serialise a single entity into an AD2 entity data block.
local function SerialiseEntity(ent, headPos)
	if not IsValid(ent) then
		return nil
	end

	local col = ent:GetColor()
	local mat = ent:GetMaterial()

	local entityMods = {}
	local defaultCol = ent:GetClass() == "prop_physics" -- white = default
	local r, g, b, a = col.r, col.g, col.b, col.a
	if r ~= 255 or g ~= 255 or b ~= 255 or a ~= 255 then
		entityMods.colour = {
			Color = Color(r, g, b, a),
			RenderMode = ent:GetRenderMode(),
			RenderFX = ent:GetRenderFX(),
		}
	end

	local data = {
		Class = ent:GetClass(),
		Model = ent:GetModel() or "",

		-- PhysicsObjects[0].Pos is the authoritative spawn position for AD2.
		-- The top-level Pos field is cleared (nil) in CopyEntTable, but we
		-- include it here for spawners that read it directly.
		PhysicsObjects = BuildPhysicsObjects(ent, headPos),

		Skin = ent:GetSkin() ~= 0 and ent:GetSkin() or nil,
		BodyG = GetBodygroups(ent), -- AD2 uses "BodyG", not "Bodygroups"

		-- _DuplicatedMaterial is read by duplicator.DoGeneric
		_DuplicatedMaterial = (mat ~= "") and mat or nil,

		-- Physics state
		Frozen = (function()
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then
				return not phys:IsMoveable()
			end
			return false
		end)(),

		EntityMods = entityMods,
		PhysicsModifier = {},
	}

	return data
end

local function DoSnapshot(filename, targetPlayer)
	if not file.IsDir("advdupe2", "DATA") then
		file.CreateDir("advdupe2")
	end

	-- collect candidate entities
	local candidates = {}
	local skipped = 0

	for _, ent in ipairs(ents.GetAll()) do
		if not IsValid(ent) then
			continue
		end

		if not WHITELISTED_CLASSES[ent:GetClass()] then
			continue
		end

		if IsValid(targetPlayer) then
			local owner = GetOwner(ent)
			if owner ~= targetPlayer then
				skipped = skipped + 1
				continue
			end
		end

		candidates[#candidates + 1] = ent
	end

	if #candidates == 0 then
		print(
			"[AF] No matching entities found"
				.. (IsValid(targetPlayer) and (" for player: " .. targetPlayer:Nick()) or "")
				.. "."
		)
		return
	end

	-- Determine head entity
	-- Use the first candidate as the head.  Its stored position will be
	-- Vector(0,0,0) and its stored angle Angle(0,0,0), so everything else
	-- is an offset from it – exactly what AD2 expects.
	local headEnt = candidates[1]
	local headPos = headEnt:GetPos()

	local groundTrace = util.TraceLine({
		start = headPos,
		endpos = headPos - Vector(0, 0, 32768),
		filter = headEnt,
		mask = MASK_SOLID_BRUSHONLY,
	})
	local groundZ = groundTrace.Hit and groundTrace.HitPos[3] or 0
	local headZ = headPos[3] - groundZ

	local entities = {}

	for i, ent in ipairs(candidates) do
		local data = SerialiseEntity(ent, headPos)
		if data then
			entities[i] = data
		end
	end

	local dupe = {
		Entities = entities,
		Constraints = {},
		HeadEnt = {
			Index = 1,
			Pos = headPos,
			Z = headZ,
		},
	}

	local stamp = {
		name = "", --LocalPlayer():Nick(),
		time = os.date("%I:%M %p"),
		date = os.date("%d %B %Y"),
		timezone = os.date("%z"),
		source = "",
	}

	local safeName = duper.codec.SanitizeFilename("advdupe2/" .. filename .. ".txt")

	print(string.format("[AF] Captured %d entities (%d skipped). Encoding...", #candidates, skipped))

	duper.codec.Encode(dupe, stamp, function(encoded)
		local f = file.Open(safeName, "wb", "DATA")
		if not f then
			print("[AF] ERROR: Could not open file for writing: data/" .. safeName)
			return
		end
		f:Write(encoded)
		f:Close()
		print(string.format("[AF] Saved to data/%s  (%d bytes)", safeName, #encoded))
	end)
end

af.commands.tree.duper = {
	save = function(fileName, playerName)
		if not fileName or fileName == "" then
			print("[AF] Usage: save <filename> [playerName]")
			print("[AF] Example: save my_build")
			print("[AF] Example: save johns_props John")
			return
		end

		if not acceptedRisk then
			print(
				"[AF] This command calls a bunch of external functions and will probably get you detected by any server looking for it.\n[AF] You may run the command again if you understand these risks!"
			)
			acceptedRisk = true
			return
		end

		local targetPlayer = NULL

		if playerName and playerName ~= "" then
			local nameLower = string.lower(playerName)
			for _, p in ipairs(player.GetAll()) do
				if string.find(string.lower(p:Nick()), nameLower, 1, true) then
					targetPlayer = p
					break
				end
			end
			if not IsValid(targetPlayer) then
				print("[AF] Could not find a player matching: " .. playerName)
				return
			end
			print("[AF] Filtering by player: " .. targetPlayer:Nick())
		else
			print("[AF] Attempting to save map")
		end

		DoSnapshot(fileName, targetPlayer)
	end,
}
af.commands.attachHelp(af.commands.tree, {})

return duper
