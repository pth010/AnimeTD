-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: LobbyBuilder
-- (replaces the earlier version: does nothing in the match place, see PlaceConfig)
-- Builds the lobby at runtime:
--   * a 240 x 240 stud city square under the open sky: tiled paving, a red-brick walkway,
--     sakura trees, street lamps and benches
--   * a ring of buildings closing it in (shops with awnings and neon signs, lit windows,
--     rooftop props), a station building behind the team pads, a torii gate behind the
--     spawn, corner towers and a skyline of taller towers further back
--   * green lawns in the open areas of the square
--   * a night sky with stars, moonlight, a light night haze and bloom so the lit windows,
--     neon signs and lamps glow. Lighting is shared by the whole server, so the day and night
--     settings are stored on Lighting as attributes and each player's screen switches to day
--     during a match (see PlacementUI)
--   * invisible walls at the edge of the square so nobody wanders off
--   * the default Baseplate is hidden (made invisible and not solid): the lobby has its own
--     ground, and a ring of distant buildings closes off the view outside the city
--   * the player spawn near the front (torii) side
--   * the Wishing Fountain (walk up to it and the summon window pops up) with its own sign
--   * the Traits Cave across from it, sunk underground: a ramp leads down into it from an
--     opening in the square (walk inside and the trait summon window pops up)
--   * FIVE team queue pads in front of the station, each with a standing sign board that
--     shows the team name and the live queue status
-- Assumes the default 512x512 Baseplate (the square is centered on the origin).
-- If Workspace.Lobby already exists (you built your own), this script does nothing.
-- A custom lobby needs: Lobby.LobbySpawn, Lobby.SummonAltar (a flat part marking the summon
-- area), Lobby.TraitCave (a flat part marking the trait summon area), and Lobby.QueuePads
-- containing Pad1..Pad5 (the parts to stand on) and Sign1..Sign5 (parts holding a
-- SurfaceGui named QueueGui with a TextLabel named Label inside).

if workspace:FindFirstChild("Lobby") then return end
if require(game:GetService("ReplicatedStorage"):WaitForChild("PlaceConfig")).IsMatchPlace() then return end

local CENTER = Vector3.new(0, 0, 0)
local SIZE = 240   -- the city square is SIZE x SIZE studs
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

-- A standing sign board: two posts and a panel. The text is printed on the panel's face and
-- never moves or turns with the camera.
--   facing: the direction the text faces (a world vector, only its flat X/Z part is used).
--           Leave it nil to face +Z, toward the front of the room.
--   boardY: height of the panel's center (default 11)
-- Returns the panel and the body TextLabel.
local function makeSignBoard(parent, name, position, accent, title, body, facing, boardY)
	local boardSize = Vector3.new(26, 14, 1)
	boardY = boardY or 11

	-- The text sits on the part's Back face, so turn the board until Back points along `facing`
	local base = CFrame.new(position)
	if facing then
		local flat = Vector3.new(facing.X, 0, facing.Z)
		if flat.Magnitude > 0.001 then
			base = CFrame.lookAt(position, position - flat.Unit)
		end
	end

	local postHeight = boardY - 7 - 0.4 -- from the floor up to the panel's bottom edge
	for _, dx in ipairs({ -10, 10 }) do
		local post = makePart(parent, name .. "Post", Vector3.new(1.4, postHeight, 1.4), position, Color3.fromRGB(60, 60, 80))
		post.CFrame = base * CFrame.new(dx, 0.4 + postHeight / 2, 0)
	end

	local board = makePart(parent, name, boardSize, position, Color3.fromRGB(28, 28, 44))
	board.CFrame = base * CFrame.new(0, boardY, 0)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "QueueGui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(520, 280) -- same shape as the 26 x 14 board
	gui.LightInfluence = 0
	gui.Parent = board

	local header = Instance.new("Frame")
	header.Size = UDim2.fromScale(1, 0.34)
	header.BackgroundColor3 = accent
	header.BorderSizePixel = 0
	header.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.4
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.Parent = header
	local titlePad = Instance.new("UIPadding")
	titlePad.PaddingTop = UDim.new(0, 8)
	titlePad.PaddingBottom = UDim.new(0, 8)
	titlePad.Parent = titleLabel

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Position = UDim2.fromScale(0, 0.34)
	label.Size = UDim2.fromScale(1, 0.66)
	label.BackgroundTransparency = 1
	label.Text = body
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingTop = UDim.new(0, 14)
	bodyPad.PaddingBottom = UDim.new(0, 14)
	bodyPad.PaddingLeft = UDim.new(0, 16)
	bodyPad.PaddingRight = UDim.new(0, 16)
	bodyPad.Parent = label

	return board, label
