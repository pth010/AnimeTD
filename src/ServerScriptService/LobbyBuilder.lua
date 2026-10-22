-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: LobbyBuilder
-- (replaces the earlier version: adds the Damage Challenge corner (back left): a red gate
--  with a pad to start the solo challenge, a TOP DAMAGE leaderboard board, and a teleport spot)
-- Builds the lobby at runtime:
--   * a 300 x 300 stud city square under the open sky: tiled paving, red-brick paths from the
--     torii gate to the fountain and from the fountain to the gates, the grotto and the park,
--     sakura trees, street lamps and benches
--   * a ring of buildings around it (shops with awnings and neon signs, lit windows, rooftop
--     props), with wide gaps: the one behind the team gates looks out on a lit pagoda. A torii
--     gate at the front, corner towers and a skyline of taller towers further back
--   * a night sky with stars, moonlight, a light night haze and bloom so the lit windows,
--     neon signs and lamps glow. Lighting is shared by the whole server, so the day and night
--     settings are stored on Lighting as attributes and each player's screen switches to day
--     during a match (see PlacementUI)
--   * invisible walls at the edge of the square so nobody wanders off
--   * the default Baseplate is hidden (made invisible and not solid): the lobby has its own
--     ground, and a ring of distant buildings closes off the view outside the city
--   * the player spawn by the torii gate. It's invisible, and so is any other spawn pad
--   * the Wishing Fountain in the middle of a big raised round plaza with steps all round
--     (walk up to it and the summon window pops up)
--   * FIVE team gates in an arc behind the fountain: a round glowing platform to stand on, a
--     gate in the team's color and a sign hanging in it with the live queue status
--   * the Traits Cave on the right: a grotto of rock with a roof, open at the front, full of
--     glowing crystals, with "TRAITS" spelled out in crystals on the front of the roof (walk
--     inside and the trait summon window pops up)
--   * a park on the left with a koi pond
--   * the Damage Challenge in the back left corner: a red gate with a pad to start the solo
--     challenge, and a board with the best scores
--   * teleport spots in front of each place, for the Teleport menu (LobbyTeleportUI)
-- Assumes the default 512x512 Baseplate (the square is centered on the origin).
-- If Workspace.Lobby already exists (you built your own), this script does nothing.
-- A custom lobby needs: Lobby.LobbySpawn, Lobby.SummonAltar (a flat part marking the summon
-- area), Lobby.TraitCave (a flat part marking the trait summon area), and Lobby.QueuePads
-- containing Pad1..Pad5 (flat parts marking where to stand, colored like the team) and
-- Sign1..Sign5 (parts holding a SurfaceGui named QueueGui with a TextLabel named Label inside).

if workspace:FindFirstChild("Lobby") then return end
if require(game:GetService("ReplicatedStorage"):WaitForChild("PlaceConfig")).IsMatchPlace() then return end

local RunService = game:GetService("RunService")

local CENTER = Vector3.new(0, 0, 0)
local SIZE = 300   -- the city square is SIZE x SIZE studs
local NUM_PADS = 5
local MAX_PLAYERS = 4 -- only used for the starting sign text

local TEAM_COLORS = {
	Color3.fromRGB(235, 70, 70),
	Color3.fromRGB(70, 130, 255),
	Color3.fromRGB(70, 200, 110),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(170, 90, 255),
}

local half = SIZE / 2

local lobby = Instance.new("Folder")
lobby.Name = "Lobby"
local roomFolder = Instance.new("Folder")
roomFolder.Name = "City"
roomFolder.Parent = lobby
local padsFolder = Instance.new("Folder")
padsFolder.Name = "QueuePads"
padsFolder.Parent = lobby

local function makePart(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- An invisible part that's only there to mark an area (or hold an effect)
local function marker(parent, name, size, cframe, color)
	local p = makePart(parent, name, size, cframe.Position, color or Color3.new(1, 1, 1))
	p.CFrame = cframe
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- A flat disc lying on the ground (cylinders point along X, so tip it up)
local function disc(parent, name, center, diameter, thickness, y, color, material)
	local d = makePart(parent, name, Vector3.new(thickness, diameter, diameter), center, color, material)
	d.Shape = Enum.PartType.Cylinder
	d.CFrame = CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return d
end

-- A round wall made of short blocks around `center`, from angle a0 to a1 (degrees; 0 = +X,
-- 90 = +Z). Returns the blocks.
local function arcWall(parent, name, center, radius, height, thickness, y, color, material, segments, a0, a1)
	a0, a1 = a0 or 0, a1 or 360
	local blocks = {}
	local step = (a1 - a0) / segments
	for i = 1, segments do
		local a = math.rad(a0 + (i - 0.5) * step)
		local length = 2 * math.pi * radius * math.abs(step) / 360 + 0.15
		local seg = makePart(parent, name, Vector3.new(length, height, thickness), center, color, material)
		local pos = center + Vector3.new(math.cos(a) * radius, y + height / 2, math.sin(a) * radius)
		-- facing the centre, so the block's length (X) runs along the circle
		seg.CFrame = CFrame.lookAt(pos, center + Vector3.new(0, y + height / 2, 0))
		table.insert(blocks, seg)
	end
	return blocks
end

-- A sign panel: a thin bar in the accent color along the top and a body TextLabel named Label
-- filling the rest, on a SurfaceGui named QueueGui. The text is printed on the panel's Back
-- face, so `cframe` should point the panel's +Z toward whoever reads it. Returns the panel and
-- the body TextLabel.
local function signPanel(parent, name, cframe, size, accent, body)
	local board = makePart(parent, name, size, cframe.Position, Color3.fromRGB(24, 24, 40))
	board.CFrame = cframe

	local gui = Instance.new("SurfaceGui")
	gui.Name = "QueueGui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(520, math.floor(520 * size.Y / size.X)) -- same shape as the board
	gui.LightInfluence = 0
	gui.Parent = board

	-- a thin accent frame around the whole panel, and a bar along the top
	local frameStroke = Instance.new("Frame")
	frameStroke.Size = UDim2.fromScale(1, 1)
	frameStroke.BackgroundTransparency = 1
	frameStroke.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = accent
	outline.Thickness = 6
	outline.Parent = frameStroke
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 0.1)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = gui

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Position = UDim2.fromScale(0, 0.1)
	label.Size = UDim2.fromScale(1, 0.9)
	label.BackgroundTransparency = 1
	label.Text = body
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingTop = UDim.new(0, 16)
	bodyPad.PaddingBottom = UDim.new(0, 16)
	bodyPad.PaddingLeft = UDim.new(0, 18)
	bodyPad.PaddingRight = UDim.new(0, 18)
	bodyPad.Parent = label

	return board, label
end

-- ===== The city square =====
-- Everything is built from a fixed random seed, so the city looks the same every time.
local cityRng = Random.new(2024)
local EDGE = half          -- the square runs from -EDGE to +EDGE on X and Z
local STREET = EDGE + 4    -- the buildings' front faces stand here

local PAVING = Color3.fromRGB(122, 116, 134)
local PAVING_DARK = Color3.fromRGB(104, 98, 120)
local BRICK = Color3.fromRGB(150, 52, 44)
local GRASS = Color3.fromRGB(58, 132, 58)
local SAKURA = Color3.fromRGB(255, 183, 213)
local STONE = Color3.fromRGB(205, 200, 215)
local STONE_DARK = Color3.fromRGB(150, 145, 165)

-- Where things are (X is left/right, -Z is the back, +Z the front where you spawn)
local FOUNTAIN_POS = CENTER + Vector3.new(0, 0, 10)   -- the hub in the middle
local GATES_CENTER = CENTER + Vector3.new(0, 0, -40)  -- the team gates stand in an arc around this
local GATES_RADIUS = 62
local CAVE_POS = CENTER + Vector3.new(100, 0, 8)      -- the grotto, on the right
local POND_POS = CENTER + Vector3.new(-100, 0, 10)    -- the koi pond, in the park on the left
local CHALLENGE_POS = CENTER + Vector3.new(-112, 0, -100) -- the Damage Challenge, back left
local SPAWN_POS = CENTER + Vector3.new(0, 0, 118)     -- by the torii gate

-- The default Baseplate would show as flat grey ground past the city, so hide it (it stays in
-- the place, just invisible and not solid)
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Transparency = 1
	baseplate.CanCollide = false
	baseplate.CanQuery = false
	baseplate.CanTouch = false
	for _, d in ipairs(baseplate:GetDescendants()) do
		if d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
end

-- Paving, with a big two-tone tile pattern
makePart(roomFolder, "Floor", Vector3.new(SIZE, 0.4, SIZE), CENTER + Vector3.new(0, 0.2, 0), PAVING, Enum.Material.Slate)

-- Street ground under the buildings around the square (the city's own ground, since the
-- Baseplate is hidden)
local BACKDROP = EDGE + 52 -- the ring of distant buildings
local GROUND_OUT = BACKDROP + 4
for _, g in ipairs({
	{ Vector3.new(GROUND_OUT * 2, 1, GROUND_OUT - EDGE), Vector3.new(0, -0.5, (GROUND_OUT + EDGE) / 2) },
	{ Vector3.new(GROUND_OUT * 2, 1, GROUND_OUT - EDGE), Vector3.new(0, -0.5, -(GROUND_OUT + EDGE) / 2) },
	{ Vector3.new(GROUND_OUT - EDGE, 1, SIZE), Vector3.new((GROUND_OUT + EDGE) / 2, -0.5, 0) },
	{ Vector3.new(GROUND_OUT - EDGE, 1, SIZE), Vector3.new(-(GROUND_OUT + EDGE) / 2, -0.5, 0) },
}) do
	makePart(roomFolder, "Street", g[1], CENTER + g[2], Color3.fromRGB(60, 60, 68), Enum.Material.Asphalt)
end
local TILE = 30
for ix = 0, SIZE / TILE - 1 do
	for iz = 0, SIZE / TILE - 1 do
		if (ix + iz) % 2 == 0 then
			local tile = makePart(roomFolder, "Tile", Vector3.new(TILE, 0.05, TILE),
				CENTER + Vector3.new(-EDGE + TILE * (ix + 0.5), 0.425, -EDGE + TILE * (iz + 0.5)), PAVING_DARK, Enum.Material.Slate)
			tile.CanCollide = false
		end
	end
