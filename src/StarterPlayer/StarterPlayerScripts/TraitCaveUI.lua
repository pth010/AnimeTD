-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: TraitCaveUI
-- The Traits Cave window: summon trait enchantments for Gold. They go into your enchantment
-- bag; put them on units with the Enchant button in the Inventory.
-- Pops up when you walk into the lobby's Traits Cave and closes when you walk out (or press X).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local inventoryRemote = ReplicatedStorage:WaitForChild("InventoryRemote")
local player = Players.LocalPlayer

local WIDTH, HEIGHT = 640, 500

local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(16, 24, 34)
local PANEL_LIGHT = Color3.fromRGB(26, 38, 52)
local TEAL = Color3.fromRGB(80, 230, 220)
local PURPLE = Color3.fromRGB(170, 100, 255)
local GOLD = Color3.fromRGB(255, 205, 90)
local SUBTLE = Color3.fromRGB(175, 200, 215)

-- ===== Small builders =====
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function gradient(parent, a, b, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

local function label(parent, text, pos, size, textSize, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = text
	l.TextColor3 = color or WHITE
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function frame(parent, pos, size, color)
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- ===== Window =====
local gui = Instance.new("ScreenGui")
gui.Name = "TraitCaveGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")

local window = frame(gui, UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2), UDim2.fromOffset(WIDTH, HEIGHT), PANEL)
window.Visible = false
corner(window, 14)
gradient(stroke(window, WHITE, 2), TEAL, PURPLE)

local uiScale = Instance.new("UIScale")
uiScale.Parent = window
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(1, (vp.X - 20) / WIDTH, (vp.Y - 40) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

-- Header
local header = frame(window, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 58), WHITE)
corner(header, 14)
gradient(header, Color3.fromRGB(20, 120, 130), Color3.fromRGB(90, 50, 160), 0)
local headerFill = frame(header, UDim2.new(0, 0, 1, -14), UDim2.new(1, 0, 0, 14), WHITE)
gradient(headerFill, Color3.fromRGB(20, 120, 130), Color3.fromRGB(90, 50, 160), 0)

local title = label(header, "TRAITS CAVE", UDim2.fromOffset(18, 6), UDim2.new(1, -70, 0, 28), 24, WHITE, Enum.Font.GothamBlack)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextStrokeTransparency = 0.6
local subtitle = label(header, "Summon trait enchantments, then Enchant your units in the Inventory",
	UDim2.fromOffset(18, 32), UDim2.new(1, -70, 0, 20), 14, Color3.fromRGB(225, 250, 250))
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -46, 0, 12)
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextSize = 16
close.TextColor3 = WHITE
close.BackgroundColor3 = Color3.new(0, 0, 0)
close.BackgroundTransparency = 0.55
close.Parent = header
corner(close, 17)
close.Activated:Connect(function()
	window.Visible = false
end)

-- ===== Odds (left) =====
local oddsPanel = frame(window, UDim2.fromOffset(16, 72), UDim2.fromOffset(300, 256), PANEL_LIGHT)
corner(oddsPanel, 12)
local oddsTitle = label(oddsPanel, "ODDS", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 18), 13, SUBTLE, Enum.Font.GothamBlack)
oddsTitle.TextXAlignment = Enum.TextXAlignment.Left

local oddsList = Instance.new("ScrollingFrame")
oddsList.Position = UDim2.fromOffset(8, 30)
oddsList.Size = UDim2.new(1, -16, 1, -38)
oddsList.BackgroundTransparency = 1
oddsList.BorderSizePixel = 0
oddsList.ScrollBarThickness = 5
oddsList.CanvasSize = UDim2.new()
oddsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
oddsList.Parent = oddsPanel
local oddsLayout = Instance.new("UIListLayout")
oddsLayout.Padding = UDim.new(0, 3)
oddsLayout.SortOrder = Enum.SortOrder.LayoutOrder
oddsLayout.Parent = oddsList

