-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: IslandBuilder
-- Builds the whole map at runtime, so an empty Baseplate place is all you need:
--   * a floating island high in a night sky (fall off the edge and you lose your bag!)
--   * the Star Well in the middle (bank stars here), with a beam of light you can see anywhere
--   * star trees, glowing crystals, boulders around a partly open edge
--   * a "How to play" sign by the spawn and the all-time leaderboard board
--   * night lighting, bloom and atmosphere
-- It deletes the default Baseplate (players would land on it instead of falling).
-- If Workspace.StarfallIsland already exists (you built your own), this script does nothing.
-- A custom island needs: StarfallIsland.Ground (folder of floor parts), StarfallIsland.StarWell
-- (a part at the well's centre with a GuideAttachment inside), a SpawnLocation, and the
-- attributes Center (Vector3), Radius, GroundY and WellRadius on the StarfallIsland model.

if workspace:FindFirstChild("StarfallIsland") then return end

local Lighting = game:GetService("Lighting")

local CENTER = Vector3.new(0, 150, 0) -- top of the grass is at CENTER.Y
local RADIUS = 110
local WELL_RADIUS = 11
local rng = Random.new(20261018) -- same layout every server

local island = Instance.new("Model")
island.Name = "StarfallIsland"
local groundFolder = Instance.new("Folder")
groundFolder.Name = "Ground"
groundFolder.Parent = island
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = island

local function makePart(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Cylinders point along X, so tip them up to make a flat disc / a standing column
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function disc(parent, name, diameter, thickness, centerPos, color, material)
	local d = makePart(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(centerPos) * UPRIGHT, color, material)
	d.Shape = Enum.PartType.Cylinder
	return d
end

-- A point on the grass at a given angle and distance from the centre
local function onGround(angle, dist, height)
	return CENTER + Vector3.new(math.cos(angle) * dist, height or 0, math.sin(angle) * dist)
end

-- ===== The island =====
disc(groundFolder, "Grass", RADIUS * 2, 4, CENTER - Vector3.new(0, 2, 0), Color3.fromRGB(70, 130, 105), Enum.Material.Grass)
disc(groundFolder, "Soil", RADIUS * 2 + 3, 6, CENTER - Vector3.new(0, 6.5, 0), Color3.fromRGB(95, 70, 60), Enum.Material.Ground)
-- the rocky underside narrows into a point
for i = 1, 8 do
	local d = RADIUS * 2 * (1 - i * 0.115)
	local shade = 70 - i * 4
	disc(decor, "Underside", d, 9, CENTER - Vector3.new(0, 9 + i * 8, 0), Color3.fromRGB(shade + 10, shade, shade + 25), Enum.Material.Slate)
end

-- a stone plaza around the well
disc(groundFolder, "Plaza", 44, 0.4, CENTER + Vector3.new(0, 0.2, 0), Color3.fromRGB(150, 145, 170), Enum.Material.Cobblestone)

-- Boulders around the edge, with gaps you can be knocked through
for i = 1, 30 do
	if rng:NextNumber() < 0.55 then
		local a = (i / 30) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local h = rng:NextNumber(1.6, 3.4)
		local size = Vector3.new(rng:NextNumber(5, 9), h, rng:NextNumber(4, 7))
		local pos = onGround(a, RADIUS - 3, h / 2)
		local rock = makePart(decor, "EdgeRock", size, CFrame.lookAt(pos, CENTER + Vector3.new(0, h / 2, 0)), Color3.fromRGB(105, 100, 125), Enum.Material.Slate)
		rock.CFrame *= CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
	end
end

-- Star trees: dark trunks with softly glowing canopies
local SPAWN_POS = CENTER + Vector3.new(0, 0.6, 72)
local function farFromSpecialSpots(pos)
	local flatSpawn = Vector3.new(pos.X - SPAWN_POS.X, 0, pos.Z - SPAWN_POS.Z).Magnitude
	local flatCenter = Vector3.new(pos.X - CENTER.X, 0, pos.Z - CENTER.Z).Magnitude
	return flatSpawn > 18 and flatCenter > 30
end

local placed = 0
while placed < 11 do
	local pos = onGround(rng:NextNumber(0, math.pi * 2), rng:NextNumber(32, RADIUS - 16))
	if farFromSpecialSpots(pos) then
		placed += 1
		local h = rng:NextNumber(9, 14)
		local trunk = makePart(decor, "Trunk", Vector3.new(h, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * UPRIGHT, Color3.fromRGB(60, 40, 50), Enum.Material.Wood)
		trunk.Shape = Enum.PartType.Cylinder
		local hue = rng:NextNumber(0.72, 0.9)
		for j = 1, 3 do
			local s = rng:NextNumber(6, 9)
			local leaf = makePart(decor, "Canopy", Vector3.new(s, s * 0.8, s),
				CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), h + rng:NextNumber(-1, 2), rng:NextNumber(-2, 2))),
				Color3.fromHSV(hue, 0.45, 0.85), Enum.Material.Neon)
			leaf.Shape = Enum.PartType.Ball
			leaf.Transparency = 0.15
			leaf.CanCollide = false
			if j == 1 then
				local light = Instance.new("PointLight")
				light.Color = leaf.Color
				light.Range = 16
				light.Brightness = 0.8
				light.Parent = leaf
			end
		end
	end
