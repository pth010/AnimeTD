-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: LevelSelectUI
-- (replaces the earlier version: does nothing in the match place, which has no pads)
-- The level-select window that pops up while you stand on a team pad in the lobby.
--   * The first player on the pad (the host) picks the level; locked levels need the one
--     before them beaten first. Picking a level starts the countdown, START skips most of it.
--   * Everyone else on the pad sees which level the host picked and the countdown.
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
local SUBTLE = Color3.fromRGB(185, 180, 215)
local GOLD = Color3.fromRGB(255, 205, 70)
local GEM = Color3.fromRGB(130, 220, 255)
local SHARD = Color3.fromRGB(80, 230, 220) -- same as TraitData.ShardColor
local LOCKED = Color3.fromRGB(110, 105, 130)

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

local list = Instance.new("Frame")
list.Position = UDim2.fromOffset(16, 72)
list.Size = UDim2.new(1, -32, 0, 4 * 80 + 3 * 8)
list.BackgroundTransparency = 1
list.Parent = window
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

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

-- ===== Level cards =====
local cards = {} -- [levelId] = { Frame, Stroke, Tag }
local currentPad = nil
local closedPad = nil -- the pad you closed the window on (it stays closed until you step off)

local function choose(levelId)
	local ok, res = pcall(function()
		return levelRemote:InvokeServer("Select", levelId)
	end)
	if not ok or type(res) ~= "table" then
		flash("Couldn't pick that level. Try again.")
	elseif not res.Success then
		flash(res.Error or "Couldn't pick that level.")
	end
end

for i, level in ipairs(LevelData.Levels) do
	local card = Instance.new("TextButton")
	card.LayoutOrder = i
	card.Size = UDim2.new(1, 0, 0, 80)
	card.BackgroundColor3 = CARD
	card.AutoButtonColor = false
	card.Text = ""
	card.Parent = list
	corner(card, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 3
	stroke.Color = GOLD
	stroke.Enabled = false
	stroke.Parent = card

	-- difficulty color strip down the left side
	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(0, 8, 1, 0)
	strip.BackgroundColor3 = level.Color
	strip.BorderSizePixel = 0
	strip.Parent = card
	corner(strip, 4)

	label(card, level.Name, UDim2.fromOffset(22, 8), UDim2.new(1, -170, 0, 24), 19, WHITE, Enum.Font.GothamBlack)
	label(card, level.Difficulty:upper(), UDim2.fromOffset(22, 32), UDim2.fromOffset(110, 16), 12, level.Color, Enum.Font.GothamBlack)
	label(card, string.format("%d waves   -   enemies x%.1f HP", level.Waves, level.HealthMult),
		UDim2.fromOffset(120, 32), UDim2.new(1, -290, 0, 16), 12, SUBTLE)
	label(card, level.Description, UDim2.fromOffset(22, 52), UDim2.new(1, -170, 0, 18), 12, SUBTLE, Enum.Font.Gotham)

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

	cards[level.Id] = { Frame = card, Stroke = stroke, Tag = tag, Level = level }

	card.Activated:Connect(function()
		if currentPad and currentPad:GetAttribute("Host") == player.UserId then
			choose(level.Id)
		end
	end)
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
local function refresh()
	local pad = currentPad
	if not pad then return end

	local padNumber = string.match(pad.Name, "%d+") or "?"
	local isHost = pad:GetAttribute("Host") == player.UserId
	local hostName = pad:GetAttribute("HostName") or ""
	local picked = pad:GetAttribute("Level") or 0
	local countdown = pad:GetAttribute("Countdown") or -1
	local running = pad:GetAttribute("Running") == true
	local cleared = LevelData.ParseCleared(player:GetAttribute("ClearedLevels"))

	title.Text = "TEAM " .. padNumber .. "  -  CHOOSE A LEVEL"
	windowStroke.Color = pad.Color
	if running then
		subtitle.Text = "This team's match is in progress. Wait here to join the next one."
	elseif isHost then
		subtitle.Text = "You're the host: pick the level your team will play."
	elseif hostName ~= "" then
		subtitle.Text = hostName .. " is the host and picks the level."
	else
		subtitle.Text = ""
	end

	for id, c in pairs(cards) do
		local unlocked = LevelData.IsUnlocked(c.Level, cleared)
		local isPicked = id == picked
		c.Stroke.Enabled = isPicked
		c.Frame.BackgroundColor3 = isPicked and Color3.fromRGB(52, 46, 84) or CARD
		c.Frame.AutoButtonColor = isHost and unlocked and not running
		if isPicked then
			c.Tag.Text = "SELECTED"
			c.Tag.TextColor3 = GOLD
		elseif not unlocked then
			c.Tag.Text = "LOCKED - beat " .. LevelData.Get(c.Level.Requires).Name
			c.Tag.TextColor3 = LOCKED
		elseif cleared[id] then
			c.Tag.Text = "CLEARED"
			c.Tag.TextColor3 = Color3.fromRGB(110, 230, 140)
		else
			c.Tag.Text = ""
		end
	end

	startButton.Visible = isHost and picked ~= 0 and not running
	local level = LevelData.Get(picked)
	if running then
		status.Text = "Match in progress..."
	elseif level and countdown >= 0 then
		status.Text = string.format("%s picked - starting in %ds", level.Name, countdown)
	elseif isHost then
		status.Text = "Click a level to pick it."
	else
		status.Text = "Waiting for " .. (hostName ~= "" and hostName or "the host") .. " to pick a level..."
	end
end

local padConnections = {}
local function watchPad(pad)
	for _, c in ipairs(padConnections) do c:Disconnect() end
	table.clear(padConnections)
	currentPad = pad
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