local row = 0
for i = #TraitData.Tiers, 1, -1 do -- rarest first
	local tier = TraitData.Tiers[i]
	for _, trait in ipairs(TraitData.Traits) do
		if trait.Tier == tier.Name then
			row += 1
			local r = frame(oddsList, UDim2.new(), UDim2.new(1, -8, 0, 34), tier.Color:Lerp(Color3.new(0, 0, 0), 0.78))
			r.LayoutOrder = row
			corner(r, 6)
			local name = label(r, trait.Name, UDim2.fromOffset(8, 2), UDim2.new(1, -70, 0, 16), 13, tier.Color)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local desc = label(r, TraitData.Describe(trait.Name), UDim2.fromOffset(8, 17), UDim2.new(1, -70, 0, 14), 11, SUBTLE, Enum.Font.Gotham)
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.TextTruncate = Enum.TextTruncate.AtEnd
			local pct = label(r, TraitData.ChanceText(trait.Name), UDim2.new(1, -64, 0, 0), UDim2.new(0, 56, 1, 0), 13, WHITE)
			pct.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
end

-- ===== Gold and your bag (right) =====
local info = frame(window, UDim2.fromOffset(328, 72), UDim2.fromOffset(296, 256), PANEL_LIGHT)
corner(info, 12)

local goldLabel = label(info, "", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 26), 20, GOLD, Enum.Font.GothamBlack)
goldLabel.TextXAlignment = Enum.TextXAlignment.Left

local bagTitle = label(info, "YOUR ENCHANTMENTS", UDim2.fromOffset(14, 44), UDim2.new(1, -28, 0, 18), 13, SUBTLE, Enum.Font.GothamBlack)
bagTitle.TextXAlignment = Enum.TextXAlignment.Left

