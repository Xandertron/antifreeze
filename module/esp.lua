local esp = esp or {}

esp.moduleInfo = {
	name = "ESP",
	description = "See the living beyond walls.",
	section = "render",
}

local config = af.config
config.init("esp", {
	maxDistance = { value = 15000, min = 0, max = 30000 },
	transparency = { value = 0.2, min = 0, max = 1 },
	playerMaterial = { value = "models/shiny" },
	drawNames = { value = true },
	drawWireframe = { value = false },
})

esp.studiorender_flags = bit.bor(STUDIO_RENDER, STUDIO_NOSHADOWS, STUDIO_STATIC_LIGHTING)
esp.materialPath = config.get("esp", "playerMaterial")
esp.material = Material(esp.materialPath)

local function draw()
	if esp.materialPath ~= config.get("esp", "playerMaterial") then
		esp.materialPath = config.get("esp", "playerMaterial")
		esp.material = Material(esp.materialPath)
	end
	for _, ply in ipairs(player.GetAll()) do
		if
			ply:IsValid()
			and ply ~= LocalPlayer()
			and LocalPlayer():GetPos():Distance(ply:GetPos()) <= config.get("esp", "maxDistance")
			and ply:Alive()
		then
			local hitboxBoneId = ply:GetHitBoxBone(0, 0)
			local plyPos = ply:GetPos()
			if hitboxBoneId then
				plyPos = ply:GetBonePosition(hitboxBoneId)
			end

			-- Same check for error models, if its equal to their origin, we have no bones, so lift it
			if plyPos == ply:GetPos() then
				plyPos = ply:GetPos() + Vector(0, 0, 50)
			end

			local pt1 = plyPos:ToScreen()

			local x1 = pt1.x - 7.5
			local y1 = pt1.y - 7.5
			local w = 15
			local h = 15
			local drawColor = config.get("hud", "drawColor")

			if config.get("esp", "drawNames") then
				surface.SetDrawColor(drawColor[1] * 255, drawColor[2] * 255, drawColor[3] * 255, 255)
				surface.DrawOutlinedRect(x1, y1, w, h, 1)

				surface.SetFont("BudgetLabel")
				surface.SetTextPos(x1 + 18, y1)
				surface.SetTextColor(255, 255, 255, 255)
				surface.DrawText(ply:Nick())

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
			end

			cam.Start({ type = "3D" })

			if config.get("esp", "drawWireframe") then
				local localMin, localMax = ply:OBBMins(), ply:OBBMaxs()
				render.DrawWireframeBox(
					ply:GetPos(),
					Angle(0, 0, 0),
					localMin,
					localMax,
					Color(drawColor[1] * 255, drawColor[2] * 255, drawColor[3] * 255, 100),
					false
				)
			end

			render.SuppressEngineLighting(true)
			render.MaterialOverride(esp.material)
			local oldR, oldG, oldB = render.GetColorModulation()
			local r = LocalPlayer():GetPos():Distance(ply:GetPos()) / 2000
			render.SetColorModulation(1 - (r * r * r), 1, 0)
			local blend = config.get("esp", "transparency")
			if blend > 0 then
				render.SetBlend(blend)
				lje.util.safe_draw_model(ply, esp.studiorender_flags)
			end
			render.MaterialOverride(nil)
			render.SetColorModulation(oldR, oldG, oldB)
			render.SuppressEngineLighting(false)

			cam.End()
		end
	end
end

return esp, { draw = draw }
