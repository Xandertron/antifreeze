local esp = esp or {}

esp.name = "ESP"
esp.description = "See the living beyond walls."

local config = lje.require("service/config.lua")
config.init("esp", {
	maxDistance = { value = 15000, min = 0, max = 30000 },
	transparency = { value = 0.2, min = 0, max = 1 },
	playerMaterial = { value = "models/shiny" },
})

esp.studiorender_flags = bit.bor(STUDIO_RENDER, STUDIO_NOSHADOWS, STUDIO_STATIC_LIGHTING)

local function draw()
	for _, ply in ipairs(player.GetAll()) do
		if
			ply:IsValid()
			and ply ~= LocalPlayer()
			and LocalPlayer():GetPos():Distance(ply:GetPos()) <= config.get("esp", "maxDistance")
			and ply:Alive()
		then
			local plyPos = ply:GetBonePosition(ply:GetHitBoxBone(0, 0))
			local pt1 = plyPos:ToScreen()

			local x1 = pt1.x - 7.5
			local y1 = pt1.y - 7.5
			local w = 15
			local h = 15

			surface.SetDrawColor(255, 100, 100, 255)
			surface.DrawOutlinedRect(x1, y1, w, h, 1)

			surface.SetFont("DermaDefaultBold")
			surface.SetTextPos(x1 + 18, y1)
			surface.SetTextColor(255, 255, 255, 255)
			surface.DrawText(ply:Nick(ply))

			-- Draw team name
			local envTeam = rawget(_G, "team")
			local teamGetName = envTeam and rawget(envTeam, "GetName")

			if teamGetName then -- Teams exist. Some anticheats will randomly remove the team table.. weird.
				local teamInfoName, teamInfo = debug.getupvalue(teamGetName, 1) -- Get the team info table

				if teamInfoName == "TeamInfo" and type(teamInfo) == "table" then
					local teamData = rawget(teamInfo, ply:Team(ply))
					if teamData and type(teamData) == "table" then
						local teamName = rawget(teamData, "Name") or "Unknown"
						surface.SetTextPos(x1 + 18, y1 + 15)
						surface.DrawText("[" .. teamName .. "]")
					end
				end
			end

			cam.Start({ type = "3D" })

			render.SuppressEngineLighting(true)
			render.MaterialOverride(config.get("esp", "playerMaterial"))
			local oldR, oldG, oldB = render.GetColorModulation()
			local r = LocalPlayer():GetPos():Distance(ply:GetPos()) / config.get("esp", "maxDistance")
			render.SetColorModulation(1 - (r * r * r), 1, 0)
			render.SetBlend(config.get("esp", "transparency"))
			lje.util.safe_draw_model(ply, esp.studiorender_flags)
			render.MaterialOverride(nil)
			render.SetColorModulation(oldR, oldG, oldB)
			render.SuppressEngineLighting(false)

			cam.End()
		end
	end
end

return esp, { draw = draw }
