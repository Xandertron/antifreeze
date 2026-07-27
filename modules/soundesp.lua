local soundesp = {}

soundesp.moduleInfo = {
	name = "Sound ESP",
	description = "Pings where nearby sounds (footsteps, gunfire, etc.) came from, even through walls.",
	section = "render",
}

local cfg = af.config.register("soundesp", {
	range = { value = 2000, min = 300, max = 6000 },
	minSoundLevel = { value = 60, min = 0, max = 140 },
	pingFadeTime = { value = 2.5, min = 0.5, max = 8 },
	showNames = { value = true },
	onlyEnemies = { value = false },
}, { "range", "minSoundLevel", "pingFadeTime", "showNames", "onlyEnemies" })

local MAX_PINGS = 256 -- safety valve; render() trims by age every frame anyway

local NEUTRAL = Color(215, 215, 215)
local ALLY = Color(95, 220, 130)
local ENEMY = Color(235, 75, 75)

soundesp.teams = nil
soundesp.pings = {}

function soundesp:fetchTeams()
	local success, teams = pcall(function()
		return lje.state.path(lje.state.client, "team"):index("GetName"):upvalue(1):copy()
	end)

	if success then
		soundesp.teams = teams
	end
end

function soundesp:getTeamInfo(ply)
	if not soundesp.teams then
		return nil
	end
	return soundesp.teams[ply:Team()]
end

function soundesp:getPingColor(ply, myTeam)
	local info = self:getTeamInfo(ply)
	if info and info.Color then
		return info.Color
	end

	if myTeam and myTeam ~= 0 then
		return ply:Team() == myTeam and ALLY or ENEMY
	end

	return NEUTRAL
end

local function isValidEntity(ent)
	return ent ~= nil and ent:IsValid()
end

local function resolveSourcePlayer(ent)
	if not isValidEntity(ent) then
		return nil
	end

	if ent:IsPlayer() then
		return ent
	end

	if ent.GetOwner then
		local owner = ent:GetOwner()
		if isValidEntity(owner) and owner:IsPlayer() then
			return owner
		end
	end

	return nil
end

hook.Add("EntityEmitSound", "antifreeze.soundesp.capture", function(data)
	if not soundesp.enabled then
		return
	end

	data = lje.proxy.copy(data)

	local source = resolveSourcePlayer(data.Entity)
	if not source or source == LocalPlayer() or not source:Alive() then
		return
	end

	if data.SoundLevel and data.SoundLevel < cfg.minSoundLevel then
		return
	end

	local myPos = LocalPlayer():GetPos()
	local pos = source:GetPos()
	if myPos:Distance(pos) > cfg.range then
		return
	end

	if cfg.onlyEnemies then
		local myTeam = LocalPlayer():Team()
		if myTeam ~= 0 and source:Team() == myTeam then
			return
		end
	end

	if #soundesp.pings >= MAX_PINGS then
		table.remove(soundesp.pings, 1)
	end

	soundesp.pings[#soundesp.pings + 1] = {
		ply = source,
		pos = pos,
		time = CurTime(),
	}
end)

local function drawFilledCircle(cx, cy, radius, r, g, b, a, segments)
	segments = segments or 40
	surface.SetDrawColor(r, g, b, a)
	surface.SetTexture(0)
	local points = {}
	for i = 0, segments do
		local rad = math.rad(360 * (i / segments))
		points[#points + 1] = { x = cx + math.cos(rad) * radius, y = cy + math.sin(rad) * radius }
	end
	surface.DrawPoly(points)
end

local function drawRing(cx, cy, radius, thickness, r, g, b, a, segments)
	segments = segments or 48
	local inner, outer = radius - thickness, radius
	surface.SetDrawColor(r, g, b, a)
	surface.SetTexture(0)
	for i = 0, segments - 1 do
		local d0 = math.rad(360 * (i / segments))
		local d1 = math.rad(360 * ((i + 1) / segments))
		surface.DrawPoly({
			{ x = cx + math.cos(d0) * inner, y = cy + math.sin(d0) * inner },
			{ x = cx + math.cos(d0) * outer, y = cy + math.sin(d0) * outer },
			{ x = cx + math.cos(d1) * outer, y = cy + math.sin(d1) * outer },
			{ x = cx + math.cos(d1) * inner, y = cy + math.sin(d1) * inner },
		})
	end
end

function soundesp:render()
	if not soundesp.teams then
		soundesp:fetchTeams()
	end

	-- trim expired pings before (and instead of) iterating twice
	local now = CurTime()
	local kept = {}
	for _, ping in ipairs(soundesp.pings) do
		if now - ping.time <= cfg.pingFadeTime and isValidEntity(ping.ply) then
			kept[#kept + 1] = ping
		end
	end
	soundesp.pings = kept

	local myTeam = LocalPlayer():Team()

	for _, ping in ipairs(soundesp.pings) do
		local age = now - ping.time
		local fraction = 1 - age / cfg.pingFadeTime

		local screenPos = ping.pos:ToScreen()
		if screenPos.visible == false then
			continue
		end

		local col = soundesp:getPingColor(ping.ply, myTeam)

		local pingRadius = 4 + age * 40
		drawRing(screenPos.x, screenPos.y, pingRadius, 1.5, col.r, col.g, col.b, 220 * fraction)
		drawFilledCircle(screenPos.x, screenPos.y, 3, col.r, col.g, col.b, 255 * math.max(fraction, 0.35))

		if cfg.showNames then
			surface.SetFont("BudgetLabel")
			surface.SetTextColor(col.r, col.g, col.b, 255 * fraction)
			surface.SetTextPos(screenPos.x + 8, screenPos.y - 6)
			surface.DrawText(ping.ply:Nick())
		end
	end
end

function soundesp:cleanup()
	soundesp.teams = nil
	soundesp.pings = {}
end

return soundesp
