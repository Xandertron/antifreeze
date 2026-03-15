local holdundo = holdundo or {}

holdundo.moduleInfo = {
	name = "HoldUndo",
	description = "Hold your undo key to undo, duh.",
	section = "other",
}

local bound = false
local undoKey = input.LookupBinding("gmod_undo", true)
local undoKeyCode = nil
if undoKey then
	undoKeyCode = input.GetKeyCode(undoKey)
    bound = true
else
	af.log("Undo key is not bound! HoldUndo will not work!", af.level.warn)
end
local undoDownTimer = 0
local undoFireTimer = 0

local function draw()
	if not holdundo.enabled then
		return
	end

    if not bound then
        af.log("Undo key is not bound! HoldUndo will not work!", af.level.error)
        af.switchModule("holdundo", false)
        return
    end

	local deltaTime = FrameTime()

	undoDownTimer = input.IsKeyDown(undoKeyCode) and undoDownTimer + deltaTime or 0

	if undoDownTimer < 0.75 then
		return
	end -- Activate rapid undo

	undoFireTimer = undoFireTimer + deltaTime

	local targetUndoFireInterval = math.Clamp(1 / undoDownTimer / 4, 0.05, 5)

	if undoFireTimer >= targetUndoFireInterval then
		RunConsoleCommand("gmod_undo")
		undoFireTimer = 0
	end
end

return holdundo, { draw = draw }
