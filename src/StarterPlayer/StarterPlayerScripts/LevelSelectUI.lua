-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: LevelSelectUI
-- (replaces the earlier version: locked maps say LOCKED and which map + difficulty to beat
--  to open them, for the late-game maps in LevelData that have UnlockedBy.)
-- You pick a MAP first, then one of its difficulties. Click a map to see its difficulties,
-- each with its waves, enemy strength and rewards. Maps and difficulties come from
-- LevelData, so a map added there shows up here on its own.
-- The level-select window that pops up while you stand on a team pad in the lobby.
--   * Everyone on the pad can look through the maps and their difficulties.
--   * The first player on the pad (the host) picks what the team plays. A map's first
--     difficulty is open (some late-game maps need another map beaten first), and each harder
--     difficulty needs the one before it beaten. Picking starts the countdown, START skips
--     most of it.
--   * Everyone else sees which map and difficulty the host picked, and the countdown.
-- Step off the pad (or press X) to close it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- the lobby only: the match place has none of this
if require(ReplicatedStorage:WaitForChild("PlaceConfig")).IsMatchPlace() then return end
local LevelData = require(ReplicatedStorage:WaitForChild("LevelData"))
-- The reward icons are a nice-to-have: if CurrencyIcons is missing or broken, the level
-- select must still open (you can't queue without it), so load it carefully.
local CurrencyIcons = nil
do
	local module = ReplicatedStorage:WaitForChild("CurrencyIcons", 5)
	local ok, result = false, nil
	if module then
		ok, result = pcall(require, module)
	end
	if ok and type(result) == "table" and type(result.Make) == "function" then
		CurrencyIcons = result
	else
		warn("[LevelSelectUI] CurrencyIcons is missing or not the full script, so level rewards show without icons."
			.. " Paste the CurrencyIcons code into ReplicatedStorage.CurrencyIcons.")
	end
end
local levelRemote = ReplicatedStorage:WaitForChild("LevelSelectRemote")
local player = Players.LocalPlayer

local WIDTH, HEIGHT = 560, 500
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(22, 20, 38)
local CARD = Color3.fromRGB(34, 31, 56)
local CARD_PICKED = Color3.fromRGB(52, 46, 84)
local SUBTLE = Color3.fromRGB(185, 180, 215)
local GOLD = Color3.fromRGB(255, 205, 70)
local GEM = Color3.fromRGB(130, 220, 255)
local SHARD = Color3.fromRGB(80, 230, 220) -- same as TraitData.ShardColor
local LOCKED = Color3.fromRGB(110, 105, 130)
local CLEARED = Color3.fromRGB(110, 230, 140)

local CARD_H, CARD_GAP = 80, 8
local LIST_TOP = 72          -- where the map list starts
local LIST_BOTTOM = HEIGHT - 84 -- both lists end here, above the status line and START

local padsFolder = workspace:WaitForChild("Lobby"):WaitForChild("QueuePads")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent, text, pos, size, textSize, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = text
	l.TextColor3 = color or WHITE
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

-- ===== Window =====
local gui = Instance.new("ScreenGui")
gui.Name = "LevelSelectGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
window.BackgroundColor3 = PANEL
window.Parent = gui
corner(window, 14)
local windowStroke = Instance.new("UIStroke")
windowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
windowStroke.Thickness = 2
windowStroke.Parent = window

local uiScale = Instance.new("UIScale")
uiScale.Parent = window
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(1, (vp.X - 20) / WIDTH, (vp.Y - 40) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local title = label(window, "", UDim2.fromOffset(20, 12), UDim2.new(1, -80, 0, 30), 24, WHITE, Enum.Font.GothamBlack)
local subtitle = label(window, "", UDim2.fromOffset(20, 42), UDim2.new(1, -80, 0, 20), 14, SUBTLE)

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -46, 0, 12)
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextSize = 16
close.TextColor3 = WHITE
close.BackgroundColor3 = Color3.fromRGB(190, 70, 70)
close.Parent = window
corner(close, 8)

-- Back to the map list (only while a map's difficulties are showing), with the map's story beside it
local backButton = Instance.new("TextButton")
backButton.Position = UDim2.fromOffset(16, LIST_TOP)
backButton.Size = UDim2.fromOffset(110, 28)
backButton.Text = "<  All maps"
backButton.Font = Enum.Font.GothamBold
backButton.TextSize = 14
backButton.TextColor3 = WHITE
backButton.BackgroundColor3 = CARD
backButton.Visible = false
backButton.Parent = window
corner(backButton, 8)
local mapStory = label(window, "", UDim2.fromOffset(136, LIST_TOP), UDim2.new(1, -152, 0, 28), 13, SUBTLE, Enum.Font.Gotham)
mapStory.Visible = false

-- Two scrolling lists in the same spot: all the maps, and one map's difficulties
local function makeList(top)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, top)
	list.Size = UDim2.new(1, -32, 0, LIST_BOTTOM - top)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, CARD_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end
local mapList = makeList(LIST_TOP)
local difficultyList = makeList(LIST_TOP + 36)
difficultyList.Visible = false

local status = label(window, "", UDim2.fromOffset(20, HEIGHT - 58), UDim2.new(1, -200, 0, 44), 15, SUBTLE)
status.TextWrapped = true
status.TextTruncate = Enum.TextTruncate.None

local startButton = Instance.new("TextButton")
startButton.AnchorPoint = Vector2.new(1, 0)
startButton.Position = UDim2.new(1, -16, 0, HEIGHT - 60)
startButton.Size = UDim2.fromOffset(160, 46)
startButton.Text = "START"
startButton.Font = Enum.Font.GothamBlack
startButton.TextSize = 20
startButton.TextColor3 = WHITE
startButton.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
startButton.Parent = window
corner(startButton, 10)

local messageToken = 0
local function flash(text)
	messageToken += 1
	local mine = messageToken
	status.Text = text
	status.TextColor3 = Color3.fromRGB(255, 130, 130)
	task.delay(2, function()
		if messageToken == mine then status.TextColor3 = SUBTLE end
	end)
end

-- ===== State =====
local currentPad = nil
local closedPad = nil  -- the pad you closed the window on (it stays closed until you step off)
local openMapId = nil  -- the map whose difficulties are showing (nil = the map list)
local shownMapId = nil -- the map the difficulty list was last scrolled for
local lastPicked = 0   -- the host's last pick, to follow it when it changes
local refresh -- defined below

local function choose(levelId)
	local ok, res = pcall(function()
		return levelRemote:InvokeServer("Select", levelId)
	end)
	if not ok or type(res) ~= "table" then
		flash("Couldn't pick that. Try again.")
	elseif not res.Success then
		flash(res.Error or "Couldn't pick that.")
	end
end

local function openMap(mapId)
	openMapId = mapId
	refresh()
end
backButton.Activated:Connect(function() openMap(nil) end)

local function cardButton(parent, order)
	local card = Instance.new("TextButton")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, CARD_H) -- room for the scroll bar
	card.BackgroundColor3 = CARD
	card.AutoButtonColor = false
	card.Text = ""
	card.Parent = parent
	corner(card, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 3
	stroke.Color = GOLD
	stroke.Enabled = false
	stroke.Parent = card
	return card, stroke
end

local function colorStrip(card, color)
	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(0, 8, 1, 0)
	strip.BackgroundColor3 = color
	strip.BorderSizePixel = 0
	strip.Parent = card
	corner(strip, 4)
end

-- ===== Map cards =====
local mapCards = {} -- [mapId] = { Frame, Stroke, Progress, Pips = { [levelId] = Frame }, Tag }
for i, map in ipairs(LevelData.Maps) do
	local card, stroke = cardButton(mapList, i)
	card.AutoButtonColor = true
	colorStrip(card, map.Color)

	local names = {}
	for _, level in ipairs(map.Levels) do
		table.insert(names, level.Difficulty)
	end
	label(card, map.Name, UDim2.fromOffset(22, 8), UDim2.new(1, -200, 0, 24), 19, WHITE, Enum.Font.GothamBlack)
	label(card, map.Description, UDim2.fromOffset(22, 34), UDim2.new(1, -200, 0, 18), 12, SUBTLE, Enum.Font.Gotham)
	-- the difficulties it has, or what to beat to unlock it
	local namesText = table.concat(names, "  ·  ")
	local namesLabel = label(card, namesText, UDim2.fromOffset(22, 54), UDim2.new(1, -200, 0, 16), 12, LOCKED)

	-- right side: how many difficulties you've beaten, one pip per difficulty, and the host's pick
	local progress = label(card, "", UDim2.new(1, -170, 0, 8), UDim2.fromOffset(156, 18), 13, SUBTLE, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	local pips = {}
	for k, level in ipairs(map.Levels) do
		local pip = Instance.new("Frame")
		pip.Position = UDim2.new(1, -14 - (#map.Levels - k + 1) * 22, 0, 32)
		pip.Size = UDim2.fromOffset(18, 10)
		pip.BackgroundColor3 = level.Color
		pip.BorderSizePixel = 0
		pip.Parent = card
		corner(pip, 3)
		local edge = Instance.new("UIStroke")
		edge.Color = level.Color
		edge.Parent = pip
		pips[level.Id] = pip
	end
	local tag = label(card, "", UDim2.new(1, -170, 0, 54), UDim2.fromOffset(156, 18), 12, GOLD, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)

	mapCards[map.Id] = { Frame = card, Stroke = stroke, Progress = progress, Pips = pips, Tag = tag,
		Names = namesLabel, NamesText = namesText }
	card.Activated:Connect(function() openMap(map.Id) end)
end

-- ===== Difficulty cards (one per map + difficulty; only the open map's show) =====
local levelCards = {} -- [levelId] = { Frame, Stroke, Tag, Level }
for _, map in ipairs(LevelData.Maps) do
	for k, level in ipairs(map.Levels) do
		local card, stroke = cardButton(difficultyList, k)
		card.Visible = false
		colorStrip(card, level.Color)

		label(card, string.upper(level.Difficulty), UDim2.fromOffset(22, 8), UDim2.new(1, -200, 0, 24), 19, level.Color, Enum.Font.GothamBlack)
		label(card, string.format("%d waves   -   enemies x%.1f HP", level.Waves, level.HealthMult),
			UDim2.fromOffset(22, 34), UDim2.new(1, -200, 0, 16), 12, SUBTLE)
		label(card, string.format("Start with $%d   -   a boss every %d waves", level.StartCash, level.BossEvery),
			UDim2.fromOffset(22, 52), UDim2.new(1, -200, 0, 16), 12, SUBTLE, Enum.Font.Gotham)

		-- what a win pays: the amount, then the currency's icon at the right edge
		for i, reward in ipairs({
			{ "Gold", level.WinGold, " Gold", GOLD },
			{ "Gems", level.WinGems, " Gems", GEM },
			{ "Shards", level.WinShards or 0, " Shards", SHARD },
		}) do
			local y = 4 + (i - 1) * 17
			label(card, "+" .. reward[2] .. reward[3], UDim2.new(1, -150, 0, y), UDim2.fromOffset(116, 18), 14, reward[4], Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
			local ok, icon = pcall(function()
				return CurrencyIcons and CurrencyIcons.Make(reward[1], 17)
			end)
			if ok and icon then
				icon.Position = UDim2.new(1, -31, 0, y)
				icon.Parent = card
			end
		end
		local tag = label(card, "", UDim2.new(1, -170, 0, 58), UDim2.fromOffset(156, 18), 12, SUBTLE, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)

		levelCards[level.Id] = { Frame = card, Stroke = stroke, Tag = tag, Level = level }

		card.Activated:Connect(function()
			local pad = currentPad
			if not pad then return end
			if pad:GetAttribute("Host") == player.UserId then
				choose(level.Id)
			else
				local hostName = pad:GetAttribute("HostName") or ""
				flash((hostName ~= "" and hostName or "The host") .. " picks what the team plays.")
			end
		end)
	end
end

startButton.Activated:Connect(function()
	local ok, res = pcall(function()
		return levelRemote:InvokeServer("Start")
	end)
	if ok and type(res) == "table" and not res.Success then
		flash(res.Error or "Couldn't start.")
	end
end)

close.Activated:Connect(function()
	closedPad = currentPad
	gui.Enabled = false
end)

-- ===== Keeping it up to date =====
refresh = function()
	local pad = currentPad
	if not pad then return end

	local padNumber = string.match(pad.Name, "%d+") or "?"
	local isHost = pad:GetAttribute("Host") == player.UserId
	local hostName = pad:GetAttribute("HostName") or ""
	local picked = pad:GetAttribute("Level") or 0
	local countdown = pad:GetAttribute("Countdown") or -1
	local running = pad:GetAttribute("Running") == true
	local cleared = LevelData.ParseCleared(player:GetAttribute("ClearedLevels"))
	local pickedLevel = LevelData.Get(picked)

	-- when the host picks something new, show that map (so everyone on the pad sees it)
	if pickedLevel and picked ~= lastPicked then
		openMapId = pickedLevel.MapId
	end
	lastPicked = picked

	local map = openMapId and LevelData.GetMap(openMapId)
	if not map then openMapId = nil end
	mapList.Visible = map == nil
	difficultyList.Visible = map ~= nil
	backButton.Visible = map ~= nil
	mapStory.Visible = map ~= nil
	if map and shownMapId ~= map.Id then
		difficultyList.CanvasPosition = Vector2.zero
	end
	shownMapId = map and map.Id or nil

	title.Text = "TEAM " .. padNumber .. "  -  " .. (map and string.upper(map.Name) or "CHOOSE A MAP")
	windowStroke.Color = pad.Color
	if running then
		subtitle.Text = "This team's match is in progress. Wait here to join the next one."
	elseif isHost then
		subtitle.Text = "You're the host: pick the map and difficulty your team will play."
	elseif hostName ~= "" then
		subtitle.Text = hostName .. " is the host and picks the map and difficulty."
	else
		subtitle.Text = ""
	end
	mapStory.Text = map and map.Description or ""
	mapStory.TextColor3 = SUBTLE
	if map and not LevelData.IsMapUnlocked(map, cleared) then
		mapStory.Text = "Beat " .. LevelData.Get(map.Levels[1].Requires).FullName .. " to unlock this map."
		mapStory.TextColor3 = GOLD
	end

	-- the map list
	for _, m in ipairs(LevelData.Maps) do
		local c = mapCards[m.Id]
		local beaten = 0
		for _, level in ipairs(m.Levels) do
			local isCleared = LevelData.IsCleared(cleared, level.Id)
			if isCleared then beaten += 1 end
			c.Pips[level.Id].BackgroundTransparency = isCleared and 0 or 0.8
		end
		if LevelData.IsMapUnlocked(m, cleared) then
			c.Progress.Text = string.format("%d / %d cleared", beaten, #m.Levels)
			c.Progress.TextColor3 = beaten == #m.Levels and CLEARED or SUBTLE
			c.Names.Text = c.NamesText
			c.Names.TextColor3 = LOCKED
		else
			c.Progress.Text = "LOCKED"
			c.Progress.TextColor3 = LOCKED
			c.Names.Text = "Beat " .. LevelData.Get(m.Levels[1].Requires).FullName .. " to unlock"
			c.Names.TextColor3 = GOLD
		end
		local isPickedMap = pickedLevel ~= nil and pickedLevel.MapId == m.Id
		c.Stroke.Enabled = isPickedMap
		c.Frame.BackgroundColor3 = isPickedMap and CARD_PICKED or CARD
		c.Tag.Text = isPickedMap and ("SELECTED: " .. string.upper(pickedLevel.Difficulty)) or ""
	end

	-- the open map's difficulties
	for id, c in pairs(levelCards) do
		local level = c.Level
		local onOpenMap = map ~= nil and level.MapId == map.Id
		c.Frame.Visible = onOpenMap
		if onOpenMap then
			local unlocked = LevelData.IsUnlocked(level, cleared)
			local isPicked = id == picked
			c.Stroke.Enabled = isPicked
			c.Frame.BackgroundColor3 = isPicked and CARD_PICKED or CARD
			c.Frame.AutoButtonColor = isHost and unlocked and not running
			if isPicked then
				c.Tag.Text = "SELECTED"
				c.Tag.TextColor3 = GOLD
			elseif not unlocked then
				-- (a map's first difficulty can need another map: the line above the list says which)
				local need = LevelData.Get(level.Requires)
				c.Tag.Text = need.MapId == level.MapId and ("LOCKED - beat " .. need.Difficulty) or "LOCKED"
				c.Tag.TextColor3 = LOCKED
			elseif LevelData.IsCleared(cleared, id) then
				c.Tag.Text = "CLEARED"
				c.Tag.TextColor3 = CLEARED
			else
				c.Tag.Text = ""
			end
		end
	end

	startButton.Visible = isHost and picked ~= 0 and not running
	if running then
		status.Text = "Match in progress..."
	elseif pickedLevel and countdown >= 0 then
		status.Text = string.format("%s picked - starting in %ds", pickedLevel.FullName, countdown)
	elseif isHost then
		status.Text = map and "Click a difficulty to pick it." or "Click a map to see its difficulties."
	else
		status.Text = "Waiting for " .. (hostName ~= "" and hostName or "the host") .. " to pick..."
	end
end

local padConnections = {}
local function watchPad(pad)
	for _, c in ipairs(padConnections) do c:Disconnect() end
	table.clear(padConnections)
	currentPad = pad
	openMapId = nil -- a new pad starts on the map list
	lastPicked = 0
	if pad then
		table.insert(padConnections, pad.AttributeChanged:Connect(refresh))
		refresh()
	end
end
player:GetAttributeChangedSignal("ClearedLevels"):Connect(refresh)

-- Which pad are you standing on? (the same check the server uses to queue you)
local function padUnderPlayer()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or player:GetAttribute("InMatch") then return nil end
	for _, pad in ipairs(padsFolder:GetChildren()) do
		if pad:IsA("BasePart") and string.match(pad.Name, "^Pad%d+$") then
			local rel = pad.CFrame:PointToObjectSpace(hrp.Position)
			if math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2 and rel.Y > -2 and rel.Y < 8 then
				return pad
			end
		end
	end
	return nil
end

task.spawn(function()
	while true do
		task.wait(0.2)
		local pad = padUnderPlayer()
		if pad ~= currentPad then
			watchPad(pad)
		end
		if not pad then
			closedPad = nil
		end
		gui.Enabled = pad ~= nil and pad ~= closedPad
	end
end)
