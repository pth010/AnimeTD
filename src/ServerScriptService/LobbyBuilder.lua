-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: LobbyBuilder
-- (replaces the earlier version: a much bigger square room, and every sign is now a
--  fixed board standing in the room instead of floating text that follows the camera)
-- Builds the lobby room at runtime:
--   * a 240 x 240 stud square room, 40 studs tall, with walls, roof and ceiling lights
--   * the player spawn near the front wall
--   * the Summon Altar (walk onto it and the summon window pops up) with its own sign
--   * FIVE team queue pads along the back wall, each with a standing sign board that
--     shows the team name and the live queue status
-- Assumes the default 512x512 Baseplate (the room is centered on the origin).
-- If Workspace.Lobby already exists (you built your own), this script does nothing.
-- A custom lobby needs: Lobby.LobbySpawn, Lobby.SummonAltar, and Lobby.QueuePads
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

-- ===== Summon Altar (front-left area) =====
local altarPos = CENTER + Vector3.new(-85, 0, 60)
local altar = makePart(lobby, "SummonAltar", Vector3.new(16, 1, 16), altarPos + Vector3.new(0, 0.9, 0), Color3.fromRGB(120, 80, 220), Enum.Material.Neon)
local orb = makePart(lobby, "SummonOrb", Vector3.new(4, 4, 4), altarPos + Vector3.new(0, 5.5, 0), Color3.fromRGB(220, 180, 255), Enum.Material.Neon)
orb.Shape = Enum.PartType.Ball
orb.CanCollide = false
orb.Transparency = 1 -- invisible; it only holds the purple glow now
local orbLight = Instance.new("PointLight")
orbLight.Color = Color3.fromRGB(190, 140, 255)
orbLight.Range = 35
orbLight.Brightness = 2
orbLight.Parent = orb
-- The sign stands BEHIND the altar as seen from the spawn, and faces the spawn
local toSpawn = Vector3.new(spawn.Position.X - altarPos.X, 0, spawn.Position.Z - altarPos.Z).Unit
local signPos = altarPos - toSpawn * 13
-- raised (boardY = 15); set the last number back to 11 (or remove it) to lower the sign now the orb is invisible
makeSignBoard(lobby, "SummonSign", signPos, Color3.fromRGB(120, 80, 220), "SUMMON", "Step onto the altar to get new units!", toSpawn, 15)

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
