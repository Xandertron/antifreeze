local fullbright = fullbright or {}

fullbright.name = "Full Bright"
fullbright.description = "mat_fullbright 1 (Screengrabbable)"

hook.post("PreRender", "antifreeze.fullbright", function()
	render.SetLightingMode(fullbright.enabled and 1 or 0)
end)
hook.pre("PostRender", "antifreeze.fullbright", function()
	render.SetLightingMode(0)
end)
hook.pre("PreDrawHUD", "antifreeze.fullbright", function()
	render.SetLightingMode(0)
end)

return fullbright
