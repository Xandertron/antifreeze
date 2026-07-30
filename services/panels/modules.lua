local panel = {
	label = "Modules",
	title = "Antifreeze | Modules",
	visible = false,
}

function panel.render()
	if imgui.begin_tab_bar("ModuleSections") then
		for groupName, moduleList in pairs(af.moduleSections) do
			--draw tabs
			if imgui.begin_tab_item(groupName) then
				--draw tab content

				for moduleName, enabled in pairs(moduleList) do
					local data = af.modules[moduleName]
					if data and data.moduleInfo then
						--https://github.com/ocornut/imgui/blob/master/docs/FAQ.md#q-how-can-i-have-multiple-windows-with-the-same-label

						if af.config.raw[moduleName] then
							local changed, value = imgui.checkbox("##" .. moduleName, data.enabled)

							imgui.same_line()

							local open = imgui.collapsing_header(data.moduleInfo.name or moduleName)
							if imgui.is_item_hovered() then
								imgui.set_tooltip(data.moduleInfo.description or "")
							end

							if open then

								local optionNames = {}
								for optionName in pairs(af.config.raw[moduleName]) do
									optionNames[#optionNames + 1] = optionName
								end

								local rank = {}
								for i, name in ipairs(af.config.order[moduleName] or {}) do
									rank[name] = i
								end

								table.sort(optionNames, function(a, b)
									local ra, rb = rank[a] or math.huge, rank[b] or math.huge
									if ra ~= rb then
										return ra < rb
									end
									return a < b
								end)

								for _, optionName in ipairs(optionNames) do
									local optionData = af.config.raw[moduleName][optionName]
									imgui.indent(28)
									if type(optionData.value) == "boolean" then
										local changed, value = imgui.checkbox(optionName, optionData.value)
										if changed then
											af.config.set(moduleName, optionName, value)
										end
									elseif type(optionData.value) == "number" then
										local changed, value = imgui.slider_float(
											optionName,
											optionData.value,
											optionData.min or 0,
											optionData.max or 100
										)

										if changed then
											--TODO: write this mf or track changed, its possible its true every frame
											af.config.set(moduleName, optionName, value, true)
										end
									elseif optionData.type == "color" then
										local col = optionData.value
										local changed, r, g, b =
											imgui.color_edit4(optionName, col[1], col[2], col[3], 1)

										if changed then
											af.config.set(moduleName, optionName, { r, g, b }, true)
										end
									elseif optionData.type == "selection" then
										if imgui.begin_combo(optionName, optionData.value) then
											for i, name in ipairs(optionData.options) do
												if imgui.selectable(name) then
													af.config.set(moduleName, optionName, name)
												end
											end
											imgui.end_combo()
										end
									elseif type(optionData.value) == "string" then
										local changed, text = imgui.input_text(optionName, optionData.value)
										if changed then
											af.config.set(moduleName, optionName, text, true)
										end
									end
									imgui.unindent(28)
								end
							end

							if changed then
								af.switchModule(moduleName, value)
							end
						else
							local changed, value = imgui.checkbox(data.moduleInfo.name or moduleName, data.enabled)

							if changed then
								af.switchModule(moduleName, value)
							end

							if imgui.is_item_hovered() then
								imgui.set_tooltip(data.moduleInfo.description or "")
							end
						end
					end
				end
				imgui.end_tab_item()
			end
		end
		imgui.end_tab_bar()
	end
end

return panel
