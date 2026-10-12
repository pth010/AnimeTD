-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: LobbyBuilder
-- (replaces the earlier version: the summon altar is now a Wishing Fountain with a floating
--  summon crystal, water jets, wishing coins and lanterns)
-- Builds the lobby room at runtime:
--   * a 240 x 240 stud square room, 40 studs tall, with walls, roof and ceiling lights
--   * the player spawn near the front wall
--   * the Wishing Fountain (walk up to it and the summon window pops up) with its own sign
--   * FIVE team queue pads along the back wall, each with a standing sign board that
--     shows the team name and the live queue status
-- Assumes the default 512x512 Baseplate (the room is centered on the origin).
-- If Workspace.Lobby already exists (you built your own), this script does nothing.
-- A custom lobby needs: Lobby.LobbySpawn, Lobby.SummonAltar (a flat part marking the summon
-- area), and Lobby.QueuePads
-- containing Pad1..Pad5 (the parts to stand on) and Sign1..Sign5 (parts holding a
-- SurfaceGui named QueueGui with a TextLabel named Label inside).

if workspace:FindFirstChild("Lobby") then return end

local CENTER = Vector3.new(0, 0, 0)
local SIZE = 240   -- the room is SIZE x SIZE studs
local HEIGHT = 40
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
roomFolder.Name = "Room"
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

-- ===== The room =====
local wallColor = Color3.fromRGB(45, 45, 78)

makePart(roomFolder, "Floor", Vector3.new(SIZE, 0.4, SIZE), CENTER + Vector3.new(0, 0.2, 0), Color3.fromRGB(55, 55, 90))
-- a lighter strip leading from the spawn to the pads
makePart(roomFolder, "Walkway", Vector3.new(24, 0.1, 170), CENTER + Vector3.new(0, 0.42, 5), Color3.fromRGB(75, 75, 120))

makePart(roomFolder, "BackWall",  Vector3.new(SIZE + 4, HEIGHT, 2), CENTER + Vector3.new(0, HEIGHT / 2, -half - 1), wallColor)
makePart(roomFolder, "FrontWall", Vector3.new(SIZE + 4, HEIGHT, 2), CENTER + Vector3.new(0, HEIGHT / 2, half + 1), wallColor)
makePart(roomFolder, "LeftWall",  Vector3.new(2, HEIGHT, SIZE), CENTER + Vector3.new(-half - 1, HEIGHT / 2, 0), wallColor)
makePart(roomFolder, "RightWall", Vector3.new(2, HEIGHT, SIZE), CENTER + Vector3.new(half + 1, HEIGHT / 2, 0), wallColor)
makePart(roomFolder, "Roof", Vector3.new(SIZE + 4, 2, SIZE + 4), CENTER + Vector3.new(0, HEIGHT + 1, 0), Color3.fromRGB(30, 30, 55))

-- Corner pillars
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		makePart(roomFolder, "Pillar", Vector3.new(7, HEIGHT, 7), CENTER + Vector3.new(sx * (half - 4), HEIGHT / 2, sz * (half - 4)), Color3.fromRGB(65, 65, 105))
	end
end

-- Ceiling lights (4 x 4) so the room isn't dark
for _, x in ipairs({ -90, -30, 30, 90 }) do
	for _, z in ipairs({ -90, -30, 30, 90 }) do
		local lamp = makePart(roomFolder, "CeilingLight", Vector3.new(12, 0.5, 12), CENTER + Vector3.new(x, HEIGHT - 0.25, z), Color3.fromRGB(255, 245, 220), Enum.Material.Neon)
		lamp.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = 90
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 245, 225)
		light.Parent = lamp
	end
end

-- Banner on the back wall (a fixed panel, not floating text)
local banner = makePart(roomFolder, "Banner", Vector3.new(110, 12, 1), CENTER + Vector3.new(0, 30, -half + 0.5), Color3.fromRGB(28, 28, 44))
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

-- ===== Five team queue pads (back wall) =====
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

	-- a colored stripe on the back wall behind each team
	makePart(roomFolder, "PadStripe" .. i, Vector3.new(22, 14, 0.4), CENTER + Vector3.new(x, 7.4, -half + 0.2), color, Enum.Material.Neon)
end

lobby.Parent = workspace

-- Everyone should spawn in the lobby
for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("SpawnLocation") and inst ~= spawn then
		inst.Enabled = false
	end
end