local tierRows = {}
for i = #TraitData.Tiers, 1, -1 do
	local tier = TraitData.Tiers[i]
	local y = 66 + (#TraitData.Tiers - i) * 24
	corner(frame(info, UDim2.fromOffset(16, y + 6), UDim2.fromOffset(10, 10), tier.Color), 5)
	local name = label(info, tier.Name, UDim2.fromOffset(34, y), UDim2.fromOffset(140, 22), 14, tier.Color)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local count = label(info, "0", UDim2.new(1, -94, 0, y), UDim2.fromOffset(80, 22), 14, WHITE)
	count.TextXAlignment = Enum.TextXAlignment.Right
	tierRows[tier.Name] = count
end
local bagHint = label(info, "In your bag, not on a unit yet. Open the Inventory and press Enchant on a unit to use one.",
	UDim2.fromOffset(14, 66 + #TraitData.Tiers * 24 + 4), UDim2.new(1, -28, 0, 48), 12, SUBTLE, Enum.Font.Gotham)
bagHint.TextXAlignment = Enum.TextXAlignment.Left
bagHint.TextYAlignment = Enum.TextYAlignment.Top

local function refreshInfo()
	goldLabel.Text = string.format("%d Gold", player:GetAttribute("Gold") or 0)
	local perTier = {}
	for traitName, n in pairs(TraitData.ParseBag(player:GetAttribute("Enchants"))) do
		local tier = TraitData.Get(traitName).Tier
		perTier[tier] = (perTier[tier] or 0) + n
	end
	for tierName, l in pairs(tierRows) do
		l.Text = tostring(perTier[tierName] or 0)
	end
end
refreshInfo()
player:GetAttributeChangedSignal("Gold"):Connect(refreshInfo)
player:GetAttributeChangedSignal("Enchants"):Connect(refreshInfo)

-- ===== Results =====
local resultsArea = frame(window, UDim2.fromOffset(16, 340), UDim2.new(1, -32, 0, 94), PANEL_LIGHT)
corner(resultsArea, 10)
local resultsHint = label(resultsArea, "Your enchantments will appear here", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14, SUBTLE, Enum.Font.Gotham)

local resultsGrid = frame(resultsArea, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 1, -12), WHITE)
resultsGrid.BackgroundTransparency = 1
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.2, -5, 0.5, -3)
grid.CellPadding = UDim2.fromOffset(6, 6)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = resultsGrid

local function clearResults()
	for _, c in ipairs(resultsGrid:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

local function showMessage(text)
	clearResults()
	resultsHint.Text = text
	resultsHint.TextColor3 = Color3.fromRGB(255, 130, 130)
	resultsHint.Visible = true
end

local function addResultCard(traitName, order)
	local trait = TraitData.Get(traitName)
	local big = trait.Tier == "Mythic" or trait.Tier == "Legendary"
	local card = frame(resultsGrid, UDim2.new(), UDim2.new(), trait.Color:Lerp(Color3.new(0, 0, 0), 0.6))
	card.LayoutOrder = order
	card.BackgroundTransparency = 1
	corner(card, 8)
	local s = stroke(card, big and GOLD or trait.Color, big and 3 or 1.5)
	s.Transparency = 1

	local name = label(card, (big and "★ " or "") .. trait.Name, UDim2.fromOffset(4, 2), UDim2.new(1, -8, 0.6, 0), 12, WHITE)
	name.TextTransparency = 1
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local sub = label(card, trait.Tier, UDim2.new(0, 4, 0.58, 0), UDim2.new(1, -8, 0.4, -2), 11, trait.Color)
	sub.TextTransparency = 1

	local tween = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(card, tween, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(s, tween, { Transparency = 0 }):Play()
	TweenService:Create(name, tween, { TextTransparency = 0 }):Play()
	TweenService:Create(sub, tween, { TextTransparency = 0 }):Play()
end

-- ===== Buttons =====
local function summonButton(text, sub, pos, a, b)
	local btn = Instance.new("TextButton")
	btn.Position = pos
	btn.Size = UDim2.new(0.5, -22, 0, 48)
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.BackgroundColor3 = WHITE
	btn.Parent = window
	corner(btn, 10)
	gradient(btn, a, b, 0)
	label(btn, text, UDim2.fromOffset(0, 4), UDim2.new(1, 0, 0, 24), 19, WHITE, Enum.Font.GothamBlack).TextStrokeTransparency = 0.6
	label(btn, sub, UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 18), 13, Color3.fromRGB(230, 250, 250))
	return btn
end

local single = summonButton("SUMMON x1", string.format("%d Gold", TraitData.SummonCost), UDim2.fromOffset(16, 442),
	Color3.fromRGB(20, 150, 160), Color3.fromRGB(40, 110, 200))
local ten = summonButton("SUMMON x10", string.format("%d Gold  -  save 10%%", TraitData.TenSummonCost), UDim2.new(0.5, 6, 0, 442),
	Color3.fromRGB(120, 70, 220), Color3.fromRGB(220, 80, 160))

local busy = false
local function doSummon(count)
	if busy then return end
	busy = true
	local ok, res = pcall(function()
		return inventoryRemote:InvokeServer("SummonEnchant", "", count)
	end)
	if not ok or type(res) ~= "table" then
		showMessage("Couldn't reach the server. Try again.")
	elseif not res.Success then
		showMessage(res.Error or "That didn't work.")
	else
		clearResults()
		resultsHint.Visible = false
		for i, traitName in ipairs(res.Results or {}) do
			addResultCard(traitName, i)
			task.wait(0.06) -- cards pop in one after another
		end
	end
	busy = false
end

single.Activated:Connect(function() doSummon(1) end)
ten.Activated:Connect(function() doSummon(10) end)

-- ===== Open inside the cave, close when you walk out =====
local trigger = workspace:WaitForChild("Lobby"):WaitForChild("TraitCave", 30)
if not trigger then
	warn("[TraitCaveUI] Lobby.TraitCave not found, the Traits Cave window is disabled.")
	return
end
task.spawn(function()
	local wasIn = false
	while true do
		task.wait(0.2)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local inside = false
		if hrp and not player:GetAttribute("InMatch") then
			local rel = trigger.CFrame:PointToObjectSpace(hrp.Position)
			inside = math.abs(rel.X) <= trigger.Size.X / 2
				and math.abs(rel.Z) <= trigger.Size.Z / 2
				and rel.Y > -2 and rel.Y < 8
		end
		if inside and not wasIn then
			refreshInfo()
			window.Visible = true
		elseif not inside and wasIn then
			window.Visible = false
		end
		wasIn = inside
	end
end)

-- Never leave the window open during a match
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		window.Visible = false
	end
end)
