local fullbright = fullbright or {}

fullbright.moduleInfo = {
	name = "Full Bright",
	description = "mat_fullbright 1 (Screengrabbable)",
	section = "render",
}

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