end

-- Glowing crystal clusters
placed = 0
while placed < 9 do
	local pos = onGround(rng:NextNumber(0, math.pi * 2), rng:NextNumber(26, RADIUS - 10))
	if farFromSpecialSpots(pos) then
		placed += 1
		local color = rng:NextNumber() < 0.5 and Color3.fromRGB(120, 220, 255) or Color3.fromRGB(190, 130, 255)
		for j = 1, 3 do
			local h = rng:NextNumber(3, 6.5)
			local crystal = makePart(decor, "Crystal", Vector3.new(1.3, h, 1.3),
				CFrame.new(pos + Vector3.new(rng:NextNumber(-1.5, 1.5), h / 2 - 0.4, rng:NextNumber(-1.5, 1.5)))
					* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 3), rng:NextNumber(-0.35, 0.35)),
				color, Enum.Material.Neon)
			crystal.CanCollide = false
			if j == 1 then
				local light = Instance.new("PointLight")
				light.Color = color
				light.Range = 12
				light.Parent = crystal
			end
		end
	end
end

-- ===== The Star Well =====
local STONE = Color3.fromRGB(200, 195, 215)
local WELL_GLOW = Color3.fromRGB(140, 230, 255)
for i = 1, 24 do
	local a = (i - 0.5) / 24 * math.pi * 2
	local r = 9
	local length = 2 * math.pi * r / 24 + 0.2
	local pos = onGround(a, r, 1.1)
	makePart(decor, "WellWall", Vector3.new(length, 2.2, 1.4), CFrame.lookAt(pos, CENTER + Vector3.new(0, 1.1, 0)), STONE, Enum.Material.Marble)
end
local water = disc(decor, "WellWater", 17, 0.6, CENTER + Vector3.new(0, 1.2, 0), WELL_GLOW, Enum.Material.Neon)
water.Transparency = 0.2
water.CanCollide = false
local waterLight = Instance.new("PointLight")
waterLight.Color = WELL_GLOW
waterLight.Range = 40
waterLight.Brightness = 2
waterLight.Parent = water

-- The beam of light: you can always find your way back to the well
local beam = makePart(decor, "WellBeam", Vector3.new(500, 7, 7), CFrame.new(CENTER + Vector3.new(0, 250, 0)) * UPRIGHT, WELL_GLOW, Enum.Material.Neon)
beam.Shape = Enum.PartType.Cylinder
beam.Transparency = 0.8
beam.CanCollide = false
beam.CanQuery = false
beam.CastShadow = false

-- The well marker the game reads (invisible). Its particles burst when someone banks stars.
local well = makePart(island, "StarWell", Vector3.new(2, 2, 2), CFrame.new(CENTER + Vector3.new(0, 1.5, 0)), WELL_GLOW)
well.Transparency = 1
well.CanCollide = false
well.CanQuery = false
well.CanTouch = false
local guide = Instance.new("Attachment")
guide.Name = "GuideAttachment"
guide.Position = Vector3.new(0, 2, 0)
guide.Parent = well
local sparkle = Instance.new("ParticleEmitter")
sparkle.Name = "Sparkle"
sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 250, 210), WELL_GLOW)
sparkle.LightEmission = 1
sparkle.Size = NumberSequence.new(0.5, 0)
sparkle.Lifetime = NumberRange.new(1.5, 2.5)
sparkle.Speed = NumberRange.new(4, 9)
sparkle.SpreadAngle = Vector2.new(25, 25)
sparkle.EmissionDirection = Enum.NormalId.Top
sparkle.Rate = 10
sparkle.Parent = well
local burst = sparkle:Clone()
burst.Name = "DepositBurst"
burst.Rate = 0
burst.Speed = NumberRange.new(18, 34)
burst.Size = NumberSequence.new(0.9, 0)
burst.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 250, 210))
burst.Parent = well

-- ===== Spawn =====
local spawn = Instance.new("SpawnLocation")
spawn.Name = "IslandSpawn"
spawn.Size = Vector3.new(10, 0.4, 10)
spawn.CFrame = CFrame.lookAt(SPAWN_POS, Vector3.new(CENTER.X, SPAWN_POS.Y, CENTER.Z)) -- face the well
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Color = Color3.fromRGB(255, 220, 130)
spawn.Material = Enum.Material.Neon
spawn.Parent = island

