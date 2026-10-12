-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: GachaUI
-- (replaces the earlier version: a redesigned event banner with a featured-unit showcase,
--  drop rates, a pity bar, an event countdown and animated result cards)
-- The summon window pops up when you walk onto the lobby's Summon Altar and closes
-- when you step off (or press the X).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local summonRemote = ReplicatedStorage:WaitForChild("SummonRemote")
local player = Players.LocalPlayer

local PITY_THRESHOLD = 50 -- keep in sync with GachaService
local WIDTH, HEIGHT = 640, 500

local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(22, 20, 38)
local PANEL_LIGHT = Color3.fromRGB(34, 31, 56)
local GOLD = Color3.fromRGB(255, 205, 90)
local SUBTLE = Color3.fromRGB(185, 180, 215)

local event = UnitData.Event
local featuredName = event and event.Featured
local featuredRarity = featuredName and UnitData.UnitRarity[featuredName]
local featuredColor = featuredRarity and UnitData.RarityColor[featuredRarity] or GOLD

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
	l.RichText = true
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
gui.Name = "GachaGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")

local window = frame(gui, UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2), UDim2.fromOffset(WIDTH, HEIGHT), PANEL)
window.Visible = false
corner(window, 14)
local windowStroke = stroke(window, WHITE, 2)
local windowGlow = gradient(windowStroke, featuredColor, GOLD) -- spun every frame below

-- Shrink the whole window on small screens (phones)
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
gradient(header, featuredColor:Lerp(Color3.new(0, 0, 0), 0.25), Color3.fromRGB(70, 40, 150), 0)
-- square off the header's bottom corners
local headerFill = frame(header, UDim2.new(0, 0, 1, -14), UDim2.new(1, 0, 0, 14), WHITE)
gradient(headerFill, featuredColor:Lerp(Color3.new(0, 0, 0), 0.25), Color3.fromRGB(70, 40, 150), 0)

local title = label(header, "", UDim2.fromOffset(18, 6), UDim2.new(1, -70, 0, 28), 24, WHITE, Enum.Font.GothamBlack)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextStrokeTransparency = 0.6
local subtitle = label(header, "", UDim2.fromOffset(18, 32), UDim2.new(1, -70, 0, 20), 14, Color3.fromRGB(255, 235, 240))
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -46, 0, 12)
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextSize = 16
close.TextColor3 = WHITE
close.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
close.BackgroundTransparency = 0.55
close.Parent = header
corner(close, 17)
close.Activated:Connect(function()
	window.Visible = false
end)

-- ===== Featured showcase (left) =====
local showcase = frame(window, UDim2.fromOffset(16, 72), UDim2.fromOffset(300, 256), WHITE)
corner(showcase, 12)
gradient(showcase, Color3.fromRGB(40, 12, 40), featuredColor:Lerp(Color3.new(0, 0, 0), 0.55), 90)
local showcaseStroke = stroke(showcase, WHITE, 3)
local showcaseGlow = gradient(showcaseStroke, featuredColor, GOLD)

local tag = frame(showcase, UDim2.fromOffset(12, 12), UDim2.fromOffset(150, 24), GOLD)
corner(tag, 12)
local tagText = label(tag, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 13, Color3.fromRGB(60, 30, 10), Enum.Font.GothamBlack)

-- A glowing "portrait" emblem: soft halo + spinning star
local halo = frame(showcase, UDim2.new(0.5, -60, 0, 44), UDim2.fromOffset(120, 120), featuredColor)
halo.BackgroundTransparency = 0.55
corner(halo, 60)
-- fades out to one side; spinning it makes the halo shimmer
local haloGradient = Instance.new("UIGradient")
haloGradient.Transparency = NumberSequence.new(0, 1)
haloGradient.Parent = halo

local star = label(showcase, "★", UDim2.new(0.5, -50, 0, 54), UDim2.fromOffset(100, 100), 92, WHITE, Enum.Font.GothamBlack)
star.TextStrokeTransparency = 0.3
star.TextStrokeColor3 = featuredColor
gradient(star, GOLD, WHITE, 90)

local featuredLabel = label(showcase, "", UDim2.fromOffset(10, 164), UDim2.new(1, -20, 0, 28), 22, WHITE, Enum.Font.GothamBlack)
featuredLabel.TextStrokeTransparency = 0.5
featuredLabel.TextStrokeColor3 = featuredColor
local featuredInfo = label(showcase, "", UDim2.fromOffset(10, 192), UDim2.new(1, -20, 0, 18), 13, featuredColor)
local featuredStats = label(showcase, "", UDim2.fromOffset(10, 212), UDim2.new(1, -20, 0, 36), 13, SUBTLE, Enum.Font.Gotham)

-- ===== Info column (right) =====
local info = frame(window, UDim2.fromOffset(328, 72), UDim2.fromOffset(296, 256), PANEL_LIGHT)
corner(info, 12)

local gemsLabel = label(info, "", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 26), 20, Color3.fromRGB(130, 220, 255), Enum.Font.GothamBlack)
gemsLabel.TextXAlignment = Enum.TextXAlignment.Left

