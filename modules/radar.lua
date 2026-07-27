local radar = {}

radar.moduleInfo = {
	name = "Radar",
	description = "Top-down live positions of nearby players.",
	section = "render",
}

local cfg = af.config.register("radar", {
	range = { value = 2500, min = 500, max = 8000 },
	size = { value = 180, min = 110, max = 320 },
	corner = {
		value = "bottom-right",
		type = "selection",
		options = { "top-left", "top-right", "bottom-left", "bottom-right" },
	},
	showNames = { value = true },
	showHeight = { value = true },
	sweep = { value = true },
	rotate = { value = false },
}, { "range", "size", "corner", "showNames", "showHeight", "sweep", "rotate" })

local MARGIN = 24
local SEGMENTS = 48 -- perimeter smoothness for the circular panel
local EDGE_INSET = 6 -- keep clamped/out-of-range blips just inside the border
local HEIGHT_THRESHOLD = 80 -- world units before a height chevron shows
local STALE_FADE_TIME = 5 -- seconds for a swept dot to dim down to the floor
local STALE_FLOOR = 0.32 -- never dims past this fraction of full brightness
local PING_FLASH_TIME = 0.3 -- seconds the "just swept" ring flash lasts

local NEUTRAL = Color(215, 215, 215)
local ALLY = Color(95, 220, 130)
local ENEMY = Color(235, 75, 75)

radar.teams = nil
radar.lastSeen = {} -- ply -> { x, y, z, time } absolute world position at the last sweep pass
radar.prevSweepHead = nil -- previous frame's WORLD sweep angle, for detecting the arc just swept