-- ===== Signs =====
-- A board on two posts; the text is printed on the side facing `lookFrom`.
local function signBoard(name, pos, lookFrom, size)
	local base = CFrame.lookAt(pos, Vector3.new(lookFrom.X, pos.Y, lookFrom.Z)) -- front (-Z) faces the reader
	local postHeight = size.Y * 0.35
	for _, dx in ipairs({ -size.X * 0.38, size.X * 0.38 }) do
		makePart(decor, name .. "Post", Vector3.new(1.2, postHeight + 1, 1.2), base * CFrame.new(dx, postHeight / 2, 0.6), Color3.fromRGB(60, 50, 70), Enum.Material.Wood)
	end
	local board = makePart(island, name, size, base * CFrame.new(0, postHeight + size.Y / 2, 0), Color3.fromRGB(25, 22, 45))
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = board
	return board, gui
end

local function guiText(parent, text, pos, size, textSize, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = text
	l.TextColor3 = color
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Parent = parent
	return l
end

local GOLD = Color3.fromRGB(255, 205, 80)
local WHITE = Color3.new(1, 1, 1)
local SOFT = Color3.fromRGB(200, 195, 230)

-- How to play, beside the spawn
do
	local _, gui = signBoard("HowToSign", SPAWN_POS + Vector3.new(-17, -0.6, -8), SPAWN_POS, Vector3.new(18, 12, 1))
	guiText(gui, "STARFALL SCRAMBLE", UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 44), 36, GOLD, Enum.Font.FredokaOne)
	guiText(gui,
		"1. Run into falling stars to fill your bag.\n" ..
		"2. Bank them at the glowing Star Well for Stardust.\n" ..
		"3. Dodge meteors! Red circles show where they land.\n" ..
		"    A hit spills half your bag. Falling off loses it all.\n" ..
		"4. Spend Stardust on upgrades. Go Supernova to earn faster forever.",
		UDim2.fromOffset(24, 76), UDim2.new(1, -48, 1, -90), 21, WHITE, Enum.Font.GothamMedium, Enum.TextXAlignment.Left)
end

-- The all-time leaderboard (filled in by StarBoard), behind the well as seen from the spawn
do
	local boardPos = CENTER + Vector3.new(0, 0, -34)
	local board, gui = signBoard("LeaderBoard", boardPos, CENTER + Vector3.new(0, 0, 40), Vector3.new(20, 18, 1))
	board.Name = "LeaderBoard"
	guiText(gui, "BRIGHTEST STAR CATCHERS", UDim2.fromOffset(0, 16), UDim2.new(1, 0, 0, 40), 30, GOLD, Enum.Font.FredokaOne)
	guiText(gui, "Lifetime Stardust, all servers", UDim2.fromOffset(0, 54), UDim2.new(1, 0, 0, 24), 18, SOFT, Enum.Font.GothamMedium)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(24, 90)
	rows.Size = UDim2.new(1, -48, 1, -104)
	rows.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = rows
	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0.1, -4)
		row.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(38, 34, 66) or Color3.fromRGB(32, 28, 58)
		row.BorderSizePixel = 0
		row.Parent = rows
		local who = guiText(row, i == 1 and "Be the first!" or "", UDim2.fromOffset(12, 0), UDim2.new(0.65, -12, 1, 0), 22,
			i <= 3 and GOLD or WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
		who.Name = "Who"
		who.TextYAlignment = Enum.TextYAlignment.Center
		who.TextTruncate = Enum.TextTruncate.AtEnd
		who.TextWrapped = false
		local amount = guiText(row, "", UDim2.new(0.65, 0, 0, 0), UDim2.new(0.35, -12, 1, 0), 22, SOFT, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
		amount.Name = "Amount"
		amount.TextYAlignment = Enum.TextYAlignment.Center
	end
end

-- Values the game scripts read
island:SetAttribute("Center", CENTER)
island:SetAttribute("Radius", RADIUS)
island:SetAttribute("GroundY", CENTER.Y)
island:SetAttribute("WellRadius", WELL_RADIUS)
island.Parent = workspace

-- Players should fall into the void, not onto the default Baseplate
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("SpawnLocation") and inst ~= spawn then
		inst.Enabled = false
	end
end

-- ===== Night sky =====
Lighting.ClockTime = 0
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(70, 60, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 110, 170)
Lighting.GlobalShadows = true
if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Color = Color3.fromRGB(120, 100, 200)
	atmosphere.Decay = Color3.fromRGB(60, 40, 120)
	atmosphere.Glare = 0
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
end
if not Lighting:FindFirstChildOfClass("BloomEffect") then
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
end