local pityLabel = label(info, "", UDim2.fromOffset(14, 42), UDim2.new(1, -28, 0, 18), 13, SUBTLE)
pityLabel.TextXAlignment = Enum.TextXAlignment.Left
local pityBack = frame(info, UDim2.fromOffset(14, 62), UDim2.new(1, -28, 0, 10), Color3.fromRGB(15, 14, 26))
corner(pityBack, 5)
local pityFill = frame(pityBack, UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), WHITE)
corner(pityFill, 5)
gradient(pityFill, UnitData.RarityColor.Legendary, UnitData.RarityColor.Mythic, 0)

local ratesTitle = label(info, "DROP RATES", UDim2.fromOffset(14, 84), UDim2.new(1, -28, 0, 18), 13, SUBTLE, Enum.Font.GothamBlack)
ratesTitle.TextXAlignment = Enum.TextXAlignment.Left

local totalWeight = 0
for _, r in ipairs(UnitData.Rarities) do
	totalWeight += r.Weight
end

local function rarityPercent(rarityName)
	for _, r in ipairs(UnitData.Rarities) do
		if r.Name == rarityName then
			return r.Weight / totalWeight * 100
		end
	end
	return 0
end

local rateRows = {}
for i = #UnitData.Rarities, 1, -1 do
	table.insert(rateRows, UnitData.Rarities[i]) -- rarest first
end
for i, r in ipairs(rateRows) do
	local y = 104 + (i - 1) * 24
	local dot = frame(info, UDim2.fromOffset(16, y + 6), UDim2.fromOffset(10, 10), r.Color)
	corner(dot, 5)
	local name = label(info, r.Name, UDim2.fromOffset(34, y), UDim2.fromOffset(140, 22), 14, r.Color)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local pct = label(info, string.format("%.1f%%", rarityPercent(r.Name)), UDim2.new(1, -94, 0, y), UDim2.fromOffset(80, 22), 14, WHITE)
	pct.TextXAlignment = Enum.TextXAlignment.Right
end
local featuredRateLabel = label(info, "", UDim2.fromOffset(14, 104 + #rateRows * 24 + 4), UDim2.new(1, -28, 0, 30), 12, GOLD)
featuredRateLabel.TextXAlignment = Enum.TextXAlignment.Left

-- ===== Results =====
local resultsArea = frame(window, UDim2.fromOffset(16, 340), UDim2.new(1, -32, 0, 94), PANEL_LIGHT)
corner(resultsArea, 10)
local resultsHint = label(resultsArea, "Your summons will appear here", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14, SUBTLE, Enum.Font.Gotham)

local resultsGrid = frame(resultsArea, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 1, -12), WHITE)
resultsGrid.BackgroundTransparency = 1
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.2, -5, 0.5, -3)
grid.CellPadding = UDim2.fromOffset(6, 6)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = resultsGrid

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
	label(btn, sub, UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 18), 13, Color3.fromRGB(230, 240, 255))
	return btn
end

local single = summonButton("SUMMON x1", "100 gems", UDim2.fromOffset(16, 442),
	Color3.fromRGB(90, 110, 240), Color3.fromRGB(120, 80, 230))
local ten = summonButton("SUMMON x10", "900 gems  -  save 10%", UDim2.new(0.5, 6, 0, 442),
	featuredColor, Color3.fromRGB(230, 120, 60))

