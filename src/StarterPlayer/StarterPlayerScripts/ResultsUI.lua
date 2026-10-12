-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: ResultsUI
-- The end-of-match screen (victory or defeat). Shows the waves reached, the rewards you
-- earned and a damage summary for every player in the match, with two buttons:
--   PLAY AGAIN       - the team replays once everyone left on the screen has picked it
--   RETURN TO LOBBY  - go back to the lobby straight away
-- After 30 seconds, players who picked Play Again replay and everyone else returns to the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local resultsEvent = ReplicatedStorage:WaitForChild("ResultsEvent")
local player = Players.LocalPlayer

local WIDTH, HEIGHT = 580, 500
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(22, 20, 38)
local PANEL_LIGHT = Color3.fromRGB(34, 31, 56)
local SUBTLE = Color3.fromRGB(185, 180, 215)
local GOLD = Color3.fromRGB(255, 205, 70)
local GEM = Color3.fromRGB(130, 220, 255)
local WIN_COLOR = Color3.fromRGB(255, 205, 70)
local LOSE_COLOR = Color3.fromRGB(235, 80, 80)

-- 1234567 -> "1,234,567"
local function commas(n)
	local s = tostring(math.floor(n))
	local sign, digits = string.match(s, "^(-?)(%d+)$")
	if not digits then return s end
	return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
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
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- ===== Screen =====
local gui = Instance.new("ScreenGui")
gui.Name = "ResultsGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.45
dim.Active = true -- clicks don't fall through to the arena
dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(WIDTH, HEIGHT)
panel.BackgroundColor3 = PANEL
panel.Parent = dim
corner(panel, 16)
local panelStroke = Instance.new("UIStroke")
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Thickness = 3
panelStroke.Parent = panel

local uiScale = Instance.new("UIScale")
uiScale.Parent = panel
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(1, (vp.X - 20) / WIDTH, (vp.Y - 20) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local title = label(panel, "", UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 50), 44, WHITE, Enum.Font.GothamBlack)
title.TextStrokeTransparency = 0.5
local subtitle = label(panel, "", UDim2.fromOffset(0, 64), UDim2.new(1, 0, 0, 22), 16, SUBTLE)

-- Rewards
local rewards = Instance.new("Frame")
rewards.Position = UDim2.fromOffset(20, 96)
rewards.Size = UDim2.new(1, -40, 0, 44)
rewards.BackgroundColor3 = PANEL_LIGHT
rewards.Parent = panel
corner(rewards, 10)
local goldText = label(rewards, "", UDim2.fromScale(0, 0), UDim2.fromScale(0.5, 1), 22, GOLD, Enum.Font.GothamBlack)
local gemsText = label(rewards, "", UDim2.fromScale(0.5, 0), UDim2.fromScale(0.5, 1), 22, GEM, Enum.Font.GothamBlack)