end

-- ===== The city square =====
-- Everything is built from a fixed random seed, so the city looks the same every time.
local cityRng = Random.new(2024)
local EDGE = half          -- the square runs from -EDGE to +EDGE on X and Z
local STREET = EDGE + 4    -- the buildings' front faces stand here

local PAVING = Color3.fromRGB(122, 116, 134)
local PAVING_DARK = Color3.fromRGB(94, 88, 110)
local BRICK = Color3.fromRGB(150, 52, 44)
local GRASS = Color3.fromRGB(58, 132, 58)
local SAKURA = Color3.fromRGB(255, 183, 213)

-- The opening in the paving where the ramp goes down into the underground Traits Cave
-- (see the Traits Cave section further down)
local CAVE_OPENING = { X0 = 31.5, X1 = 68.5, Z0 = 48.5, Z1 = 61.5 }
local function overlapsOpening(x0, x1, z0, z1)
	return x1 > CAVE_OPENING.X0 and x0 < CAVE_OPENING.X1 and z1 > CAVE_OPENING.Z0 and z0 < CAVE_OPENING.Z1
end

-- The default Baseplate would block the underground cave and shows as flat grey ground past
-- the city, so hide it (it stays in the place, just invisible and not solid)
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

-- Paving (in four pieces around the cave opening), with a big two-tone tile pattern
local function floorPiece(x0, x1, z0, z1)
	makePart(roomFolder, "Floor", Vector3.new(x1 - x0, 0.4, z1 - z0), CENTER + Vector3.new((x0 + x1) / 2, 0.2, (z0 + z1) / 2), PAVING, Enum.Material.Slate)
end
floorPiece(-EDGE, CAVE_OPENING.X0, -EDGE, EDGE)
floorPiece(CAVE_OPENING.X1, EDGE, -EDGE, EDGE)
floorPiece(CAVE_OPENING.X0, CAVE_OPENING.X1, CAVE_OPENING.Z1, EDGE)
floorPiece(CAVE_OPENING.X0, CAVE_OPENING.X1, -EDGE, CAVE_OPENING.Z0)

-- Street ground under the buildings around the square (the city's own ground, since the
-- Baseplate is hidden)
local GROUND_OUT = 176
for _, g in ipairs({
	{ Vector3.new(GROUND_OUT * 2, 1, GROUND_OUT - EDGE), Vector3.new(0, -0.5, (GROUND_OUT + EDGE) / 2) },
	{ Vector3.new(GROUND_OUT * 2, 1, GROUND_OUT - EDGE), Vector3.new(0, -0.5, -(GROUND_OUT + EDGE) / 2) },
	{ Vector3.new(GROUND_OUT - EDGE, 1, SIZE), Vector3.new((GROUND_OUT + EDGE) / 2, -0.5, 0) },
	{ Vector3.new(GROUND_OUT - EDGE, 1, SIZE), Vector3.new(-(GROUND_OUT + EDGE) / 2, -0.5, 0) },
}) do
	makePart(roomFolder, "Street", g[1], CENTER + g[2], Color3.fromRGB(60, 60, 68), Enum.Material.Asphalt)
end
local TILE = 24
for ix = 0, SIZE / TILE - 1 do
	for iz = 0, SIZE / TILE - 1 do
		local tx0, tz0 = -EDGE + TILE * ix, -EDGE + TILE * iz
		if (ix + iz) % 2 == 0 and not overlapsOpening(tx0, tx0 + TILE, tz0, tz0 + TILE) then
			local tile = makePart(roomFolder, "Tile", Vector3.new(TILE, 0.05, TILE),
				CENTER + Vector3.new(-EDGE + TILE * (ix + 0.5), 0.425, -EDGE + TILE * (iz + 0.5)), PAVING_DARK, Enum.Material.Slate)
			tile.CanCollide = false
		end
	end