end

-- Red-brick paths: from the torii gate to the fountain, and from the fountain to the gates,
-- the grotto and the park
local function path(name, x0, x1, z0, z1)
	makePart(roomFolder, name, Vector3.new(x1 - x0, 0.1, z1 - z0), CENTER + Vector3.new((x0 + x1) / 2, 0.5, (z0 + z1) / 2), BRICK, Enum.Material.Brick)
end
-- (they start at the foot of the raised plaza around the fountain, see Wishing Fountain)
path("Walkway", -10, 10, 46, EDGE)
path("GatePath", -10, 10, -89, -26) -- up to the arc in front of the gates
path("CavePath", 36, 82, 1, 15)
path("ParkPath", -76, -36, 3, 17)
-- a brick band under the gates, joining them up. It's made of straight pieces around the
-- curve, each as wide as the band's outer edge needs, so there are no gaps between them; every
-- other piece sits a hair higher so where they overlap doesn't flicker.
local ARC_WIDTH = 28   -- how wide the band is (from the inside of the curve to the outside)
local ARC_SPAN = 160   -- degrees of the curve it covers
local ARC_PIECES = 72
for i = 1, ARC_PIECES do
	local a = math.rad(-ARC_SPAN / 2 + (i - 0.5) * (ARC_SPAN / ARC_PIECES))
	local y = 0.5 + (i % 2) * 0.01
	local pos = GATES_CENTER + Vector3.new(math.sin(a) * GATES_RADIUS, y, -math.cos(a) * GATES_RADIUS)
	local outerLength = 2 * math.pi * (GATES_RADIUS + ARC_WIDTH / 2) * (ARC_SPAN / ARC_PIECES) / 360
	local seg = makePart(roomFolder, "GateArc", Vector3.new(outerLength + 0.4, 0.1, ARC_WIDTH), pos, BRICK, Enum.Material.Brick)
	seg.CFrame = CFrame.lookAt(pos, Vector3.new(GATES_CENTER.X, pos.Y, GATES_CENTER.Z))
end
-- a lighter sidewalk band around the edge
for _, side in ipairs({ { Vector3.new(SIZE, 0.1, 8), Vector3.new(0, 0, EDGE - 4) }, { Vector3.new(SIZE, 0.1, 8), Vector3.new(0, 0, -EDGE + 4) },
	{ Vector3.new(8, 0.1, SIZE - 16), Vector3.new(EDGE - 4, 0, 0) }, { Vector3.new(8, 0.1, SIZE - 16), Vector3.new(-EDGE + 4, 0, 0) } }) do
	makePart(roomFolder, "Sidewalk", side[1], CENTER + side[2] + Vector3.new(0, 0.48, 0), Color3.fromRGB(150, 145, 162), Enum.Material.Concrete)
end

-- Green lawns in the open areas of the square, each with a low stone edge
local function lawn(x0, x1, z0, z1)
	local size = Vector3.new(x1 - x0, 0.12, z1 - z0)
	local center = CENTER + Vector3.new((x0 + x1) / 2, 0.5, (z0 + z1) / 2)
	makePart(roomFolder, "Lawn", size, center, GRASS, Enum.Material.Grass)
	for _, e in ipairs({
		{ Vector3.new(size.X + 1, 0.5, 0.5), Vector3.new(0, 0, size.Z / 2) },
		{ Vector3.new(size.X + 1, 0.5, 0.5), Vector3.new(0, 0, -size.Z / 2) },
		{ Vector3.new(0.5, 0.5, size.Z), Vector3.new(size.X / 2, 0, 0) },
		{ Vector3.new(0.5, 0.5, size.Z), Vector3.new(-size.X / 2, 0, 0) },
	}) do
		makePart(roomFolder, "LawnEdge", e[1], center + e[2] + Vector3.new(0, 0.1, 0), Color3.fromRGB(105, 100, 112), Enum.Material.Concrete)
	end
end
lawn(-140, -76, -36, 58)   -- the park (the koi pond sits in it)
lawn(-140, -22, 78, 140)   -- front left, beside the walkway
lawn(22, 140, 78, 140)     -- front right, beside the walkway
-- (the back left corner is the Damage Challenge, see further down)
lawn(88, 140, -140, -62)   -- back right corner

-- Invisible walls at the edge of the square (the gaps between buildings are open)
for _, wall in ipairs({ { Vector3.new(SIZE + 8, 120, 2), Vector3.new(0, 60, EDGE + 2) }, { Vector3.new(SIZE + 8, 120, 2), Vector3.new(0, 60, -EDGE - 2) },
	{ Vector3.new(2, 120, SIZE + 8), Vector3.new(EDGE + 2, 60, 0) }, { Vector3.new(2, 120, SIZE + 8), Vector3.new(-EDGE - 2, 60, 0) } }) do
	local w = makePart(roomFolder, "Boundary", wall[1], CENTER + wall[2], Color3.new(1, 1, 1))
	w.Transparency = 1
end

-- A grid of windows painted on one face of a part (lit warm yellow or dark blue).
-- spacing = studs between windows across (rows are 1 stud further apart); far-away
-- buildings use wider spacing so the city doesn't need thousands of windows.
local function windows(part, face, widthStuds, heightStuds, bottomGap, topGap, spacing)
	spacing = spacing or 6
	local rowStep = spacing + 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.LightInfluence = 0 -- windows glow at night
	gui.Parent = part
	local cols = math.max(1, math.floor(widthStuds / spacing))
	local rows = math.max(1, math.floor((heightStuds - bottomGap - topGap) / rowStep))
	for r = 1, rows do
		for c = 1, cols do
			local lit = cityRng:NextNumber() < 0.45
			local win = Instance.new("Frame")
			win.BorderSizePixel = 0
			win.AnchorPoint = Vector2.new(0.5, 0.5)
			win.Size = UDim2.fromScale(0.55 / cols, 3.6 / heightStuds)
			win.Position = UDim2.fromScale((c - 0.5) / cols, (topGap + (r - 0.5) * rowStep) / heightStuds)
			win.BackgroundColor3 = lit and Color3.fromRGB(255, 222, 150) or Color3.fromRGB(46, 62, 92)
			win.Parent = gui
		end
	end
end