--------------------------------------------------------------------------
-- team lookup (same lje.state.path trick esp.lua uses, kept self-contained
-- so radar doesn't depend on esp being enabled)
--------------------------------------------------------------------------

function radar:fetchTeams()
	local success, teams = pcall(function()
		return lje.state.path(lje.state.client, "team"):index("GetName"):upvalue(1):copy()
	end)

	if success then
		radar.teams = teams
	end
end

function radar:getTeamInfo(ply)
	if not radar.teams then
		return nil
	end
	return radar.teams[ply:Team()]
end

function radar:getBlipColor(ply, myTeam)
	local info = self:getTeamInfo(ply)
	if info and info.Color then
		return info.Color
	end

	if myTeam and myTeam ~= 0 then
		return ply:Team() == myTeam and ALLY or ENEMY
	end

	return NEUTRAL
end

--------------------------------------------------------------------------
-- drawing primitives (surface.DrawPoly needs an explicit blank texture and
-- a convex vertex list; everything below is built to stay convex)
--------------------------------------------------------------------------

-- rotates a world-space offset by `angleRad`; used to spin the whole radar
-- plane around the panel center when rotate mode is on, and left as a no-op
-- (angleRad = 0) in fixed north-up mode
local function rotatePoint(x, y, angleRad)
	local c, s = math.cos(angleRad), math.sin(angleRad)
	return x * c - y * s, x * s + y * c
end

-- true if angleDeg lies within the arc swept going from fromDeg to toDeg
-- (mod 360, so it stays correct across the 360/0 wrap the sweep does every lap)
local function angleInArc(angleDeg, fromDeg, toDeg)
	local span = (toDeg - fromDeg) % 360
	local rel = (angleDeg - fromDeg) % 360
	return rel <= span
end

local function circlePoints(cx, cy, radius, segments, startDeg, endDeg)
	startDeg = startDeg or 0
	endDeg = endDeg or 360
	local span = endDeg - startDeg
	local steps = math.max(3, math.floor(segments * (math.abs(span) / 360)))
	local points = {}
	for i = 0, steps do
		local rad = math.rad(startDeg + span * (i / steps))
		points[#points + 1] = { x = cx + math.cos(rad) * radius, y = cy + math.sin(rad) * radius }
	end
	return points
end

local function drawFilledCircle(cx, cy, radius, r, g, b, a)
	surface.SetDrawColor(r, g, b, a)
	surface.SetTexture(0)
	surface.DrawPoly(circlePoints(cx, cy, radius, SEGMENTS))
end

-- thin ring, built as a strip of quads between two radii (a true annulus
-- isn't convex, so a single DrawPoly can't punch a hole in a filled circle)
local function drawRing(cx, cy, radius, thickness, r, g, b, a, segments)
	segments = segments or SEGMENTS
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

-- filled pie slice; only ever called with a narrow span so it stays convex
local function drawSector(cx, cy, radius, startDeg, endDeg, r, g, b, a)
	local points = circlePoints(cx, cy, radius, SEGMENTS, startDeg, endDeg)
	table.insert(points, 1, { x = cx, y = cy })
	surface.SetDrawColor(r, g, b, a)
	surface.SetTexture(0)
	surface.DrawPoly(points)
end

local function drawChevron(cx, cy, size, pointUp, r, g, b, a)
	local tipY = pointUp and (cy - size) or (cy + size)
	local baseY = pointUp and (cy + size * 0.5) or (cy - size * 0.5)
	surface.SetDrawColor(r, g, b, a)
	surface.SetTexture(0)
	surface.DrawPoly({
		{ x = cx, y = tipY },
		{ x = cx - size * 0.7, y = baseY },
		{ x = cx + size * 0.7, y = baseY },
	})
end

-- arrow at the radar's center showing where we're actually looking. Takes an
-- explicit screen-space direction rather than a yaw, since in rotate mode
-- "forward" is always straight up by definition, and in fixed mode it's
-- derived from yaw using the same axis mapping as the blips below
local function drawPlayerArrow(cx, cy, dirX, dirY, size, r, g, b, a)
	local perpX, perpY = -dirY, dirX

	surface.SetDrawColor(r, g, b, a)
	surface.SetTexture(0)
	surface.DrawPoly({
		{ x = cx + dirX * size, y = cy + dirY * size },
		{ x = cx - dirX * size * 0.5 + perpX * size * 0.55, y = cy - dirY * size * 0.5 + perpY * size * 0.55 },
		{ x = cx - dirX * size * 0.5 - perpX * size * 0.55, y = cy - dirY * size * 0.5 - perpY * size * 0.55 },
	})
end

--------------------------------------------------------------------------
-- module
--------------------------------------------------------------------------

function radar:render()
	if not radar.teams then
		radar:fetchTeams()
	end

	local ply = LocalPlayer()
	local ac = af.brand.color

	local size = cfg.size
	local rad = size / 2
	local scrW, scrH = ScrW(), ScrH()

	local cx, cy
	if cfg.corner == "top-left" then
		cx, cy = MARGIN + rad, MARGIN + rad
	elseif cfg.corner == "top-right" then
		cx, cy = scrW - MARGIN - rad, MARGIN + rad
	elseif cfg.corner == "bottom-left" then
		cx, cy = MARGIN + rad, scrH - MARGIN - rad
	else
		cx, cy = scrW - MARGIN - rad, scrH - MARGIN - rad
	end

	--drawFilledCircle(cx + 3, cy + 4, rad + 2, 0, 0, 0, 110) -- drop shadow
	drawFilledCircle(cx, cy, rad, 12, 14, 18, 215) -- panel

	drawRing(cx, cy, rad * (1 / 3), 1, ac.r, ac.g, ac.b, 30)
	drawRing(cx, cy, rad * (2 / 3), 1, ac.r, ac.g, ac.b, 30)

	local yawRad = math.rad(ply:EyeAngles()[2])
	-- rotate mode: spin the whole plane so "forward" always renders as up.
	-- fixed mode: no rotation, world +Y is always up (delta stays 0)
	local delta = cfg.rotate and (math.pi / 2 - yawRad) or 0
	local deltaDeg = math.deg(delta)

	-- the sweep progresses in pure world-angle terms, completely independent
	-- of view/rotate-mode, so spinning the camera can never "cheat" a scan.
	-- for drawing we convert that world angle into a display angle with the
	-- same transform the blips below go through, so the beam always visually
	-- lines up with whatever it's currently sweeping over on screen
	local worldSweepHead = cfg.sweep and ((SysTime() * 70) % 360) or nil

	if worldSweepHead then
		local displaySweepHead = -(worldSweepHead + deltaDeg) % 360
		local trail = 6
		for i = 0, trail - 1 do
			local fade = 1 - (i / trail)
			drawSector(
				cx, cy, rad - 2,
				displaySweepHead + i * 5, displaySweepHead + (i + 1) * 5,
				ac.r, ac.g, ac.b, 50 * fade
			)
		end
	end

	drawRing(cx, cy, rad, 2, ac.r, ac.g, ac.b, 210) -- border

	surface.SetFont("BudgetLabel")
	local nW, nH = surface.GetTextSize("N")
	local nx, ny = rotatePoint(0, 1, delta) -- world north, spun the same way as blips
	local labelR = rad + nH / 2 - 20
	surface.SetTextColor(ac.r, ac.g, ac.b, 180)
	surface.SetTextPos(cx + nx * labelR - nW / 2, cy - ny * labelR - nH / 2)
	surface.DrawText("N")

	local myPos = ply:GetPos()
	local myTeam = ply:Team()
	local scale = (rad - EDGE_INSET) / cfg.range

	for _, other in ipairs(player.GetAll()) do
		if other == ply or not other:Alive() then
			continue
		end

		local pos = other:GetPos()
		local liveDx = pos.x - myPos.x
		local liveDy = pos.y - myPos.y

		-- with sweep off, always render the live position (no staleness).
		-- with sweep on, only re-anchor to a player's current spot once the
		-- sweep passes their true WORLD bearing (never their on-screen
		-- bearing - that would let spinning the camera fake a scan). Once
		-- anchored we store their absolute world position, not an offset
		-- from us, and re-derive dx/dy from our own current position every
		-- frame - so as we move, the stale dot correctly drifts relative to
		-- us instead of just sitting dead at a now-meaningless offset
		local dx, dy, dz, age = liveDx, liveDy, pos.z - myPos.z, 0
		if worldSweepHead then
			local worldAngle = math.deg(math.atan2(liveDy, liveDx)) % 360

			local seen = radar.lastSeen[other]
			local swept = radar.prevSweepHead and angleInArc(worldAngle, radar.prevSweepHead, worldSweepHead)

			if not seen or swept then
				seen = { x = pos.x, y = pos.y, z = pos.z, time = SysTime() }
				radar.lastSeen[other] = seen
			end

			dx, dy, dz, age = seen.x - myPos.x, seen.y - myPos.y, seen.z - myPos.z, SysTime() - seen.time
		end

		local dist = math.sqrt(dx * dx + dy * dy)

		local rx, ry = rotatePoint(dx, dy, delta)
		local px, py = rx * scale, -ry * scale -- flip Y so "up" in radar space renders as up on screen
		local ptDist = math.sqrt(px * px + py * py)
		local maxDist = rad - EDGE_INSET

		local clamped = ptDist > maxDist
		if clamped then
			local ang = math.atan2(py, px)
			px, py = math.cos(ang) * maxDist, math.sin(ang) * maxDist
		end

		local bx, by = cx + px, cy + py
		local col = radar:getBlipColor(other, myTeam)
		local freshness = worldSweepHead and math.clamp(1 - age / STALE_FADE_TIME, STALE_FLOOR, 1) or 1
		local alpha = (clamped and 140 or math.clamp(255 - (dist / cfg.range) * 110, 140, 255)) * freshness
		local dotSize = clamped and 3 or 4.5

		drawFilledCircle(bx, by, dotSize + 1.5, 0, 0, 0, alpha * 0.5) -- outline
		drawFilledCircle(bx, by, dotSize, col.r, col.g, col.b, alpha)

		if worldSweepHead and age < PING_FLASH_TIME then
			local flash = 1 - (age / PING_FLASH_TIME)
			drawRing(bx, by, dotSize + 2 + flash * 6, 1.5, col.r, col.g, col.b, 200 * flash)
		end

		if cfg.showHeight and not clamped then
			if dz > HEIGHT_THRESHOLD then
				drawChevron(bx, by - dotSize - 5, 3.5, true, col.r, col.g, col.b, alpha)
			elseif dz < -HEIGHT_THRESHOLD then
				drawChevron(bx, by + dotSize + 5, 3.5, false, col.r, col.g, col.b, alpha)
			end
		end

		if cfg.showNames and not clamped and dist < cfg.range * 0.95 then
			surface.SetFont("BudgetLabel")
			surface.SetTextColor(255, 255, 255, alpha)
			local tw = surface.GetTextSize(other:Nick())
			surface.SetTextPos(bx - tw / 2, by + dotSize + 3)
			surface.DrawText(other:Nick())
		end
	end

	radar.prevSweepHead = worldSweepHead

	-- fixed mode: arrow points toward actual yaw. rotate mode: forward is
	-- always up by construction, so the arrow just stays pointed up
	local arrowDirX, arrowDirY
	if cfg.rotate then
		arrowDirX, arrowDirY = 0, -1
	else
		arrowDirX, arrowDirY = math.cos(yawRad), -math.sin(yawRad)
	end
	drawPlayerArrow(cx, cy, arrowDirX, arrowDirY, 7, ac.r, ac.g, ac.b, 255)
end

function radar:cleanup()
	radar.teams = nil
	radar.lastSeen = {}
	radar.prevSweepHead = nil
end

return radar