end
-- red-brick walkway from the spawn to the pads, and a cross path to the fountain and the cave
makePart(roomFolder, "Walkway", Vector3.new(24, 0.1, 170), CENTER + Vector3.new(0, 0.5, 5), BRICK, Enum.Material.Brick)
-- (it stops short of the cave opening on the right)
makePart(roomFolder, "CrossPath", Vector3.new(98, 0.1, 14), CENTER + Vector3.new(-21, 0.47, 58), BRICK, Enum.Material.Brick)
-- a lighter sidewalk band around the edge
for _, side in ipairs({ { Vector3.new(SIZE, 0.1, 8), Vector3.new(0, 0, EDGE - 4) }, { Vector3.new(SIZE, 0.1, 8), Vector3.new(0, 0, -EDGE + 4) },
	{ Vector3.new(8, 0.1, SIZE - 16), Vector3.new(EDGE - 4, 0, 0) }, { Vector3.new(8, 0.1, SIZE - 16), Vector3.new(-EDGE + 4, 0, 0) } }) do
	makePart(roomFolder, "Sidewalk", side[1], CENTER + side[2] + Vector3.new(0, 0.48, 0), Color3.fromRGB(150, 145, 162), Enum.Material.Concrete)
end

-- Green lawns in the open areas of the square (clear of the walkway, fountain, cave, pads
-- and spawn), each with a low stone edge
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
lawn(-112, -26, -50, 38)  -- back left (between the pads and the fountain)
lawn(26, 112, -50, 36)    -- back right (between the pads and the cave)
lawn(-112, -26, 80, 112)  -- front left (beside the spawn)
lawn(26, 112, 94, 112)    -- front right (beside the spawn, past the cave sign)

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
			local height = cityRng:NextInteger(26, 64)
			building(origin + along * (pos + width / 2), facing, width - 0.6, depth or 30, height)
			pos += width
		end
	end
end

-- back side (behind the pads): the station in the middle, shops either side
local STATION_W = 190 -- wide enough for all five team banners (pads at x = -80 .. 80)
local station = building(CENTER + Vector3.new(0, 0, -STREET), Vector3.zAxis, STATION_W, 34, 46,
	{ Shop = false, Vertical = false, Color = Color3.fromRGB(34, 38, 74) })
station.Name = "Station"
buildingRow(CENTER + Vector3.new(0, 0, -STREET), Vector3.xAxis, Vector3.zAxis, -EDGE - 8, EDGE + 8, { { -STATION_W / 2, STATION_W / 2 } })
-- front side (behind the spawn): a gap for the torii gate in the middle
buildingRow(CENTER + Vector3.new(0, 0, STREET), Vector3.xAxis, -Vector3.zAxis, -EDGE - 8, EDGE + 8, { { -18, 18 } })
-- left and right sides
buildingRow(CENTER + Vector3.new(-STREET, 0, 0), Vector3.zAxis, Vector3.xAxis, -EDGE + 8, EDGE - 8)
buildingRow(CENTER + Vector3.new(STREET, 0, 0), Vector3.zAxis, -Vector3.xAxis, -EDGE + 8, EDGE - 8)

-- tall towers in the four corners
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local corner = CENTER + Vector3.new(sx * (STREET + 8), 0, sz * (STREET + 8))
		local toSquare = Vector3.new(-sx, 0, -sz).Unit
		building(corner - toSquare * 2, toSquare, 30, 30, cityRng:NextInteger(85, 110), { Shop = false, Vertical = true })
	end
end

