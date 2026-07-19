local vision = {}

vision.moduleInfo = {
	name = "Vision",
	description = "Modify your eyesight (Screengrabbable)",
	section = "render",
}

local cfg = af.config.register("vision", {
	wraithVision = { value = false },
	wraithTransparency = { value = 0.75, min = 0, max = 1 },
})

function vision:onConfigChange(key, value)
	if key == "wraithVision" or key == "wraithTransparency" then
		local mapMaterials = Entity(0):GetMaterials()

		for k, v in pairs(mapMaterials) do
			local m = Material(v)

			if cfg.wraithVision and value then
				m:SetFloat("$alpha", cfg.wraithTransparency)
			else
				m:SetFloat("$alpha", 1)
			end
		end
	end
end

return vision
