local esp = {}

esp.moduleInfo = {
	name = "ESP",
	description = "See the living beyond walls.",
	section = "render",
}

local cfg = af.config.register("esp", {
	material = { value = "models/shiny" },
	transparency = { value = 0.3, min = 0, max = 1 },
	drawModels = { value = true },
	drawAimLines = { value = true },
	drawPropHuntX = { value = true },
})

esp.currentMaterialPath = cfg.material
esp.currentMaterial = Material(cfg.material)
esp.teams = nil
local RED = Color(255, 0, 0)

function esp:fetchTeams()
	local success, teams = pcall(function()
		return lje.state.path(lje.state.client, "team"):index("GetName"):upvalue(1):copy()
	end)

	if success then
		esp.teams = teams
	end
end

function esp:getTeamInfo(ply)
	if not esp.teams then
		return nil
	end

	local teamId = ply:Team()
	return esp.teams[teamId]
end

local notseen = {}

function esp:render()
	if not self.teams then
		self:fetchTeams()
	end

	if esp.currentMaterialPath ~= cfg.material then
		esp.currentMaterialPath = cfg.material
		esp.currentMaterial = Material(cfg.material)
	end

	for _, ply in ipairs(player.GetAll()) do
		if ply == LocalPlayer() then
			continue
		end

		cam.Start({ type = "3D" })

		local hitboxBoneId = ply:GetHitBoxBone(0, 0)
		local plyPos = ply:GetPos()
		if hitboxBoneId then
			plyPos = ply:GetBonePosition(hitboxBoneId)
		end

		local screenPos = plyPos:ToScreen() or { x = 0, y = 0 }

		if ply:Alive() then
			--draw body
			render.SuppressEngineLighting(true)
			render.MaterialOverride(esp.currentMaterial)

			local oldR, oldG, oldB = render.GetColorModulation()
			local r = LocalPlayer():GetPos():Distance(ply:GetPos()) / 2000
			render.SetColorModulation(0.5, 1, 1)
			render.SetBlend(cfg.transparency)
			
			local prop = ply:GetNWEntity("PlayerPropEntity", nil)
			if prop ~= nil and prop:IsValid() then
				prop:DrawModel()
			end

			if cfg.drawModels then
				ply:DrawModel()
			end

			render.MaterialOverride(nil)
			render.SetColorModulation(oldR, oldG, oldB)
			render.SuppressEngineLighting(false)

			-- draw aim line
			if cfg.drawAimLines then
				local eyePos = ply:EyePos()
				local eyeAngles = ply:EyeAngles()
				local endPos = eyeAngles:Forward() * 100
				render.DrawLine(eyePos, eyePos + endPos, RED)
			end
		end
		cam.End()

		--draw info text
		surface.SetDrawColor(255, 0, 255, 255)
		surface.DrawOutlinedRect(screenPos.x - 5, screenPos.y - 5, 10, 10)
		surface.SetTextColor(255, 255, 255, 255)
		surface.SetFont("BudgetLabel")
		surface.SetTextPos(screenPos.x + 10, screenPos.y - 5)
		surface.DrawText(ply:Nick())

		local teamInfo = self:getTeamInfo(ply)
		if teamInfo then
			surface.SetTextColor(teamInfo.Color)
			surface.SetTextPos(screenPos.x + 10, screenPos.y + 10)
			surface.DrawText(teamInfo.Name)
		end
	end
end

function esp:cleanup()
	esp.currentMaterial = nil
	esp.currentMaterialPath = nil
	esp.teams = nil
end

return esp