-- a skyline of taller towers further back, for depth
for side = 1, 4 do
	local dir = ({ Vector3.zAxis, -Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis })[side]
	local along = math.abs(dir.Z) > 0 and Vector3.xAxis or Vector3.zAxis
	for i = -2, 2 do
		local width = cityRng:NextInteger(30, 46)
		local front = CENTER + dir * cityRng:NextInteger(185, 215) + along * (i * 62 + cityRng:NextInteger(-10, 10))
		local tower = makePart(roomFolder, "SkylineTower", Vector3.new(width, 1, width), front, Color3.new(1, 1, 1))
		local height = cityRng:NextInteger(110, 190)
		tower.Size = Vector3.new(width, height, width)
		tower.Color = Color3.fromRGB(26, 30, 60):Lerp(Color3.fromRGB(56, 62, 108), cityRng:NextNumber())
		tower.CFrame = CFrame.lookAt(front, front - dir) * CFrame.new(0, height / 2, width / 2)
		windows(tower, Enum.NormalId.Front, width, height, 4, 4, 8)
	end
end

-- A ring of distant buildings right behind the shops, so the gaps between buildings show
-- more city instead of the empty world outside
local BACKDROP = 172
for side = 1, 4 do
	local dir = ({ Vector3.zAxis, -Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis })[side]
	local length = BACKDROP * 2 + 4
	local front = CENTER + dir * BACKDROP
	local wall = makePart(roomFolder, "Backdrop", Vector3.new(length, 70, 4), front, Color3.fromRGB(32, 36, 66))
	wall.CFrame = CFrame.lookAt(front, front - dir) * CFrame.new(0, 35, 2)
	windows(wall, Enum.NormalId.Front, length, 70, 4, 4, 10)
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
	{ -104, 104 }, { 104, 104 }, { -104, -104 }, { 104, -104 },
	{ -106, -20 }, { -106, -45 }, { 106, -20 }, { 106, -45 },
	{ -40, 106 }, { 40, 106 },
}) do
	sakuraTree(t[1], t[2], 1)
end

-- Street lamps along the walkway
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
for _, z in ipairs({ 72, 30, -10, -42 }) do
	streetLamp(-16, z)
	streetLamp(16, z)
end

-- Benches facing the walkway
local function bench(x, z, facingX)
	local pos = CENTER + Vector3.new(x, 0, z)
	local cf = CFrame.lookAt(pos, pos + Vector3.new(facingX, 0, 0))
	local seat = makePart(roomFolder, "BenchSeat", Vector3.new(6, 0.5, 2), pos, Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks)
	seat.CFrame = cf * CFrame.new(0, 1.8, 0)
	local back = makePart(roomFolder, "BenchBack", Vector3.new(6, 1.6, 0.4), pos, Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks)
	back.CFrame = cf * CFrame.new(0, 2.9, 0.9)
	for _, sx in ipairs({ -2.4, 2.4 }) do
		local leg = makePart(roomFolder, "BenchLeg", Vector3.new(0.4, 1.6, 1.8), pos, Color3.fromRGB(45, 45, 55), Enum.Material.Metal)
		leg.CFrame = cf * CFrame.new(sx, 0.8, 0)
	end
end
for _, z in ipairs({ 50, 12, -26 }) do
	bench(-22, z, 1)
	bench(22, z, -1)
end

-- Banner on the station's front (a fixed panel, not floating text)
local banner = makePart(roomFolder, "Banner", Vector3.new(110, 12, 1), CENTER + Vector3.new(0, 34, -STREET + 0.6), Color3.fromRGB(28, 28, 44))
do
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1100, 120)
	gui.LightInfluence = 0
	gui.Parent = banner
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "CHOOSE A TEAM PAD"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = text
end

-- ===== Spawn =====
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Size = Vector3.new(12, 0.4, 12)
spawn.Position = CENTER + Vector3.new(0, 0.6, 90)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Color = Color3.fromRGB(255, 255, 255)
spawn.Parent = lobby