-- Big text painted on one face of a part
local function signText(part, face, text, color, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.Font = font or Enum.Font.FredokaOne
	l.TextScaled = true
	l.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = l
	return l
end

local BUILDING_COLORS = {
	Color3.fromRGB(28, 104, 116), Color3.fromRGB(128, 34, 56), Color3.fromRGB(86, 48, 140),
	Color3.fromRGB(36, 58, 120), Color3.fromRGB(36, 98, 66), Color3.fromRGB(176, 82, 34),
	Color3.fromRGB(140, 36, 104), Color3.fromRGB(58, 46, 118),
}
local ACCENTS = {
	Color3.fromRGB(235, 70, 70), Color3.fromRGB(60, 150, 230), Color3.fromRGB(70, 190, 120),
	Color3.fromRGB(250, 180, 50), Color3.fromRGB(160, 90, 230), Color3.fromRGB(240, 110, 170),
}
local SHOPS = { "RAMEN", "ARCADE", "MANGA", "CAFE", "BOBA", "SUSHI", "GAMES", "BAKERY", "DOJO", "FLOWERS", "KARAOKE", "TOYS" }
local VERTICAL_SIGNS = { "SAKURA", "HOTEL", "NEON", "TOKYO", "ANIME", "MOCHI" }
local shopIndex, vertIndex = 0, 0

-- One city building with its front facing the square.
--   frontCenter: the middle of the bottom edge of its front face; facing: toward the square
local function building(frontCenter, facing, width, depth, height, opts)
	opts = opts or {}
	local color = opts.Color or BUILDING_COLORS[cityRng:NextInteger(1, #BUILDING_COLORS)]
	local accent = ACCENTS[cityRng:NextInteger(1, #ACCENTS)]
	-- local frame: -Z (Front) points at the square, the origin at the front-bottom-middle
	local base = CFrame.lookAt(frontCenter, frontCenter + facing)

	local body = makePart(roomFolder, "Building", Vector3.new(width, height, depth), frontCenter, color, Enum.Material.SmoothPlastic)
	body.CFrame = base * CFrame.new(0, height / 2, depth / 2)
	local shopFloor = opts.Shop ~= false and 10 or 0
	windows(body, Enum.NormalId.Front, width, height, shopFloor + 2, 3)

	-- roof lip and rooftop props
	local lip = makePart(roomFolder, "RoofLip", Vector3.new(width + 1, 1.2, depth + 1), frontCenter, color:Lerp(Color3.new(0, 0, 0), 0.25))
	lip.CFrame = base * CFrame.new(0, height + 0.6, depth / 2)
	if cityRng:NextNumber() < 0.6 then
		local tank = makePart(roomFolder, "WaterTank", Vector3.new(6, 5, 5), frontCenter, Color3.fromRGB(150, 110, 80), Enum.Material.WoodPlanks)
		tank.Shape = Enum.PartType.Cylinder
		tank.CFrame = base * CFrame.new(cityRng:NextNumber(-width / 4, width / 4), height + 4.2, depth * 0.6) * CFrame.Angles(0, 0, math.rad(90))
	end
	for _ = 1, cityRng:NextInteger(0, 2) do
		local ac = makePart(roomFolder, "AirCon", Vector3.new(3, 2, 3), frontCenter, Color3.fromRGB(190, 192, 198), Enum.Material.Metal)
		ac.CFrame = base * CFrame.new(cityRng:NextNumber(-width / 3, width / 3), height + 2.2, cityRng:NextNumber(4, depth - 4))
	end

	if opts.Shop ~= false then
		-- the shop front: glass, an awning in the accent color and a lit sign
		local glass = makePart(roomFolder, "ShopWindow", Vector3.new(width - 4, 6, 0.3), frontCenter, Color3.fromRGB(150, 200, 230), Enum.Material.Glass)
		glass.Transparency = 0.35
		glass.CFrame = base * CFrame.new(0, 3.6, -0.1)
		local awning = makePart(roomFolder, "Awning", Vector3.new(width - 2, 0.4, 4.5), frontCenter, accent, Enum.Material.Fabric)
		awning.CFrame = base * CFrame.new(0, 8, -2) * CFrame.Angles(math.rad(-16), 0, 0)
		shopIndex += 1
		local sign = makePart(roomFolder, "ShopSign", Vector3.new(math.min(width - 4, 18), 2.6, 0.4), frontCenter, Color3.fromRGB(30, 26, 40))
		sign.CFrame = base * CFrame.new(0, 10.6, -0.3)
		signText(sign, Enum.NormalId.Front, SHOPS[(shopIndex - 1) % #SHOPS + 1], accent:Lerp(Color3.new(1, 1, 1), 0.35))
		-- paper lanterns at the awning's corners
		for _, sx in ipairs({ -1, 1 }) do
			local lantern = makePart(roomFolder, "Lantern", Vector3.new(1.4, 1.8, 1.4), frontCenter, Color3.fromRGB(235, 70, 60), Enum.Material.Neon)
			lantern.Shape = Enum.PartType.Ball
			lantern.CanCollide = false
			lantern.CFrame = base * CFrame.new(sx * (width / 2 - 2), 6.4, -4.2)
		end
	end

	-- some buildings get a tall vertical neon sign on one edge
	if opts.Vertical or (opts.Vertical == nil and height > 40 and cityRng:NextNumber() < 0.5) then
		vertIndex += 1
		local word = VERTICAL_SIGNS[(vertIndex - 1) % #VERTICAL_SIGNS + 1]
		local tall = makePart(roomFolder, "VerticalSign", Vector3.new(3, #word * 3 + 2, 0.8), frontCenter, Color3.fromRGB(28, 22, 40))
		tall.CFrame = base * CFrame.new((width / 2 - 2.5) * (vertIndex % 2 == 0 and 1 or -1), 14 + (#word * 3 + 2) / 2, -1.2)
		signText(tall, Enum.NormalId.Front, table.concat(string.split(word, ""), "\n"), accent:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Font.GothamBlack)
	end
	return body
end

-- A row of buildings along one side, skipping the gaps listed in `skip` ({ from, to } along the row)
local function buildingRow(origin, along, facing, from, to, skip, depth)
	local pos = from
	while pos < to - 6 do
		local width = math.min(cityRng:NextInteger(20, 32), to - pos)
		local blocked = false
		for _, gap in ipairs(skip or {}) do
			if pos + width > gap[1] and pos < gap[2] then
				if gap[1] - pos >= 12 then
					width = gap[1] - pos -- squeeze a narrower building in before the gap
				else
					blocked = true
					pos = gap[2]
				end
				break
			end
		end
		if not blocked then
			local height = cityRng:NextInteger(24, 52)
			building(origin + along * (pos + width / 2), facing, width - 0.6, depth or 30, height)
			pos += width
		end
	end
end

-- back side (behind the gates): a wide gap in the middle that looks out on the pagoda
buildingRow(CENTER + Vector3.new(0, 0, -STREET), Vector3.xAxis, Vector3.zAxis, -EDGE - 8, EDGE + 8, { { -70, 70 } })
-- front side (behind the spawn): a gap for the torii gate in the middle
buildingRow(CENTER + Vector3.new(0, 0, STREET), Vector3.xAxis, -Vector3.zAxis, -EDGE - 8, EDGE + 8, { { -18, 18 } })
-- left and right sides, each with a gap opposite the park and the grotto
buildingRow(CENTER + Vector3.new(-STREET, 0, 0), Vector3.zAxis, Vector3.xAxis, -EDGE + 8, EDGE - 8, { { -10, 30 } })
buildingRow(CENTER + Vector3.new(STREET, 0, 0), Vector3.zAxis, -Vector3.xAxis, -EDGE + 8, EDGE - 8, { { -12, 28 } })

-- tall towers in the four corners
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local corner = CENTER + Vector3.new(sx * (STREET + 8), 0, sz * (STREET + 8))
		local toSquare = Vector3.new(-sx, 0, -sz).Unit
		building(corner - toSquare * 2, toSquare, 30, 30, cityRng:NextInteger(85, 110), { Shop = false, Vertical = true })
	end
end

-- a skyline of taller towers further back, for depth (none right behind the pagoda)
for side = 1, 4 do
	local dir = ({ Vector3.zAxis, -Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis })[side]
	local along = math.abs(dir.Z) > 0 and Vector3.xAxis or Vector3.zAxis
	for i = -2, 2 do
		if not (side == 2 and i == 0) then
			local width = cityRng:NextInteger(30, 46)
			local front = CENTER + dir * cityRng:NextInteger(EDGE + 65, EDGE + 95) + along * (i * 72 + cityRng:NextInteger(-10, 10))
			local tower = makePart(roomFolder, "SkylineTower", Vector3.new(width, 1, width), front, Color3.new(1, 1, 1))
			local height = cityRng:NextInteger(110, 190)
			tower.Size = Vector3.new(width, height, width)
			tower.Color = Color3.fromRGB(26, 30, 60):Lerp(Color3.fromRGB(56, 62, 108), cityRng:NextNumber())
			tower.CFrame = CFrame.lookAt(front, front - dir) * CFrame.new(0, height / 2, width / 2)
			windows(tower, Enum.NormalId.Front, width, height, 4, 4, 8)
		end
	end
end

-- A ring of distant buildings right behind the shops, so the gaps between buildings show
-- more city instead of the empty world outside
for side = 1, 4 do
	local dir = ({ Vector3.zAxis, -Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis })[side]
	local length = BACKDROP * 2 + 4
	local front = CENTER + dir * BACKDROP
	local wall = makePart(roomFolder, "Backdrop", Vector3.new(length, 50, 4), front, Color3.fromRGB(32, 36, 66))
	wall.CFrame = CFrame.lookAt(front, front - dir) * CFrame.new(0, 25, 2)
	windows(wall, Enum.NormalId.Front, length, 50, 4, 4, 10)
end

-- The pagoda, seen through the gap behind the team gates: five tiers getting narrower, each
-- with a dark roof and a glowing trim, and a golden spire on top
do
	local pagodaPos = CENTER + Vector3.new(0, 0, -(STREET + 30))
	local RED = Color3.fromRGB(170, 40, 40)
	local ROOF = Color3.fromRGB(40, 36, 48)
	local TRIM = Color3.fromRGB(255, 190, 90)
	makePart(roomFolder, "PagodaBase", Vector3.new(40, 3, 40), pagodaPos + Vector3.new(0, 1.5, 0), STONE_DARK, Enum.Material.Slate)
	local y = 3
	for tier = 1, 5 do
		local width = 30 - (tier - 1) * 4.5
		local height = tier == 1 and 12 or 9
		local body = makePart(roomFolder, "PagodaTier", Vector3.new(width, height, width), pagodaPos + Vector3.new(0, y + height / 2, 0), RED, Enum.Material.Wood)
		windows(body, Enum.NormalId.Front, width, height, 2, 2, 5)
		y += height
		makePart(roomFolder, "PagodaRoof", Vector3.new(width + 9, 1.6, width + 9), pagodaPos + Vector3.new(0, y + 0.8, 0), ROOF, Enum.Material.Slate)
		makePart(roomFolder, "PagodaRoofTop", Vector3.new(width + 4, 1.4, width + 4), pagodaPos + Vector3.new(0, y + 2.3, 0), ROOF, Enum.Material.Slate)
		local trim = makePart(roomFolder, "PagodaTrim", Vector3.new(width + 9.2, 0.35, width + 9.2), pagodaPos + Vector3.new(0, y - 0.1, 0), TRIM, Enum.Material.Neon)
		trim.CanCollide = false
		-- lanterns hanging from the roof's corners
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local lantern = makePart(roomFolder, "PagodaLantern", Vector3.new(1.4, 1.8, 1.4),
					pagodaPos + Vector3.new(sx * (width / 2 + 4), y - 1.4, sz * (width / 2 + 4)), Color3.fromRGB(235, 70, 60), Enum.Material.Neon)
				lantern.Shape = Enum.PartType.Ball
				lantern.CanCollide = false
			end
		end
		y += 3
	end
	local spire = makePart(roomFolder, "PagodaSpire", Vector3.new(1.2, 14, 1.2), pagodaPos + Vector3.new(0, y + 7, 0), Color3.fromRGB(255, 205, 70), Enum.Material.Metal)
	for i = 1, 4 do
		local ring = makePart(roomFolder, "SpireRing", Vector3.new(0.5, 3 - i * 0.4, 3 - i * 0.4), spire.Position + Vector3.new(0, -5 + i * 2.2, 0), Color3.fromRGB(255, 205, 70), Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(ring.Position) * CFrame.Angles(0, 0, math.rad(90))
	end
	local glowPart = marker(roomFolder, "PagodaGlow", Vector3.new(1, 1, 1), CFrame.new(pagodaPos + Vector3.new(0, 30, 24)))
	local light = Instance.new("PointLight")
	light.Color = TRIM
	light.Range = 45
	light.Brightness = 1.2
	light.Parent = glowPart
end

-- Torii gate behind the spawn (in the gap of the front row)
do
	local RED = Color3.fromRGB(205, 45, 40)
	local gateZ = EDGE - 6
	for _, sx in ipairs({ -1, 1 }) do
		local post = makePart(roomFolder, "ToriiPost", Vector3.new(2.6, 22, 2.6), CENTER + Vector3.new(sx * 13, 11, gateZ), RED, Enum.Material.Wood)
		post.Shape = Enum.PartType.Block
		makePart(roomFolder, "ToriiFoot", Vector3.new(3.4, 1.4, 3.4), CENTER + Vector3.new(sx * 13, 0.9, gateZ), Color3.fromRGB(40, 36, 40))
	end
	makePart(roomFolder, "ToriiTopBeam", Vector3.new(36, 2.2, 3.4), CENTER + Vector3.new(0, 23, gateZ), Color3.fromRGB(40, 36, 40), Enum.Material.Wood)
	makePart(roomFolder, "ToriiBeam", Vector3.new(32, 1.8, 2.2), CENTER + Vector3.new(0, 18.5, gateZ), RED, Enum.Material.Wood)
	local plaque = makePart(roomFolder, "ToriiPlaque", Vector3.new(6, 4, 0.6), CENTER + Vector3.new(0, 20.8, gateZ), Color3.fromRGB(40, 36, 40))
	signText(plaque, Enum.NormalId.Back, "ANIME\nTD", Color3.fromRGB(255, 215, 120), Enum.Font.GothamBlack)
end

-- Sakura trees in round planters
local function sakuraTree(x, z, scale)
	scale = scale or 1
	local pos = CENTER + Vector3.new(x, 0, z)
	local planter = makePart(roomFolder, "Planter", Vector3.new(1.6, 9 * scale, 9 * scale), pos, Color3.fromRGB(150, 140, 130), Enum.Material.Concrete)
	planter.Shape = Enum.PartType.Cylinder
	planter.CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local trunk = makePart(roomFolder, "Trunk", Vector3.new(1.4 * scale, 9 * scale, 1.4 * scale), pos + Vector3.new(0, 4.5 * scale + 1, 0),
		Color3.fromRGB(100, 70, 60), Enum.Material.Wood)
	trunk.CFrame = trunk.CFrame * CFrame.Angles(0, 0, math.rad(cityRng:NextNumber(-6, 6)))
	for i = 1, 4 do
		local blossom = makePart(roomFolder, "Blossom", Vector3.one * (cityRng:NextNumber(6, 8.5) * scale),
			pos + Vector3.new(cityRng:NextNumber(-2.6, 2.6) * scale, (9.5 + cityRng:NextNumber(-1, 1.5)) * scale + 1, cityRng:NextNumber(-2.6, 2.6) * scale),
			SAKURA:Lerp(Color3.new(1, 1, 1), cityRng:NextNumber(0, 0.3)), Enum.Material.Grass)
		blossom.Shape = Enum.PartType.Ball
		blossom.CanCollide = i == 1
	end
	local petals = Instance.new("ParticleEmitter")
	petals.Color = ColorSequence.new(SAKURA)
	petals.Size = NumberSequence.new(0.25)
	petals.Lifetime = NumberRange.new(4, 6)
	petals.Rate = 2
	petals.Speed = NumberRange.new(0.5, 1.5)
	petals.Acceleration = Vector3.new(0.6, -1.2, 0.3)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Parent = trunk
end
for _, t in ipairs({
	-- front lawns, either side of the walkway
	{ -40, 95 }, { -75, 120 }, { -115, 92 }, { -125, 128 }, { 40, 95 }, { 75, 120 }, { 115, 92 }, { 125, 128 },
	-- the park, around the pond
	{ -128, -24 }, { -84, -26 }, { -128, 44 }, { -86, 46 },
	-- the back corners
	{ 120, -100 }, { 104, -128 },
}) do
	sakuraTree(t[1], t[2], 1)
end

-- Street lamps
local function streetLamp(x, z)
	local pos = CENTER + Vector3.new(x, 0, z)
	makePart(roomFolder, "LampPost", Vector3.new(0.6, 12, 0.6), pos + Vector3.new(0, 6, 0), Color3.fromRGB(45, 45, 55), Enum.Material.Metal)
	makePart(roomFolder, "LampArm", Vector3.new(2.4, 0.4, 0.4), pos + Vector3.new(0, 12, 0), Color3.fromRGB(45, 45, 55), Enum.Material.Metal)
	local bulb = makePart(roomFolder, "LampLight", Vector3.new(1.4, 1.4, 1.4), pos + Vector3.new(0, 12.9, 0), Color3.fromRGB(255, 232, 180), Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Range = 24
	light.Brightness = 1.2
	light.Parent = bulb
end
for _, z in ipairs({ 132, 104, 76, 50 }) do -- along the walkway
	streetLamp(-14, z)
	streetLamp(14, z)
end
for i = 1, 8 do -- around the foot of the fountain's raised plaza, leaving the paths clear
	local a = math.rad(i * 45 + 22.5)
	streetLamp(FOUNTAIN_POS.X + math.cos(a) * 40, FOUNTAIN_POS.Z + math.sin(a) * 40)
end
streetLamp(55, -6) -- by the grotto path
streetLamp(55, 22)
streetLamp(-52, -4) -- by the park path
streetLamp(-52, 24)

-- Benches, facing `facing` (a flat direction)
local function bench(x, z, facing)
	local pos = CENTER + Vector3.new(x, 0, z)
	local cf = CFrame.lookAt(pos, pos + Vector3.new(facing.X, 0, facing.Z))
	local seat = makePart(roomFolder, "BenchSeat", Vector3.new(6, 0.5, 2), pos, Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks)
	seat.CFrame = cf * CFrame.new(0, 1.8, 0)
	local back = makePart(roomFolder, "BenchBack", Vector3.new(6, 1.6, 0.4), pos, Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks)
	back.CFrame = cf * CFrame.new(0, 2.9, 0.9)
	for _, sx in ipairs({ -2.4, 2.4 }) do
		local leg = makePart(roomFolder, "BenchLeg", Vector3.new(0.4, 1.6, 1.8), pos, Color3.fromRGB(45, 45, 55), Enum.Material.Metal)
		leg.CFrame = cf * CFrame.new(sx, 0.8, 0)
	end
end
for _, z in ipairs({ 120, 90, 62 }) do -- along the walkway, facing it
	bench(-20, z, Vector3.xAxis)
	bench(20, z, -Vector3.xAxis)
end
for i = 1, 6 do -- around the pond, facing it
	local a = math.rad(i * 60)
	local x, z = POND_POS.X + math.cos(a) * 18, POND_POS.Z + math.sin(a) * 18
	bench(x - CENTER.X, z - CENTER.Z, Vector3.new(-math.cos(a), 0, -math.sin(a)))
end

-- ===== Koi pond (in the park) =====
do
	local pond = Instance.new("Folder")
	pond.Name = "KoiPond"
	pond.Parent = roomFolder
	disc(pond, "PondBed", POND_POS, 22, 0.3, 0.35, Color3.fromRGB(40, 70, 90), Enum.Material.Slate)
	arcWall(pond, "PondEdge", POND_POS, 11.4, 1, 1.4, 0.4, STONE, Enum.Material.Cobblestone, 26)
	local water = disc(pond, "PondWater", POND_POS, 22, 0.3, 0.95, Color3.fromRGB(70, 150, 200), Enum.Material.Glass)
	water.Transparency = 0.3
	water.CanCollide = false
	water.CanQuery = false
	-- koi (orange and white) and lily pads
	local koiRng = Random.new(11)
	for i = 1, 6 do
		local a = koiRng:NextNumber() * math.pi * 2
		local r = koiRng:NextNumber(2, 8)
		local koi = makePart(pond, "Koi", Vector3.new(0.6, 0.3, 1.6), POND_POS, i % 3 == 0 and Color3.fromRGB(245, 245, 240) or Color3.fromRGB(255, 120, 40), Enum.Material.SmoothPlastic)
		koi.CanCollide = false
		koi.CFrame = CFrame.new(POND_POS + Vector3.new(math.cos(a) * r, 0.75, math.sin(a) * r)) * CFrame.Angles(0, koiRng:NextNumber() * math.pi * 2, 0)
	end
	for i = 1, 5 do
		local a = i * 1.3
		local pad = disc(pond, "LilyPad", POND_POS + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7), 2.2, 0.1, 1.12, Color3.fromRGB(70, 150, 70), Enum.Material.Grass)
		pad.CanCollide = false
	end
	-- a stone lantern by the water
	local lanternPos = POND_POS + Vector3.new(0, 0, -14)
	makePart(pond, "StoneLanternBase", Vector3.new(2.4, 1, 2.4), lanternPos + Vector3.new(0, 0.9, 0), STONE_DARK, Enum.Material.Cobblestone)
	makePart(pond, "StoneLanternPost", Vector3.new(1, 3, 1), lanternPos + Vector3.new(0, 2.9, 0), STONE_DARK, Enum.Material.Cobblestone)
	local box = makePart(pond, "StoneLanternLight", Vector3.new(2, 1.6, 2), lanternPos + Vector3.new(0, 5.2, 0), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 140)
	glow.Range = 16
	glow.Parent = box
	makePart(pond, "StoneLanternRoof", Vector3.new(3.4, 0.8, 3.4), lanternPos + Vector3.new(0, 6.4, 0), STONE_DARK, Enum.Material.Cobblestone)
end

-- ===== Spawn (invisible) =====
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Size = Vector3.new(12, 0.2, 12)
spawn.Position = SPAWN_POS + Vector3.new(0, 0.5, 0)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Transparency = 1
spawn.CanCollide = false -- you land on the paving under it
spawn.CanQuery = false
spawn.CanTouch = false
spawn.Parent = lobby

-- ===== Wishing Fountain (the summon spot, the hub in the middle) =====
-- The fountain stands in the middle of a big round raised plaza (a white circle with a darker
-- rim), with steps all the way round leading up to it, each with a glowing edge. Walk up to
-- the fountain and the summon window pops up (GachaUI checks the invisible SummonAltar
-- trigger that covers the fountain's own plaza).
local FOUNTAIN_RAISE = 2.5 -- how far above the square the raised plaza is (studs)
local DAIS_STEPS = 2        -- steps up to the plaza's rim, all the way round
local PLAZA_RADIUS = 29     -- the white circle the fountain sits in
local RIM_WIDTH = 3         -- the darker rim around it
local STEP_WIDTH = 2.4      -- how deep each step is
local altarPos = FOUNTAIN_POS + Vector3.new(0, FOUNTAIN_RAISE, 0)
local fountain = Instance.new("Folder")
fountain.Name = "WishingFountain"
fountain.Parent = lobby

local WATER = Color3.fromRGB(90, 165, 255)
local MAGIC = Color3.fromRGB(170, 110, 255)
local GOLD = Color3.fromRGB(255, 205, 70)

-- The raised plaza: the steps (each a ring a little lower and wider than the one inside it),
-- the darker rim on top, and the white circle inside the rim, all from the paving (0.4) up
do
	local floorTop = 0.4
	local plazaTop = FOUNTAIN_RAISE + 0.3 -- the fountain's own plaza sits on this
	local stepHeight = (plazaTop - floorTop) / (DAIS_STEPS + 1)
	local rimRadius = PLAZA_RADIUS + RIM_WIDTH
	-- a glowing line along an edge, just on top of it
	local function edgeGlow(radius, top)
		for _, t in ipairs(arcWall(fountain, "PlazaTrim", FOUNTAIN_POS, radius - 0.15, 0.08, 0.25, top - 0.02, MAGIC, Enum.Material.Neon, 64)) do
			t.Transparency = 0.35
			t.CanCollide = false
		end
	end
	for i = 1, DAIS_STEPS do -- from the bottom step up
		local radius = rimRadius + (DAIS_STEPS - i + 1) * STEP_WIDTH
		local top = floorTop + stepHeight * i
		disc(fountain, "PlazaStep", FOUNTAIN_POS, radius * 2, top - floorTop, (floorTop + top) / 2,
			i % 2 == 1 and STONE or STONE_DARK, Enum.Material.Marble)
		edgeGlow(radius, top)
	end
	disc(fountain, "PlazaRim", FOUNTAIN_POS, rimRadius * 2, plazaTop - floorTop, (floorTop + plazaTop) / 2, STONE_DARK, Enum.Material.Slate)
	edgeGlow(rimRadius, plazaTop)
	disc(fountain, "PlazaWhite", FOUNTAIN_POS, PLAZA_RADIUS * 2, 0.1, plazaTop + 0.05, STONE, Enum.Material.Slate) -- (a hair above the rim)
end

-- A flat disc at the fountain
local function fountainDisc(name, diameter, thickness, y, color, material)
	return disc(fountain, name, altarPos, diameter, thickness, y, color, material)
end

-- A standing column
local function column(name, diameter, height, y, color, material)
	local c = makePart(fountain, name, Vector3.new(height, diameter, diameter), altarPos, color, material)
	c.Shape = Enum.PartType.Cylinder
	c.CFrame = CFrame.new(altarPos + Vector3.new(0, y + height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return c
end

-- A round wall around the fountain
local function ringWall(name, radius, height, thickness, y, color, material, segments)
	return arcWall(fountain, name, altarPos, radius, height, thickness, y, color, material, segments)
end

local function waterJet(parent, speed, rate, spread)
	local jet = Instance.new("ParticleEmitter")
	jet.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255), WATER)
	jet.LightEmission = 0.3
	jet.Transparency = NumberSequence.new(0.2, 0.8)
	jet.Size = NumberSequence.new(0.45, 0.2)
	jet.Lifetime = NumberRange.new(1, 1.3)
	jet.Speed = NumberRange.new(speed * 0.9, speed)
	jet.Acceleration = Vector3.new(0, -30, 0)
	jet.SpreadAngle = Vector2.new(spread, spread)
	jet.Rate = rate
	jet.Parent = parent
	return jet
end

-- Plaza around the fountain, with a glowing magic circle
fountainDisc("Plaza", 30, 0.3, 0.45, STONE, Enum.Material.Marble)
fountainDisc("PlazaInlay", 26, 0.32, 0.46, STONE_DARK, Enum.Material.Marble)
fountainDisc("PlazaInner", 25, 0.34, 0.47, STONE, Enum.Material.Marble)
ringWall("MagicCircle", 12.2, 0.05, 0.25, 0.64, MAGIC, Enum.Material.Neon, 40)

-- The basin: a low round wall full of water (with a few wishing coins at the bottom)
fountainDisc("BasinFloor", 16, 0.4, 0.75, Color3.fromRGB(70, 110, 170), Enum.Material.Slate)
ringWall("BasinWall", 8, 1.4, 1.1, 0.6, STONE, Enum.Material.Marble, 28)
ringWall("BasinRim", 8, 0.25, 1.5, 2.0, STONE_DARK, Enum.Material.Marble, 28)
local water = fountainDisc("Water", 15.2, 0.5, 1.3, WATER, Enum.Material.Glass)
water.Transparency = 0.35
water.CanCollide = false
water.CanQuery = false
local glow = Instance.new("PointLight")
glow.Color = MAGIC
glow.Range = 22
glow.Brightness = 1.5
glow.Parent = water
for i = 1, 10 do
	local a = i * 2.4
	local r = 3 + (i % 4) * 1.1
	local coin = makePart(fountain, "Coin", Vector3.new(0.08, 0.6, 0.6), altarPos, GOLD, Enum.Material.Metal)
	coin.Shape = Enum.PartType.Cylinder
	coin.CanCollide = false
	coin.CFrame = CFrame.new(altarPos + Vector3.new(math.cos(a) * r, 1.0, math.sin(a) * r)) * CFrame.Angles(0, a, math.rad(90))
end

-- The centre: a pillar holding a bowl, then the floating summon crystal
column("Pedestal", 3.2, 3.6, 0.9, STONE, Enum.Material.Marble)
fountainDisc("Bowl", 7, 0.6, 4.7, STONE, Enum.Material.Marble)
ringWall("BowlRim", 3.4, 0.5, 0.4, 4.8, STONE_DARK, Enum.Material.Marble, 18)
local bowlWater = fountainDisc("BowlWater", 6.4, 0.3, 5.05, WATER, Enum.Material.Glass)
bowlWater.Transparency = 0.3
bowlWater.CanCollide = false
column("Spire", 1.3, 2.2, 5.0, STONE, Enum.Material.Marble)

local crystal = makePart(fountain, "SummonCrystal", Vector3.new(1.8, 2.6, 1.8), altarPos + Vector3.new(0, 10, 0), MAGIC, Enum.Material.Neon)
crystal.CanCollide = false
local crystalLight = Instance.new("PointLight")
crystalLight.Color = Color3.fromRGB(190, 140, 255)
crystalLight.Range = 35
crystalLight.Brightness = 2
crystalLight.Parent = crystal
local sparkles = Instance.new("ParticleEmitter")
sparkles.Color = ColorSequence.new(Color3.fromRGB(230, 200, 255), MAGIC)
sparkles.LightEmission = 1
sparkles.Size = NumberSequence.new(0.35, 0)
sparkles.Lifetime = NumberRange.new(1, 2)
sparkles.Speed = NumberRange.new(1, 3)
sparkles.SpreadAngle = Vector2.new(180, 180)
sparkles.Rate = 12
sparkles.Parent = crystal

-- Water: a jet straight up from the spire, and four arcing jets from the basin wall
local topJet = makePart(fountain, "TopJet", Vector3.new(0.5, 0.5, 0.5), altarPos + Vector3.new(0, 7.3, 0), WATER)
topJet.Transparency = 1
topJet.CanCollide = false
waterJet(topJet, 11, 45, 12).EmissionDirection = Enum.NormalId.Top
for i = 1, 4 do
	local a = i * math.pi / 2 + math.pi / 4
	local from = altarPos + Vector3.new(math.cos(a) * 7.2, 2.3, math.sin(a) * 7.2)
	local nozzle = makePart(fountain, "Jet", Vector3.new(0.4, 0.4, 0.4), from, WATER)
	nozzle.Transparency = 1
	nozzle.CanCollide = false
	nozzle.CFrame = CFrame.lookAt(from, altarPos + Vector3.new(0, 9, 0))
	waterJet(nozzle, 15, 30, 4).EmissionDirection = Enum.NormalId.Front
end

-- Four lanterns around the plaza
for i = 1, 4 do
	local a = i * math.pi / 2
	local base = altarPos + Vector3.new(math.cos(a) * 13.6, 0, math.sin(a) * 13.6)
	makePart(fountain, "LanternPost", Vector3.new(0.6, 5, 0.6), base + Vector3.new(0, 3, 0), Color3.fromRGB(60, 60, 80), Enum.Material.Metal)
	local lantern = makePart(fountain, "Lantern", Vector3.new(1.2, 1.2, 1.2), base + Vector3.new(0, 6, 0), Color3.fromRGB(255, 220, 160), Enum.Material.Neon)
	lantern.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Range = 14
	light.Parent = lantern
end

-- The invisible trigger: standing anywhere on the plaza opens the summon window
marker(lobby, "SummonAltar", Vector3.new(30, 1, 30), CFrame.new(altarPos + Vector3.new(0, 0.9, 0)), MAGIC)

-- ===== Traits Cave (the trait summon spot, on the right) =====
-- A grotto: a ring of tall rocks around a crystal-lit floor under a rock roof, open at the
-- front (toward the fountain). On the front of the roof, "TRAITS" is spelled out in glowing
-- crystals. Walk inside and the trait summon window pops up (TraitCaveUI checks the
-- invisible TraitCave trigger).
local cave = Instance.new("Folder")
cave.Name = "TraitsCave"
cave.Parent = lobby

local CAVE_ROCK = Color3.fromRGB(78, 72, 92)
local CAVE_ROCK_DARK = Color3.fromRGB(52, 48, 64)
local CAVE_CRYSTALS = {
	Color3.fromRGB(80, 230, 220),
	Color3.fromRGB(170, 100, 255),
	Color3.fromRGB(255, 90, 170),
}
local CAVE_RADIUS = 17     -- the inside is a circle this big
local OPENING = 55         -- the front is open this many degrees either side of straight ahead
local FRONT_ANGLE = 180    -- straight ahead is -X (toward the fountain)

local function rock(name, size, cframe, color)
	local r = makePart(cave, name, size, cframe.Position, color or CAVE_ROCK, Enum.Material.Rock)
	r.CFrame = cframe
	return r
end

-- A glowing crystal standing at `base`, leaning by `tilt` (radians around X then Z)
local function caveCrystal(base, height, width, color, tiltX, tiltZ, lightRange)
	local c = makePart(cave, "Crystal", Vector3.new(width, height, width), base, color, Enum.Material.Neon)
	c.CanCollide = false
	c.CFrame = CFrame.new(base) * CFrame.Angles(tiltX or 0, math.rad(45), tiltZ or 0) * CFrame.new(0, height / 2, 0)
	if lightRange then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = lightRange
		light.Brightness = 1.6
		light.Parent = c
	end
	return c
end

-- the floor: dark stone with a glowing ring inlaid around the middle
disc(cave, "CaveFloor", CAVE_POS, CAVE_RADIUS * 2 + 2, 0.12, 0.47, Color3.fromRGB(40, 36, 52), Enum.Material.Slate)
arcWall(cave, "FloorRing", CAVE_POS, 9, 0.05, 0.3, 0.52, CAVE_CRYSTALS[1], Enum.Material.Neon, 36)

-- The rock ring: tall blocks leaning in a little, holding up the roof. The front is left open.
local caveRng = Random.new(7)
local ROCK_SEGMENTS = 18
for i = 1, ROCK_SEGMENTS do
	local deg = FRONT_ANGLE + OPENING + (i - 0.5) * (360 - 2 * OPENING) / ROCK_SEGMENTS
	local a = math.rad(deg)
	local height = caveRng:NextNumber(21, 23)
	local out = Vector3.new(math.cos(a), 0, math.sin(a))
	local pos = CAVE_POS + out * (CAVE_RADIUS + 2)
	local length = 2 * math.pi * (CAVE_RADIUS + 2) * ((360 - 2 * OPENING) / ROCK_SEGMENTS) / 360 + 1.5
	local face = CFrame.lookAt(pos, CAVE_POS) -- -Z toward the middle
	rock("CaveWall", Vector3.new(length, height, 4.5), face * CFrame.new(0, height / 2, 0) * CFrame.Angles(math.rad(-6), 0, 0),
		caveRng:NextNumber() < 0.5 and CAVE_ROCK or CAVE_ROCK_DARK)
	-- a boulder leaning on the outside
	local size = caveRng:NextNumber(6, 10)
	rock("Boulder", Vector3.new(size, size * 0.8, size),
		CFrame.new(CAVE_POS + out * (CAVE_RADIUS + 4.5 + size * 0.4) + Vector3.new(0, size * 0.3, 0))
			* CFrame.Angles(caveRng:NextNumber() * 0.6, caveRng:NextNumber() * math.pi, caveRng:NextNumber() * 0.6),
		caveRng:NextNumber() < 0.5 and CAVE_ROCK or CAVE_ROCK_DARK)
	-- crystals growing out of the foot of the wall
	if i % 2 == 0 then
		local color = CAVE_CRYSTALS[(i / 2) % 3 + 1]
		local foot = CAVE_POS + out * (CAVE_RADIUS - 2) + Vector3.new(0, 0.5, 0)
		caveCrystal(foot, caveRng:NextNumber(2.5, 4.5), 1, color, -out.Z * 0.35, out.X * 0.35, i % 4 == 0 and 20 or nil)
		caveCrystal(foot + Vector3.new(out.Z, 0, -out.X) * 1.4, 1.8, 0.7, color, -out.Z * 0.5, out.X * 0.5)
	end
end

-- Rock pillars framing the way in (two at the ends of the ring, two further out holding up the
-- front of the roof), with big crystals at their feet
local ROOF_Y = 20.6 -- the underside of the roof
for _, side in ipairs({ -1, 1 }) do
	local a = math.rad(FRONT_ANGLE + side * OPENING)
	local out = Vector3.new(math.cos(a), 0, math.sin(a))
	local base = CAVE_POS + out * (CAVE_RADIUS + 2)
	rock("EntrancePillar", Vector3.new(5, ROOF_Y + 0.5, 5), CFrame.new(base + Vector3.new(0, (ROOF_Y + 0.5) / 2, 0)) * CFrame.Angles(0, math.rad(20 * side), 0), CAVE_ROCK_DARK)
	caveCrystal(base + out * -3 + Vector3.new(0, 0.5, 0) + Vector3.new(-5, 0, 0), 5, 1.4, CAVE_CRYSTALS[side == 1 and 2 or 3], 0, side * 0.25, 22)
	local porchA = math.rad(FRONT_ANGLE + side * 25)
	local porch = CAVE_POS + Vector3.new(math.cos(porchA), 0, math.sin(porchA)) * (CAVE_RADIUS + 3.5)
	rock("PorchPillar", Vector3.new(4, ROOF_Y + 0.5, 4), CFrame.new(porch + Vector3.new(0, (ROOF_Y + 0.5) / 2, 0)) * CFrame.Angles(0, math.rad(35 * side), 0), CAVE_ROCK)
	caveCrystal(porch + Vector3.new(-2.5, 0.5, -side * 1.5), 3.5, 1.1, CAVE_CRYSTALS[1], 0, side * 0.3, 16)
end

-- The roof: a thick slab of rock over the whole grotto (reaching out over the way in), with
-- boulders and crystals on top
local ROOF_THICK = 3
local roofTop = ROOF_Y + ROOF_THICK
disc(cave, "Roof", CAVE_POS + Vector3.new(-1, 0, 0), (CAVE_RADIUS + 5) * 2, ROOF_THICK, ROOF_Y + ROOF_THICK / 2, CAVE_ROCK_DARK, Enum.Material.Rock)
disc(cave, "RoofTop", CAVE_POS + Vector3.new(2, 0, 0), (CAVE_RADIUS + 1) * 2, 2, roofTop + 1, CAVE_ROCK, Enum.Material.Rock)
-- a straight rock brow along the front of the roof, over the way in (the sign stands on it)
local BROW_FRONT = CAVE_POS.X - (CAVE_RADIUS + 6)
rock("RoofBrow", Vector3.new(10, ROOF_THICK, 40), CFrame.new(Vector3.new(BROW_FRONT + 5, ROOF_Y + ROOF_THICK / 2, CAVE_POS.Z)), CAVE_ROCK_DARK)
for _ = 1, 7 do
	local size = caveRng:NextNumber(6, 10)
	local spot = CAVE_POS + Vector3.new(caveRng:NextNumber(-2, 14), roofTop + 2 + size * 0.2, caveRng:NextNumber(-14, 14))
	rock("RoofBoulder", Vector3.new(size, size * 0.7, size),
		CFrame.new(spot) * CFrame.Angles(caveRng:NextNumber() * 0.4, caveRng:NextNumber() * math.pi, caveRng:NextNumber() * 0.4),
		caveRng:NextNumber() < 0.5 and CAVE_ROCK or CAVE_ROCK_DARK)
end

-- "TRAITS" in glowing crystals on a slab of rock standing on the roof's brow, facing
-- the fountain. Each letter is drawn on a 5 x 7 grid ("#" = a crystal), in turn teal, purple
-- and pink. Reading it from the fountain, the letters run along +Z.
do
	local LETTERS = {
		T = { "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.." },
		R = { "####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#" },
		A = { ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" },
		I = { "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####" },
		S = { ".####", "#....", "#....", ".###.", "....#", "....#", "####." },
	}
	local WORD = "TRAITS"
	local PITCH = 0.95 -- studs from one crystal to the next
	local columns = #WORD * 6 - 1
	local slabCenter = Vector3.new(BROW_FRONT + 2.5, roofTop + 4.5, CAVE_POS.Z)
	rock("TraitsSign", Vector3.new(3, 9, columns * PITCH + 3), CFrame.new(slabCenter), CAVE_ROCK_DARK)
	local faceX = slabCenter.X - 1.5 - 0.15 -- just in front of the slab's front face
	for li = 1, #WORD do
		local color = CAVE_CRYSTALS[(li - 1) % 3 + 1]
		local glyph = LETTERS[string.sub(WORD, li, li)]
		for row = 1, 7 do
			for col = 1, 5 do
				if string.sub(glyph[row], col, col) == "#" then
					local c = (li - 1) * 6 + col -- 1..columns, left to right as you read it
					local spot = Vector3.new(faceX, slabCenter.Y + (4 - row) * PITCH, slabCenter.Z + (c - (columns + 1) / 2) * PITCH)
					local gem = makePart(cave, "LetterCrystal", Vector3.new(0.5, 0.8, 0.8), spot, color, Enum.Material.Neon)
					gem.CanCollide = false
					gem.CFrame = CFrame.new(spot) * CFrame.Angles(math.rad(45), 0, 0) -- a diamond, as seen from the front
				end
			end
		end
		-- each letter lights up the rock around it
		local glowPart = marker(cave, "LetterGlow", Vector3.new(1, 1, 1),
			CFrame.new(Vector3.new(faceX - 3, slabCenter.Y, slabCenter.Z + ((li - 1) * 6 + 3 - (columns + 1) / 2) * PITCH)))
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = glowPart
	end
	-- crystal clusters at both ends of the sign
	for _, side in ipairs({ -1, 1 }) do
		local foot = Vector3.new(slabCenter.X, roofTop, slabCenter.Z + side * (columns * PITCH / 2 + 2.5))
		caveCrystal(foot, 6, 1.4, CAVE_CRYSTALS[2], 0, -side * 0.25, 18)
		caveCrystal(foot + Vector3.new(0, 0, side * 1.6), 3.5, 1, CAVE_CRYSTALS[1], 0, -side * 0.45)
	end
end

-- Crystals: a big cluster on a rock in the middle, and the floating trait crystal over it
local clusterPos = CAVE_POS + Vector3.new(3, 0.5, 0)
rock("Pedestal", Vector3.new(7, 2, 7), CFrame.new(clusterPos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(20), 0), CAVE_ROCK_DARK)
for i = 1, 6 do
	local a = i / 6 * math.pi * 2
	caveCrystal(clusterPos + Vector3.new(math.cos(a) * 2, 2, math.sin(a) * 2), 3 + (i % 3), 1.1,
		CAVE_CRYSTALS[i % 3 + 1], math.sin(a) * 0.45, -math.cos(a) * 0.45)
end
local traitCrystal = makePart(cave, "TraitCrystal", Vector3.new(2.2, 3.2, 2.2), clusterPos + Vector3.new(0, 9, 0), CAVE_CRYSTALS[1], Enum.Material.Neon)
traitCrystal.CanCollide = false
local traitLight = Instance.new("PointLight")
traitLight.Color = CAVE_CRYSTALS[1]
traitLight.Range = 30
traitLight.Brightness = 2
traitLight.Parent = traitCrystal
local traitSparkles = Instance.new("ParticleEmitter")
traitSparkles.Color = ColorSequence.new(CAVE_CRYSTALS[1], CAVE_CRYSTALS[2])
traitSparkles.LightEmission = 1
traitSparkles.Size = NumberSequence.new(0.35, 0)
traitSparkles.Lifetime = NumberRange.new(1, 2)
traitSparkles.Speed = NumberRange.new(1, 3)
traitSparkles.SpreadAngle = Vector2.new(180, 180)
traitSparkles.Rate = 14
traitSparkles.Parent = traitCrystal
-- motes of light drifting up from the floor
local motes = marker(cave, "Motes", Vector3.new(CAVE_RADIUS * 1.6, 1, CAVE_RADIUS * 1.6), CFrame.new(CAVE_POS + Vector3.new(0, 1, 0)))
local moteEmitter = Instance.new("ParticleEmitter")
moteEmitter.Color = ColorSequence.new(CAVE_CRYSTALS[1], CAVE_CRYSTALS[2])
moteEmitter.LightEmission = 1
moteEmitter.Size = NumberSequence.new(0.25, 0)
moteEmitter.Lifetime = NumberRange.new(3, 4.5) -- (they fade before reaching the roof)
moteEmitter.Speed = NumberRange.new(1.5, 3)
moteEmitter.EmissionDirection = Enum.NormalId.Top
moteEmitter.SpreadAngle = Vector2.new(15, 15)
moteEmitter.Rate = 8
moteEmitter.Parent = motes

-- The invisible trigger: standing anywhere inside the grotto opens the trait summon window
marker(lobby, "TraitCave", Vector3.new(CAVE_RADIUS * 2 - 4, 1, CAVE_RADIUS * 2 - 4), CFrame.new(CAVE_POS + Vector3.new(0, 0.9, 0)), CAVE_CRYSTALS[1])

-- ===== Five team gates (in an arc behind the fountain) =====
-- Each one: a round platform to stand on with a glowing ring and light rising off it, a gate
-- in the team's color behind it, and the team's sign hanging in the gate. Pad1..Pad5 are
-- invisible flat parts over the platforms that mark where to stand (GameService and
-- LevelSelectUI check them; they're colored like the team).
local GATE_DARK = Color3.fromRGB(38, 38, 56)
local gateEmblems = {}
for i = 1, NUM_PADS do
	local color = TEAM_COLORS[i]
	local deg = (i - (NUM_PADS + 1) / 2) * 30 -- -60, -30, 0, 30, 60
	local a = math.rad(deg)
	local pos = GATES_CENTER + Vector3.new(math.sin(a) * GATES_RADIUS, 0, -math.cos(a) * GATES_RADIUS)
	-- -Z faces the middle of the arc (toward the fountain), +Z is behind the platform
	local base = CFrame.lookAt(pos, Vector3.new(GATES_CENTER.X, pos.Y, GATES_CENTER.Z))

	-- the platform: a dark stone base, a lighter top, a glowing ring and a glowing emblem
	disc(padsFolder, "PadBase" .. i, pos, 22, 0.6, 0.7, Color3.fromRGB(52, 50, 66), Enum.Material.Slate)
	disc(padsFolder, "PadTop" .. i, pos, 19, 0.2, 1.05, color:Lerp(Color3.new(0, 0, 0), 0.55), Enum.Material.Marble)
	arcWall(padsFolder, "PadRing" .. i, pos, 9.8, 0.12, 0.5, 1.0, color, Enum.Material.Neon, 32)
	local emblem = disc(padsFolder, "PadEmblem" .. i, pos, 6, 0.06, 1.17, color, Enum.Material.Neon)
	emblem.Transparency = 0.25
	emblem.CanCollide = false

	-- light rising off the platform
	local riser = marker(padsFolder, "PadLight" .. i, Vector3.new(16, 0.2, 16), base * CFrame.new(0, 1.3, 0), color)
	local rise = Instance.new("ParticleEmitter")
	rise.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color)
	rise.LightEmission = 1
	rise.Transparency = NumberSequence.new(0.2, 1)
	rise.Size = NumberSequence.new(0.45, 0)
	rise.Lifetime = NumberRange.new(1.5, 2.5)
	rise.Speed = NumberRange.new(3, 5)
	rise.EmissionDirection = Enum.NormalId.Top
	rise.SpreadAngle = Vector2.new(5, 5)
	rise.Rate = 14
	rise.Parent = riser
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = riser

	-- where to stand (what GameService and LevelSelectUI check)
	marker(padsFolder, "Pad" .. i, Vector3.new(18, 0.4, 18), base * CFrame.new(0, 1.3, 0), color)

	-- the gate: two pillars with glowing strips, a beam across the top, and a spinning
	-- emblem over it
	for _, sx in ipairs({ -1, 1 }) do
		local pillar = makePart(padsFolder, "GatePillar" .. i, Vector3.new(2.4, 21, 2.4), pos, GATE_DARK, Enum.Material.Metal)
		pillar.CFrame = base * CFrame.new(sx * 12, 10.5, 9)
		local strip = makePart(padsFolder, "GateStrip" .. i, Vector3.new(0.5, 19, 0.3), pos, color, Enum.Material.Neon)
		strip.CanCollide = false
		strip.CFrame = base * CFrame.new(sx * 12, 10.5, 9 - 1.3)
		local foot = makePart(padsFolder, "GateFoot" .. i, Vector3.new(3.6, 1.2, 3.6), pos, GATE_DARK, Enum.Material.Metal)
		foot.CFrame = base * CFrame.new(sx * 12, 0.9, 9)
	end
	local beam = makePart(padsFolder, "GateBeam" .. i, Vector3.new(29, 2.4, 3), pos, GATE_DARK, Enum.Material.Metal)
	beam.CFrame = base * CFrame.new(0, 22, 9)
	local beamStrip = makePart(padsFolder, "GateBeamStrip" .. i, Vector3.new(27, 0.4, 0.3), pos, color, Enum.Material.Neon)
	beamStrip.CanCollide = false
	beamStrip.CFrame = base * CFrame.new(0, 20.6, 9 - 1.55)
	local gem = makePart(padsFolder, "GateEmblem" .. i, Vector3.new(2.6, 2.6, 2.6), pos, color, Enum.Material.Neon)
	gem.CanCollide = false
	gem.CFrame = base * CFrame.new(0, 25.5, 9)
	table.insert(gateEmblems, { Part = gem, Home = gem.Position, Phase = i })

	-- the team's sign hanging in the gate, facing the middle (the panel's +Z toward it)
	local signCf = base * CFrame.new(0, 15, 9) * CFrame.Angles(0, math.pi, 0)
	signPanel(padsFolder, "Sign" .. i, signCf, Vector3.new(20, 8, 0.6), color,
		string.format("Step here to queue\n0/%d", MAX_PLAYERS))
	for _, sx in ipairs({ -1, 1 }) do -- the chains it hangs from
		local chain = makePart(padsFolder, "SignChain" .. i, Vector3.new(0.25, 2, 0.25), pos, Color3.fromRGB(150, 150, 165), Enum.Material.Metal)
		chain.CanCollide = false
		chain.CFrame = base * CFrame.new(sx * 8, 19.9, 9)
	end
end

-- ===== Damage Challenge (back left corner) =====
-- A red gate like the team gates, with a round platform: stand on it to play the solo
-- Damage Challenge (GameService runs it). Beside it, a board shows the best scores
-- (ChallengeScores fills it in). Lobby.ChallengePad marks where to stand,
-- Lobby.ChallengeSign shows the queue, Lobby.ChallengeBoard is the leaderboard.
do
	local RED = Color3.fromRGB(235, 50, 70)
	local DARK_RED = Color3.fromRGB(70, 20, 30)
	local challenge = Instance.new("Folder")
	challenge.Name = "DamageChallenge"
	challenge.Parent = lobby
	local pos = CHALLENGE_POS
	-- -Z faces the middle of the gates' arc, +Z is behind the platform
	local base = CFrame.lookAt(pos, Vector3.new(GATES_CENTER.X, pos.Y, GATES_CENTER.Z))

	-- a dark stone square under it all, with a red edge
	disc(challenge, "ChallengePlaza", pos + base.LookVector * 6, 56, 0.1, 0.48, Color3.fromRGB(46, 40, 52), Enum.Material.Slate)
	for _, t in ipairs(arcWall(challenge, "ChallengePlazaEdge", pos + base.LookVector * 6, 27.8, 0.08, 0.3, 0.52, RED, Enum.Material.Neon, 64)) do
		t.Transparency = 0.3
		t.CanCollide = false
	end

	-- the platform, like a team gate's but red
	disc(challenge, "ChallengePadBase", pos, 22, 0.6, 0.7, Color3.fromRGB(52, 44, 56), Enum.Material.Slate)
	disc(challenge, "ChallengePadTop", pos, 19, 0.2, 1.05, DARK_RED, Enum.Material.Marble)
	arcWall(challenge, "ChallengePadRing", pos, 9.8, 0.12, 0.5, 1.0, RED, Enum.Material.Neon, 32)
	local emblem = disc(challenge, "ChallengeEmblem", pos, 6, 0.06, 1.17, RED, Enum.Material.Neon)
	emblem.Transparency = 0.25
	emblem.CanCollide = false
	local riser = marker(challenge, "ChallengeLight", Vector3.new(16, 0.2, 16), base * CFrame.new(0, 1.3, 0), RED)
	local rise = Instance.new("ParticleEmitter")
	rise.Color = ColorSequence.new(Color3.fromRGB(255, 140, 120), RED)
	rise.LightEmission = 1
	rise.Transparency = NumberSequence.new(0.2, 1)
	rise.Size = NumberSequence.new(0.45, 0)
	rise.Lifetime = NumberRange.new(1.5, 2.5)
	rise.Speed = NumberRange.new(3, 5)
	rise.EmissionDirection = Enum.NormalId.Top
	rise.SpreadAngle = Vector2.new(5, 5)
	rise.Rate = 14
	rise.Parent = riser
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = riser
	marker(lobby, "ChallengePad", Vector3.new(18, 0.4, 18), base * CFrame.new(0, 1.3, 0), RED)

	-- the gate, its spinning emblem, and the sign hanging in it
	for _, sx in ipairs({ -1, 1 }) do
		local pillar = makePart(challenge, "ChallengePillar", Vector3.new(2.4, 21, 2.4), pos, GATE_DARK, Enum.Material.Metal)
		pillar.CFrame = base * CFrame.new(sx * 12, 10.5, 9)
		local strip = makePart(challenge, "ChallengeStrip", Vector3.new(0.5, 19, 0.3), pos, RED, Enum.Material.Neon)
		strip.CanCollide = false
		strip.CFrame = base * CFrame.new(sx * 12, 10.5, 9 - 1.3)
		local foot = makePart(challenge, "ChallengeFoot", Vector3.new(3.6, 1.2, 3.6), pos, GATE_DARK, Enum.Material.Metal)
		foot.CFrame = base * CFrame.new(sx * 12, 0.9, 9)
		local chain = makePart(challenge, "ChallengeChain", Vector3.new(0.25, 2, 0.25), pos, Color3.fromRGB(150, 150, 165), Enum.Material.Metal)
		chain.CanCollide = false
		chain.CFrame = base * CFrame.new(sx * 8, 19.9, 9)
	end
	local beam = makePart(challenge, "ChallengeBeam", Vector3.new(29, 2.4, 3), pos, GATE_DARK, Enum.Material.Metal)
	beam.CFrame = base * CFrame.new(0, 22, 9)
	local beamStrip = makePart(challenge, "ChallengeBeamStrip", Vector3.new(27, 0.4, 0.3), pos, RED, Enum.Material.Neon)
	beamStrip.CanCollide = false
	beamStrip.CFrame = base * CFrame.new(0, 20.6, 9 - 1.55)
	local gem = makePart(challenge, "ChallengeGem", Vector3.new(2.6, 2.6, 2.6), pos, RED, Enum.Material.Neon)
	gem.CanCollide = false
	gem.CFrame = base * CFrame.new(0, 25.5, 9)
	table.insert(gateEmblems, { Part = gem, Home = gem.Position, Phase = 9 })
	signPanel(lobby, "ChallengeSign", base * CFrame.new(0, 15, 9) * CFrame.Angles(0, math.pi, 0), Vector3.new(20, 8, 0.6), RED,
		"SOLO DAMAGE CHALLENGE\nStep here to start")

	-- the leaderboard: a tall board beside the gate, facing the same way
	local boardSize = Vector3.new(18, 22, 0.6)
	local boardCf = base * CFrame.new(24, 1.6 + boardSize.Y / 2, 6) * CFrame.Angles(0, math.pi, 0)
	local board = makePart(lobby, "ChallengeBoard", boardSize, pos, Color3.fromRGB(24, 22, 36))
	board.CFrame = boardCf
	for _, sx in ipairs({ -1, 1 }) do
		local leg = makePart(challenge, "BoardLeg", Vector3.new(1.2, 1.8, 1.2), pos, GATE_DARK, Enum.Material.Metal)
		leg.CFrame = boardCf * CFrame.new(sx * 7, -boardSize.Y / 2 - 0.5, 0)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(360, 440) -- the board's shape
	gui.LightInfluence = 0
	gui.Parent = board
	local outline = Instance.new("Frame")
	outline.Size = UDim2.fromScale(1, 1)
	outline.BackgroundTransparency = 1
	outline.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Color = RED
	edge.Thickness = 6
	edge.Parent = outline
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundColor3 = RED
	header.BorderSizePixel = 0
	header.Text = "TOP DAMAGE"
	header.TextColor3 = Color3.new(1, 1, 1)
	header.Font = Enum.Font.GothamBlack
	header.TextSize = 38
	header.Parent = gui
	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.Position = UDim2.fromOffset(14, 72 + (i - 1) * 33)
		row.Size = UDim2.new(1, -28, 0, 30)
		row.BackgroundColor3 = i % 2 == 1 and Color3.fromRGB(40, 34, 52) or Color3.fromRGB(32, 28, 44)
		row.BorderSizePixel = 0
		row.Parent = gui
		local rank = Instance.new("TextLabel")
		rank.Name = "PlayerName"
		rank.Position = UDim2.fromOffset(8, 0)
		rank.Size = UDim2.new(0.62, -8, 1, 0)
		rank.BackgroundTransparency = 1
		rank.Text = i .. ". -"
		rank.TextColor3 = i == 1 and Color3.fromRGB(255, 210, 80) or (i <= 3 and Color3.fromRGB(220, 220, 235) or Color3.fromRGB(190, 185, 210))
		rank.Font = Enum.Font.GothamBold
		rank.TextSize = 18
		rank.TextXAlignment = Enum.TextXAlignment.Left
		rank.TextTruncate = Enum.TextTruncate.AtEnd
		rank.Parent = row
		local score = Instance.new("TextLabel")
		score.Name = "Score"
		score.Position = UDim2.new(0.62, 0, 0, 0)
		score.Size = UDim2.new(0.38, -8, 1, 0)
		score.BackgroundTransparency = 1
		score.Text = ""
		score.TextColor3 = Color3.fromRGB(255, 150, 140)
		score.Font = Enum.Font.GothamBlack
		score.TextSize = 18
		score.TextXAlignment = Enum.TextXAlignment.Right
		score.Parent = row
	end
	local note = Instance.new("TextLabel")
	note.Name = "Note"
	note.Position = UDim2.new(0, 10, 1, -34)
	note.Size = UDim2.new(1, -20, 0, 26)
	note.BackgroundTransparency = 1
	note.Text = "Loading..."
	note.TextColor3 = Color3.fromRGB(160, 155, 180)
	note.Font = Enum.Font.Gotham
	note.TextSize = 14
	note.TextWrapped = true
	note.Parent = gui
end

-- ===== Moving bits: the summon crystal, the trait crystal and the gate emblems =====
local spinTime = 0
RunService.Heartbeat:Connect(function(dt)
	spinTime += dt
	crystal.CFrame = CFrame.new(altarPos + Vector3.new(0, 10 + math.sin(spinTime * 1.5) * 0.5, 0))
		* CFrame.Angles(0, spinTime * 0.8, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	traitCrystal.CFrame = CFrame.new(clusterPos + Vector3.new(0, 9 + math.sin(spinTime * 1.2) * 0.5, 0))
		* CFrame.Angles(0, -spinTime * 0.9, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	for _, g in ipairs(gateEmblems) do
		g.Part.CFrame = CFrame.new(g.Home + Vector3.new(0, math.sin(spinTime * 1.4 + g.Phase) * 0.4, 0))
			* CFrame.Angles(0, spinTime * 1.1 + g.Phase, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	end
end)

-- ===== Teleport spots =====
-- Where the Teleport menu (LobbyTeleportUI) puts you: an invisible marker standing in front of
-- each place, facing it. Label = its name in the menu, Order = its place in the list.
do
	local spots = Instance.new("Folder")
	spots.Name = "TeleportSpots"
	spots.Parent = lobby
	local function teleportSpot(order, label, color, standAt, lookAt)
		local cf = CFrame.lookAt(standAt, Vector3.new(lookAt.X, standAt.Y, lookAt.Z))
		local spot = marker(spots, label, Vector3.new(4, 1, 4), cf, color)
		spot:SetAttribute("Label", label)
		spot:SetAttribute("Order", order)
	end
	local up = Vector3.new(0, 0.5, 0)
	teleportSpot(1, "Spawn", Color3.fromRGB(205, 45, 40), SPAWN_POS + up, FOUNTAIN_POS)
	teleportSpot(2, "Wishing Fountain", MAGIC, FOUNTAIN_POS + Vector3.new(0, 0, 39) + up, FOUNTAIN_POS) -- at the foot of the steps
	teleportSpot(3, "Team Gates", Color3.fromRGB(110, 200, 255), GATES_CENTER + Vector3.new(0, 0, -20) + up,
		GATES_CENTER + Vector3.new(0, 0, -GATES_RADIUS))
	teleportSpot(4, "Traits Cave", CAVE_CRYSTALS[1], CAVE_POS + Vector3.new(-32, 0, 0) + up, CAVE_POS)
	teleportSpot(5, "Koi Pond", Color3.fromRGB(110, 200, 120), POND_POS + Vector3.new(26, 0, 0) + up, POND_POS)
	do -- in front of the Challenge gate, facing it
		local toward = Vector3.new(GATES_CENTER.X - CHALLENGE_POS.X, 0, GATES_CENTER.Z - CHALLENGE_POS.Z).Unit
		teleportSpot(6, "Damage Challenge", Color3.fromRGB(235, 50, 70), CHALLENGE_POS + toward * 20 + up, CHALLENGE_POS)
	end
end

-- ===== Night sky =====
-- Lighting is shared by the whole server (lobby and arenas). The lobby is night; matches stay
-- in daylight. The original daylight settings and the night settings are both stored on
-- Lighting as attributes ("Day_ClockTime", "Night_ClockTime", ...), and PlacementUI switches
-- each player's own lighting between them as they go in and out of matches.
do
	local Lighting = game:GetService("Lighting")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0
		atmosphere.Parent = Lighting
	end
	local NIGHT = {
		ClockTime = 0.2,
		Brightness = 1.8, -- (moonlight)
		Ambient = Color3.fromRGB(44, 46, 78),
		OutdoorAmbient = Color3.fromRGB(80, 88, 136),
		ExposureCompensation = 0.25,
		EnvironmentDiffuseScale = 0.4,
		EnvironmentSpecularScale = 0.6,
	}
	for prop, nightValue in pairs(NIGHT) do
		Lighting:SetAttribute("Day_" .. prop, Lighting[prop])
		Lighting:SetAttribute("Night_" .. prop, nightValue)
		Lighting[prop] = nightValue
	end
	-- a light blue night haze that softens the distant skyline and lightens the sky (none
	-- during the day). Lighter Color / Decay = a brighter sky.
	Lighting:SetAttribute("Day_AtmosphereDensity", atmosphere.Density)
	Lighting:SetAttribute("Night_AtmosphereDensity", 0.3)
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(100, 116, 182)
	atmosphere.Decay = Color3.fromRGB(56, 62, 112)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2

	-- glow on neon and lit windows, and a little extra color everywhere
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.5 -- (softer glow, so neon and lamps don't blaze)
	bloom.Size = 24
	bloom.Threshold = 1.6
	if not Lighting:FindFirstChild("LobbyColor") then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "LobbyColor"
		grade.Saturation = 0.18
		grade.Contrast = 0.06
		grade.Parent = Lighting
	end
end

-- Every lamp, lantern and crystal light in the lobby shines at this fraction of the brightness
-- it was built with (1 = full). Lower it for softer lights.
local LIGHT_LEVEL = 0.6
for _, d in ipairs(lobby:GetDescendants()) do
	if d:IsA("Light") then
		d.Brightness *= LIGHT_LEVEL
	end
end

lobby.Parent = workspace

-- Everyone should spawn in the lobby, and no spawn pad should show: switch off and hide any
-- other spawn (like the one a new place starts with)
for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("SpawnLocation") and inst ~= spawn then
		inst.Enabled = false
		inst.Transparency = 1
		inst.CanCollide = false
		inst.CanQuery = false
		inst.CanTouch = false
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			end
		end
	end
end