-- Damage summary
label(panel, "DAMAGE SUMMARY", UDim2.fromOffset(24, 152), UDim2.fromOffset(240, 20), 14, SUBTLE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
local headerY = 176
label(panel, "PLAYER", UDim2.fromOffset(60, headerY), UDim2.fromOffset(150, 16), 12, SUBTLE, nil, Enum.TextXAlignment.Left)
label(panel, "DAMAGE", UDim2.fromOffset(330, headerY), UDim2.fromOffset(100, 16), 12, SUBTLE, nil, Enum.TextXAlignment.Right)
label(panel, "SHARE", UDim2.fromOffset(436, headerY), UDim2.fromOffset(56, 16), 12, SUBTLE, nil, Enum.TextXAlignment.Right)
label(panel, "KILLS", UDim2.fromOffset(496, headerY), UDim2.fromOffset(56, 16), 12, SUBTLE, nil, Enum.TextXAlignment.Right)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(20, 196)
list.Size = UDim2.new(1, -40, 0, 196)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- Status + buttons
local status = label(panel, "", UDim2.fromOffset(0, 400), UDim2.new(1, 0, 0, 22), 15, SUBTLE)

local function button(text, pos, color)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = UDim2.new(0.5, -30, 0, 50)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = WHITE
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 18
	b.Parent = panel
	corner(b, 12)
	return b
end
local againButton = button("PLAY AGAIN", UDim2.fromOffset(20, 432), Color3.fromRGB(60, 160, 90))
local menuButton = button("RETURN TO LOBBY", UDim2.new(0.5, 10, 0, 432), Color3.fromRGB(80, 80, 105))

-- ===== Filling it in =====
local deadline = 0
local teamCount = 1
local votedAgain = false

local function addRow(order, row, maxDamage, totalDamage)
	local isMe = row.UserId == player.UserId
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.Size = UDim2.new(1, -8, 0, 40)
	f.BackgroundColor3 = isMe and Color3.fromRGB(48, 44, 78) or PANEL_LIGHT
	f.Parent = list
	corner(f, 8)
	if isMe then
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = GOLD
		s.Thickness = 2
		s.Parent = f
	end

	local rank = label(f, order == 1 and row.Damage > 0 and "★" or tostring(order), UDim2.fromOffset(6, 0), UDim2.fromOffset(30, 40), 18,
		order == 1 and GOLD or SUBTLE, Enum.Font.GothamBlack)
	rank.TextTruncate = Enum.TextTruncate.None

	label(f, row.Name .. (isMe and "  (you)" or ""), UDim2.fromOffset(40, 3), UDim2.fromOffset(250, 20), 15, WHITE, nil, Enum.TextXAlignment.Left)

	-- a bar showing damage compared to the top player
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromOffset(40, 26)
	barBack.Size = UDim2.fromOffset(250, 7)
	barBack.BackgroundColor3 = Color3.fromRGB(15, 14, 26)
	barBack.BorderSizePixel = 0
	barBack.Parent = f
	corner(barBack, 4)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = order == 1 and GOLD or Color3.fromRGB(110, 140, 255)
	fill.BorderSizePixel = 0
	fill.Parent = barBack
	corner(fill, 4)
	local share = maxDamage > 0 and row.Damage / maxDamage or 0
	TweenService:Create(fill, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(share, 1) }):Play()

	label(f, commas(row.Damage), UDim2.fromOffset(300, 0), UDim2.fromOffset(110, 40), 16, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
	local pct = totalDamage > 0 and math.floor(row.Damage / totalDamage * 100 + 0.5) or 0
	label(f, pct .. "%", UDim2.fromOffset(416, 0), UDim2.fromOffset(56, 40), 15, SUBTLE, nil, Enum.TextXAlignment.Right)
	label(f, tostring(row.Kills), UDim2.fromOffset(476, 0), UDim2.fromOffset(56, 40), 15, WHITE, nil, Enum.TextXAlignment.Right)
end

local function updateStatus()
	local left = math.max(0, math.ceil(deadline - os.clock()))
	if votedAgain then
		local ready = player:GetAttribute("ResultsReady") or 1
		status.Text = string.format("Ready! Waiting for your team (%d/%d)  -  %ds", ready, teamCount, left)
	else
		status.Text = string.format("Returning to the lobby in %ds", left)
	end
end

local function hide()
	gui.Enabled = false
end

local function show(data)
	votedAgain = false
	teamCount = data.TeamCount or 1
	deadline = os.clock() + (data.Time or 30)

	local color = data.Victory and WIN_COLOR or LOSE_COLOR
	title.Text = data.Victory and "VICTORY!" or "DEFEAT"
	title.TextColor3 = color
	panelStroke.Color = color
	subtitle.Text = string.format("Waves cleared: %d / %d", data.Victory and data.MaxWave or math.max(0, (data.Wave or 1) - 1), data.MaxWave or 0)

	goldText.Text = (data.Gold or 0) > 0 and ("+" .. commas(data.Gold) .. " Gold") or "+0 Gold"
	gemsText.Text = "+" .. commas(data.Gems or 0) .. " Gems"

	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local rows = data.Players or {}
	local maxDamage = rows[1] and rows[1].Damage or 0
	for i, row in ipairs(rows) do
		addRow(i, row, maxDamage, data.TotalDamage or 0)
	end

	againButton.Text = "PLAY AGAIN"
	againButton.AutoButtonColor = true
	againButton.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	updateStatus()

	panel.Position = UDim2.fromScale(0.5, 0.56)
	gui.Enabled = true
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

resultsEvent.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.Hide then
		hide()
	else
		show(data)
	end
end)

againButton.Activated:Connect(function()
	if votedAgain or not gui.Enabled then return end
	votedAgain = true
	againButton.Text = "READY!"
	againButton.AutoButtonColor = false
	againButton.BackgroundColor3 = Color3.fromRGB(45, 110, 65)
	resultsEvent:FireServer("Again")
	updateStatus()
end)

menuButton.Activated:Connect(function()
	if not gui.Enabled then return end
	resultsEvent:FireServer("Menu")
	hide()
end)

-- Countdown text
RunService.Heartbeat:Connect(function()
	if gui.Enabled then updateStatus() end
end)

-- Left the match (sent to the lobby, or the time ran out)
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") ~= true then
		hide()
	end
end)
