local fullbright = {}

fullbright.moduleInfo = {
	name = "Full Bright",
	description = "mat_fullbright 1 (Screengrabbable)",
	section = "render",
}

hook.Add("PreRender", "antifreeze.fullbright", function()
	render.SetLightingMode(fullbright.enabled and 1 or 0)
end)
hook.Add("PostRender", "antifreeze.fullbright", function()
	render.SetLightingMode(0)
end)
hook.Add("PreDrawHUD", "antifreeze.fullbright", function()
	render.SetLightingMode(0)
end)

return fullbright