-- ===== Wishing Fountain (the summon spot, front-left area) =====
-- Walk up to the fountain and the summon window pops up (GachaUI checks the invisible
-- SummonAltar trigger that covers the fountain's plaza).
local altarPos = CENTER + Vector3.new(-85, 0, 60)
local fountain = Instance.new("Folder")
fountain.Name = "WishingFountain"
fountain.Parent = lobby

local STONE = Color3.fromRGB(205, 200, 215)
local STONE_DARK = Color3.fromRGB(150, 145, 165)
local WATER = Color3.fromRGB(90, 165, 255)
local MAGIC = Color3.fromRGB(170, 110, 255)
local GOLD = Color3.fromRGB(255, 205, 70)

-- A flat disc (cylinders point along X, so tip it up)
local function disc(name, diameter, thickness, y, color, material)
	local d = makePart(fountain, name, Vector3.new(thickness, diameter, diameter), altarPos, color, material)
	d.Shape = Enum.PartType.Cylinder
	d.CFrame = CFrame.new(altarPos + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return d
end

-- A standing column
local function column(name, diameter, height, y, color, material)
	local c = makePart(fountain, name, Vector3.new(height, diameter, diameter), altarPos, color, material)
	c.Shape = Enum.PartType.Cylinder
	c.CFrame = CFrame.new(altarPos + Vector3.new(0, y + height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return c
end

-- A round wall made of short blocks
local function ringWall(name, radius, height, thickness, y, color, material, segments)
	for i = 1, segments do
		local a = (i - 0.5) / segments * math.pi * 2
		local length = 2 * math.pi * radius / segments + 0.15
		local seg = makePart(fountain, name, Vector3.new(length, height, thickness), altarPos, color, material)
		local pos = altarPos + Vector3.new(math.cos(a) * radius, y + height / 2, math.sin(a) * radius)
		-- facing the centre, so the block's length (X) runs along the circle
		seg.CFrame = CFrame.lookAt(pos, altarPos + Vector3.new(0, y + height / 2, 0))
	end
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
disc("Plaza", 30, 0.3, 0.45, STONE, Enum.Material.Marble)
disc("PlazaInlay", 26, 0.32, 0.46, STONE_DARK, Enum.Material.Marble)
disc("PlazaInner", 25, 0.34, 0.47, STONE, Enum.Material.Marble)
ringWall("MagicCircle", 12.2, 0.05, 0.25, 0.64, MAGIC, Enum.Material.Neon, 40)

-- The basin: a low round wall full of water (with a few wishing coins at the bottom)
disc("BasinFloor", 16, 0.4, 0.75, Color3.fromRGB(70, 110, 170), Enum.Material.Slate)
ringWall("BasinWall", 8, 1.4, 1.1, 0.6, STONE, Enum.Material.Marble, 28)
ringWall("BasinRim", 8, 0.25, 1.5, 2.0, STONE_DARK, Enum.Material.Marble, 28)
local water = disc("Water", 15.2, 0.5, 1.3, WATER, Enum.Material.Glass)
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
disc("Bowl", 7, 0.6, 4.7, STONE, Enum.Material.Marble)
ringWall("BowlRim", 3.4, 0.5, 0.4, 4.8, STONE_DARK, Enum.Material.Marble, 18)
local bowlWater = disc("BowlWater", 6.4, 0.3, 5.05, WATER, Enum.Material.Glass)
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
local altar = makePart(lobby, "SummonAltar", Vector3.new(30, 1, 30), altarPos + Vector3.new(0, 0.9, 0), MAGIC)
altar.Transparency = 1
altar.CanCollide = false
altar.CanQuery = false
altar.CanTouch = false

-- The crystal slowly spins and bobs
local spinTime = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	spinTime += dt
	crystal.CFrame = CFrame.new(altarPos + Vector3.new(0, 10 + math.sin(spinTime * 1.5) * 0.5, 0))
		* CFrame.Angles(0, spinTime * 0.8, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
end)

-- The sign stands BEHIND the fountain as seen from the spawn, and faces the spawn
local toSpawn = Vector3.new(spawn.Position.X - altarPos.X, 0, spawn.Position.Z - altarPos.Z).Unit
local signPos = altarPos - toSpawn * 19
makeSignBoard(lobby, "SummonSign", signPos, MAGIC, "SUMMON", "Walk up to the Wishing Fountain to get new units!", toSpawn, 13)

-- ===== Traits Cave (the trait summon spot, front-right area) =====
-- A rocky cave whose entrance faces the walkway. Walk inside and the trait summon window
-- pops up (TraitCaveUI checks the invisible TraitCave trigger covering the cave floor).
local CAVE_DEPTH = 22 -- how far below the square the cave floor is
local cavePos = CENTER + Vector3.new(85, -CAVE_DEPTH, 55)
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
local CAVE_INNER = 15   -- the inside is 30 x 30 studs
local CAVE_HEIGHT = 18
local WALL = 3

local function rock(name, size, cframe, color)
	local r = makePart(cave, name, size, cframe.Position, color or CAVE_ROCK, Enum.Material.Rock)
	r.CFrame = cframe
	return r
end

-- A glowing crystal standing at `base`, leaning by `tilt` (radians around X then Z)
local function crystal(base, height, width, color, tiltX, tiltZ, lightRange)
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

-- Walls and roof. The entrance is a 12 x 11 gap in the front (-X) wall.
local wallY = CAVE_HEIGHT / 2
local edge = CAVE_INNER + WALL / 2
local span = CAVE_INNER * 2 + WALL * 2
rock("BackWall", Vector3.new(WALL, CAVE_HEIGHT, span), CFrame.new(cavePos + Vector3.new(edge, wallY, 0)))
rock("SideWall", Vector3.new(span, CAVE_HEIGHT, WALL), CFrame.new(cavePos + Vector3.new(0, wallY, edge)))
rock("SideWall", Vector3.new(span, CAVE_HEIGHT, WALL), CFrame.new(cavePos + Vector3.new(0, wallY, -edge)))
local doorHalf, doorHeight = 6, 11
local frontLen = edge + WALL / 2 - doorHalf
for _, sz in ipairs({ -1, 1 }) do
	rock("FrontWall", Vector3.new(WALL, CAVE_HEIGHT, frontLen),
		CFrame.new(cavePos + Vector3.new(-edge, wallY, sz * (doorHalf + frontLen / 2))))
end
rock("Lintel", Vector3.new(WALL, CAVE_HEIGHT - doorHeight, doorHalf * 2),
	CFrame.new(cavePos + Vector3.new(-edge, doorHeight + (CAVE_HEIGHT - doorHeight) / 2, 0)))
rock("Roof", Vector3.new(span, WALL, span), CFrame.new(cavePos + Vector3.new(0, CAVE_HEIGHT + WALL / 2, 0)), CAVE_ROCK_DARK)
makePart(cave, "CaveFloor", Vector3.new(CAVE_INNER * 2, 0.1, CAVE_INNER * 2), cavePos + Vector3.new(0, 0.45, 0),
	Color3.fromRGB(40, 36, 52), Enum.Material.Slate)

-- Boulders piled against the outside and on the roof, so it reads as a cave and not a box.
-- Each one sits far enough out that it can never poke into the inside or the doorway.
local boulderRng = Random.new(7)
local function boulder(offset, size)
	local b = rock("Boulder", Vector3.new(size, size * 0.8, size),
		CFrame.new(cavePos + offset) * CFrame.Angles(boulderRng:NextNumber() * 0.6, boulderRng:NextNumber() * math.pi, boulderRng:NextNumber() * 0.6),
		boulderRng:NextNumber() < 0.5 and CAVE_ROCK or CAVE_ROCK_DARK)
	return b
end
for i = 1, 6 do -- along the back and both sides
	local t = (i - 0.5) / 6 * 2 - 1 -- -1..1 along the wall
	local size = boulderRng:NextNumber(6, 9)
	local out = CAVE_INNER + size * 0.87
	boulder(Vector3.new(out, size * 0.3, t * CAVE_INNER), size)
	boulder(Vector3.new(t * CAVE_INNER, size * 0.3, out), size)
	boulder(Vector3.new(t * CAVE_INNER, size * 0.3, -out), size)
end
for _, p in ipairs({ { -10, -9 }, { -2, 8 }, { 7, -4 }, { 11, 10 }, { -11, 9 }, { 3, -12 } }) do -- on the roof
	local size = boulderRng:NextNumber(7, 11)
	boulder(Vector3.new(p[1], CAVE_HEIGHT + WALL + size * 0.25, p[2]), size)
end

-- Crystals: a big cluster in the middle, smaller ones along the walls, and two by the door
local clusterPos = cavePos + Vector3.new(3, 0.5, 0)
rock("Pedestal", Vector3.new(7, 2, 7), CFrame.new(clusterPos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(20), 0), CAVE_ROCK_DARK)
for i = 1, 6 do
	local a = i / 6 * math.pi * 2
	crystal(clusterPos + Vector3.new(math.cos(a) * 2, 2, math.sin(a) * 2), 3 + (i % 3), 1.1,
		CAVE_CRYSTALS[i % 3 + 1], math.sin(a) * 0.45, -math.cos(a) * 0.45)
end
for i, p in ipairs({ { 12, -12 }, { 12, 12 }, { 0, -13 }, { 0, 13 }, { -12, -12 }, { -12, 12 }, { 13, 0 } }) do
	local color = CAVE_CRYSTALS[i % 3 + 1]
	crystal(cavePos + Vector3.new(p[1], 0.5, p[2]), 2.5, 0.9, color, -p[2] / 60, p[1] / 60, i % 2 == 1 and 20 or nil)
	crystal(cavePos + Vector3.new(p[1] - math.sign(p[1]) * 1.2, 0.5, p[2] + 0.8), 1.6, 0.7, color, -p[2] / 40, p[1] / 40)
end
for _, sz in ipairs({ -1, 1 }) do
	crystal(cavePos + Vector3.new(-edge - 3, 0.5, sz * (doorHalf - 1)), 4, 1.2, CAVE_CRYSTALS[2], 0, sz * 0.2, 18)
end

-- The floating trait crystal over the cluster
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

-- The invisible trigger: standing anywhere inside the cave opens the trait summon window
-- ===== The way down: an opening in the square, a ramp and a tunnel to the cave's door =====
do
	local O = CAVE_OPENING
	local top = CENTER + Vector3.new(O.X0, 0.4, (O.Z0 + O.Z1) / 2)               -- street level
	local bottom = CENTER + Vector3.new(O.X1, -CAVE_DEPTH + 0.5, (O.Z0 + O.Z1) / 2) -- the cave's door
	local length = (bottom - top).Magnitude
	local ramp = rock("Ramp", Vector3.new(O.Z1 - O.Z0, 1, length),
		CFrame.lookAt(top, bottom) * CFrame.new(0, -0.5, -length / 2), Color3.fromRGB(96, 88, 104))
	ramp.Material = Enum.Material.Slate

	-- solid ground under the cave and its doorway
	rock("CaveGround", Vector3.new(span + 6, 2, span), CFrame.new(cavePos + Vector3.new(-2, -1, 0)), CAVE_ROCK_DARK)

	-- tunnel walls from the cave floor up to the street, either side of the ramp
	local tunnelLen = O.X1 - O.X0
	for _, z in ipairs({ O.Z0 - 0.5, O.Z1 + 0.5 }) do
		rock("TunnelWall", Vector3.new(tunnelLen, CAVE_DEPTH + 0.4, 1),
			CFrame.new(CENTER + Vector3.new((O.X0 + O.X1) / 2, (0.4 - CAVE_DEPTH) / 2, z)))
	end
	-- rock between the top of the cave's front wall and the street
	rock("DoorFill", Vector3.new(WALL, 4.4, O.Z1 - O.Z0 + 2), CFrame.new(CENTER + Vector3.new(O.X1, -1.8, (O.Z0 + O.Z1) / 2)))

	-- low rock railings around the opening, so nobody falls in from the side
	for _, z in ipairs({ O.Z0 - 0.6, O.Z1 + 0.6 }) do
		rock("Railing", Vector3.new(tunnelLen + 1.2, 2.6, 1.2), CFrame.new(CENTER + Vector3.new((O.X0 + O.X1) / 2, 1.7, z)))
	end
	rock("Railing", Vector3.new(1.2, 2.6, O.Z1 - O.Z0 + 2.4), CFrame.new(CENTER + Vector3.new(O.X1 + 0.6, 1.7, (O.Z0 + O.Z1) / 2)))

	-- a rocky arch over the top of the ramp, with glowing crystals
	local mid = (O.Z0 + O.Z1) / 2
	for _, sz in ipairs({ -1, 1 }) do
		rock("ArchPillar", Vector3.new(3.4, 15, 3.4),
			CFrame.new(CENTER + Vector3.new(O.X0 - 1, 7.9, mid + sz * 8.4)) * CFrame.Angles(0, math.rad(15 * sz), math.rad(-4 * sz)))
		crystal(CENTER + Vector3.new(O.X0 - 3.5, 0.4, mid + sz * 10.5), 5, 1.4, CAVE_CRYSTALS[(sz + 3) % 3 + 1], 0, sz * 0.25, 22)
	end
	rock("ArchTop", Vector3.new(4, 3.2, 22), CFrame.new(CENTER + Vector3.new(O.X0 - 1, 16.4, mid)) * CFrame.Angles(math.rad(3), 0, 0), CAVE_ROCK_DARK)
	crystal(CENTER + Vector3.new(O.X0 - 1, 17.8, mid), 3.5, 1.2, CAVE_CRYSTALS[1], 0, 0, 24)
end

local caveTrigger = makePart(lobby, "TraitCave", Vector3.new(CAVE_INNER * 2, 1, CAVE_INNER * 2), cavePos + Vector3.new(0, 0.9, 0), CAVE_CRYSTALS[1])
caveTrigger.Transparency = 1
caveTrigger.CanCollide = false
caveTrigger.CanQuery = false
caveTrigger.CanTouch = false

local caveTime = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	caveTime += dt
	traitCrystal.CFrame = CFrame.new(clusterPos + Vector3.new(0, 9 + math.sin(caveTime * 1.2) * 0.5, 0))
		* CFrame.Angles(0, -caveTime * 0.9, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
end)

-- The sign stands beside the entrance and faces the spawn
-- (at street level, beside the ramp, since the cave itself is underground)
local caveSignPos = CENTER + Vector3.new(44, 0, 78)
local caveToSpawn = Vector3.new(spawn.Position.X - caveSignPos.X, 0, spawn.Position.Z - caveSignPos.Z).Unit
makeSignBoard(lobby, "TraitCaveSign", caveSignPos, CAVE_CRYSTALS[1], "TRAITS CAVE",
	"Head down the ramp to summon traits onto your units!", caveToSpawn, 13)

-- ===== Five team queue pads (in front of the station) =====
for i = 1, NUM_PADS do
	local color = TEAM_COLORS[i]
	local x = (i - (NUM_PADS + 1) / 2) * 40 -- -80, -40, 0, 40, 80

	local pad = makePart(padsFolder, "Pad" .. i, Vector3.new(22, 0.4, 22), CENTER + Vector3.new(x, 0.6, -70), color, Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 26
	glow.Brightness = 1.5
	glow.Parent = pad

	makeSignBoard(padsFolder, "Sign" .. i, CENTER + Vector3.new(x, 0, -92), color, "TEAM " .. i,
		string.format("Step here to queue\n0/%d", MAX_PLAYERS))

	-- a hanging team banner on the station's front behind each pad
	makePart(roomFolder, "PadStripe" .. i, Vector3.new(16, 22, 0.4), CENTER + Vector3.new(x, 15, -(half + 4) + 0.3), color, Enum.Material.Neon)
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
		Brightness = 1.6,
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
	-- a light blue night haze that softens the distant skyline (none during the day)
	Lighting:SetAttribute("Day_AtmosphereDensity", atmosphere.Density)
	Lighting:SetAttribute("Night_AtmosphereDensity", 0.32)
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(70, 82, 140)
	atmosphere.Decay = Color3.fromRGB(30, 30, 70)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2

	-- glow on neon and lit windows, and a little extra color everywhere
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.7
		bloom.Size = 28
		bloom.Threshold = 1.4
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChild("LobbyColor") then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "LobbyColor"
		grade.Saturation = 0.18
		grade.Contrast = 0.06
		grade.Parent = Lighting
	end
end

lobby.Parent = workspace

-- Everyone should spawn in the lobby
for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("SpawnLocation") and inst ~= spawn then
		inst.Enabled = false
	end
end
