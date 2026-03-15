local example = example or {}

esp.moduleInfo = {
	name = "example",
	description = "example",
	section = "other"
}

local config = af.config
config.init("example", {
	number = { value = 25, min = 0, max = 100 },
	string = { value = "example" },
})

local function draw()
    --ljeutil/render hook
end

return esp, {draw = draw}