-- ===== Live text: event state, gems, pity =====
local function formatTimeLeft(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	if d > 0 then return string.format("%dd %dh", d, h) end
	if h > 0 then return string.format("%dh %dm", h, m) end
	return string.format("%dm %ds", m, seconds % 60)
end

local celebrateUntil = 0 -- while this is in the future, the subtitle shows "You summoned ..."

local function refreshEvent()
	local active = UnitData.IsEventActive() and featuredRarity ~= nil
	if active then
		title.Text = string.upper(event.Name)
		if os.clock() >= celebrateUntil then
			subtitle.Text = event.EndsAt
				and ("Limited banner  -  ends in " .. formatTimeLeft(event.EndsAt - os.time()))
				or "Limited banner  -  for a limited time only!"
		end
		tagText.Text = "LIMITED  " .. featuredRarity:upper()
		featuredLabel.Text = featuredName
		featuredInfo.Text = string.format("%s  -  RATE UP!", featuredRarity)
		featuredRateLabel.Text = string.format("%s: %.0f%% of %s pulls (%.2f%% per summon)",
			featuredName, event.RateUp * 100, featuredRarity, event.RateUp * rarityPercent(featuredRarity))
	else
		title.Text = "STANDARD BANNER"
		subtitle.Text = event and (event.Name .. " has ended. Thanks for playing!") or "Summon new units!"
		tagText.Text = "EVENT ENDED"
		featuredLabel.Text = featuredName or ""
		featuredInfo.Text = "No longer summonable"
		featuredRateLabel.Text = ""
	end
	tag.BackgroundColor3 = active and GOLD or Color3.fromRGB(120, 120, 130)
	star.TextTransparency = active and 0 or 0.6
end

local function refreshPlayerInfo()
	local gems = player:GetAttribute("Gems") or 0
	local pity = player:GetAttribute("Pity") or 0
	gemsLabel.Text = string.format("%d gems", gems)
	pityLabel.Text = string.format("Pity  %d / %d  -  guaranteed Legendary+ at %d", pity, PITY_THRESHOLD, PITY_THRESHOLD)
	pityFill.Size = UDim2.fromScale(math.clamp(pity / PITY_THRESHOLD, 0, 1), 1)
end

if featuredName then
	local s = UnitData.GetStats(featuredName)
	featuredStats.Text = string.format("DMG %d   RNG %d   %.2fs attack\n%s", s.Damage, s.Range, s.Cooldown, event.Tagline or "")
else
	showcase.Visible = false
end

refreshEvent()
refreshPlayerInfo()
player:GetAttributeChangedSignal("Gems"):Connect(refreshPlayerInfo)
player:GetAttributeChangedSignal("Pity"):Connect(refreshPlayerInfo)

-- Countdown ticks once a second
task.spawn(function()
	while true do
		task.wait(1)
		if window.Visible then refreshEvent() end
	end
end)

-- Shimmer: spin the border gradients and gently pulse the star while the window is open
local t = 0
RunService.RenderStepped:Connect(function(dt)
	if not window.Visible then return end
	t += dt
	windowGlow.Rotation = (t * 60) % 360
	showcaseGlow.Rotation = (t * 120) % 360
	haloGradient.Rotation = (t * 40) % 360
	star.Rotation = math.sin(t * 1.5) * 8
	star.TextSize = 92 + math.sin(t * 3) * 6
end)

-- ===== Results cards =====
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

local function addResultCard(unit, order)
	local color = UnitData.RarityColor[unit.Rarity]
	local card = frame(resultsGrid, UDim2.new(), UDim2.new(), color:Lerp(Color3.new(0, 0, 0), 0.55))
	card.LayoutOrder = order
	card.BackgroundTransparency = 1
	corner(card, 8)
	local s = stroke(card, unit.Featured and GOLD or color, unit.Featured and 3 or 1.5)
	s.Transparency = 1

	local name = label(card, (unit.Featured and "★ " or "") .. unit.Name, UDim2.fromOffset(4, 2), UDim2.new(1, -8, 0.6, 0), 12, WHITE)
	name.TextTransparency = 1
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local sub = label(card, unit.AutoDeleted and "auto-deleted" or unit.Rarity, UDim2.new(0, 4, 0.58, 0), UDim2.new(1, -8, 0.4, -2), 11,
		unit.AutoDeleted and Color3.fromRGB(150, 150, 160) or color)
	sub.TextTransparency = 1

	local tween = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(card, tween, { BackgroundTransparency = unit.AutoDeleted and 0.5 or 0 }):Play()
	TweenService:Create(s, tween, { Transparency = 0 }):Play()
	TweenService:Create(name, tween, { TextTransparency = unit.AutoDeleted and 0.5 or 0 }):Play()
	TweenService:Create(sub, tween, { TextTransparency = 0 }):Play()
end

-- ===== Summoning =====
local busy = false
local function doSummon(count)
	if busy then return end
	busy = true
	local ok, res = pcall(function()
		return summonRemote:InvokeServer(count)
	end)
	if not ok or type(res) ~= "table" then
		showMessage("Couldn't reach the server. Try again.")
	elseif not res.Success then
		showMessage(res.Error or "That didn't work.")
	else
		clearResults()
		resultsHint.Visible = false
		local gotFeatured = false
		for i, unit in ipairs(res.Results) do
			addResultCard(unit, i)
			gotFeatured = gotFeatured or unit.Featured
			task.wait(0.06) -- cards pop in one after another
		end
		if gotFeatured then
			celebrateUntil = os.clock() + 4
			subtitle.Text = "★ You summoned " .. featuredName .. "! ★"
		end
	end
	busy = false
end

single.Activated:Connect(function() doSummon(1) end)
ten.Activated:Connect(function() doSummon(10) end)

-- ===== Open on the altar, close when you step off =====
local altar = workspace:WaitForChild("Lobby"):WaitForChild("SummonAltar")
task.spawn(function()
	local wasOn = false
	while true do
		task.wait(0.2)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local on = false
		if hrp and not player:GetAttribute("InMatch") then
			local rel = altar.CFrame:PointToObjectSpace(hrp.Position)
			on = math.abs(rel.X) <= altar.Size.X / 2
				and math.abs(rel.Z) <= altar.Size.Z / 2
				and rel.Y > -2 and rel.Y < 8
		end
		if on and not wasOn then
			refreshEvent()
			window.Visible = true
		elseif not on and wasOn then
			window.Visible = false
		end
		wasOn = on
	end
end)

-- Never leave the window open during a match
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		window.Visible = false
	end
end)
