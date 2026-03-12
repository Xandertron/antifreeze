local function draw()
	imgui.text(af.info.version)
	if imgui.begin_tab_bar("Modules") then
		for groupName, moduleList in pairs(af.moduleSections) do
			--draw tabs
			if imgui.begin_tab_item(groupName) then
				--draw tab content

				for moduleName, enabled in pairs(moduleList) do
					local data = af.modules[moduleName]
					if data and data.moduleInfo then
						changed, value = imgui.checkbox(data.moduleInfo.name or moduleName, data.enabled)

						if imgui.is_item_hovered() then
							imgui.set_tooltip(data.moduleInfo.description or "")
						end

						if changed then
							af.switchModule(moduleName, value)
						end
					end
				end
				imgui.end_tab_item()
			end
		end
		imgui.end_tab_bar()
	end
end

return { draw = draw }
