-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: TraitCaveUI
-- (replaces the earlier version: lists every unit you own separately, since each copy
--  has its own trait now)
-- The Traits Cave window: pick one of your units, then summon a trait onto it for Trait
-- Shards (won from levels).
-- The unit keeps that trait until you summon on it again (the new trait replaces the old).
-- Pops up when you walk into the lobby's Traits Cave and closes when you walk out (or press X).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local ProgressData = require(ReplicatedStorage:WaitForChild("ProgressData"))
local inventoryRemote = ReplicatedStorage:WaitForChild("InventoryRemote")
local player = Players.LocalPlayer

local WIDTH, HEIGHT = 680, 524

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GLASS = Color3.fromRGB(24, 30, 48)      -- panels sit on the window as dark glass
local TEAL = Color3.fromRGB(80, 230, 220)
local PURPLE = Color3.fromRGB(170, 100, 255)
local PINK = Color3.fromRGB(255, 90, 170)
local GOLD = Color3.fromRGB(255, 205, 90)
local SHARD = TraitData.ShardColor
local SUBTLE = Color3.fromRGB(170, 185, 210)
local DIM = Color3.fromRGB(110, 120, 145)
local ERROR_COLOR = Color3.fromRGB(255, 130, 130)

-- ===== Small builders =====
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius == "round" and UDim.new(1, 0) or UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function gradient(parent, colors, rotation)
	local g = Instance.new("UIGradient")
	g.Color = typeof(colors) == "ColorSequence" and colors or ColorSequence.new(colors[1], colors[2])
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

local function frame(parent, pos, size, color, transparency)
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color or WHITE
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- A small diamond (a square turned 45 degrees)
local function diamond(parent, size, color, transparency)
	local d = frame(parent, UDim2.new(), UDim2.fromOffset(size, size), color, transparency)
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Rotation = 45
	return d
end

local function withCommas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- "1 Trait Shard" / "12 Trait Shards"
local function shardText(n)
	return withCommas(n) .. (n == 1 and " Trait Shard" or " Trait Shards")
end

local function shards()
	return player:GetAttribute("Shards") or 0
end

local function darker(color, amount)
	return color:Lerp(BLACK, amount)
end

-- ===== Window =====
local gui = Instance.new("ScreenGui")
gui.Name = "TraitCaveGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- the odds window draws over everything
gui.Parent = player:WaitForChild("PlayerGui")

local window = frame(gui, UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2), UDim2.fromOffset(WIDTH, HEIGHT), WHITE)
window.Visible = false
corner(window, 18)
gradient(window, { Color3.fromRGB(12, 26, 38), Color3.fromRGB(34, 16, 54) }, 135)
local borderGlow = gradient(stroke(window, WHITE, 2.5), ColorSequence.new({
	ColorSequenceKeypoint.new(0, TEAL),
	ColorSequenceKeypoint.new(0.5, PURPLE),
	ColorSequenceKeypoint.new(1, TEAL),
}))

local uiScale = Instance.new("UIScale")
uiScale.Parent = window
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(1, (vp.X - 20) / WIDTH, (vp.Y - 40) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

-- Faint crystals drifting in the background
local driftCrystals = {}
for i = 1, 9 do
	local d = diamond(window, 6 + (i % 3) * 4, ({ TEAL, PURPLE, PINK })[i % 3 + 1], 0.75)
	d.ZIndex = 0 -- behind the panels
	d.Position = UDim2.fromOffset((i * 73) % WIDTH, (i * 131) % HEIGHT)
	table.insert(driftCrystals, { Frame = d, Speed = 6 + (i % 4) * 3, X = (i * 73) % WIDTH, Y = (i * 131) % HEIGHT })
end

-- ===== Header =====
local icon = diamond(window, 22, WHITE)
icon.Position = UDim2.fromOffset(34, 34)
gradient(icon, { TEAL, PURPLE }, 90)
stroke(icon, WHITE, 1.5, 0.4)

local title = label(window, "TRAITS CAVE", UDim2.fromOffset(56, 14), UDim2.fromOffset(400, 30), 28, WHITE, Enum.Font.GothamBlack)
title.TextXAlignment = Enum.TextXAlignment.Left
gradient(title, { Color3.fromRGB(170, 255, 245), Color3.fromRGB(215, 175, 255) }, 0)
local subtitle = label(window, "Pick a unit and summon a trait onto it. It keeps that trait until you summon again.",
	UDim2.fromOffset(56, 44), UDim2.fromOffset(520, 18), 13, SUBTLE, Enum.Font.Gotham)
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -50, 0, 16)
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextSize = 15
close.TextColor3 = WHITE
close.BackgroundColor3 = BLACK
close.BackgroundTransparency = 0.5
close.Parent = window
corner(close, "round")
stroke(close, WHITE, 1, 0.75)

-- ===== Your units (left) =====
local unitsPanel = frame(window, UDim2.fromOffset(16, 76), UDim2.fromOffset(292, 366), GLASS, 0.25)
corner(unitsPanel, 14)
stroke(unitsPanel, WHITE, 1, 0.88)
local unitsTitle = label(unitsPanel, "YOUR UNITS", UDim2.fromOffset(14, 10), UDim2.fromOffset(150, 16), 12, SUBTLE, Enum.Font.GothamBlack)
unitsTitle.TextXAlignment = Enum.TextXAlignment.Left
local unitsCount = label(unitsPanel, "", UDim2.new(1, -114, 0, 10), UDim2.fromOffset(100, 16), 12, DIM, Enum.Font.Gotham)
unitsCount.TextXAlignment = Enum.TextXAlignment.Right

local unitList = Instance.new("ScrollingFrame")
unitList.Position = UDim2.fromOffset(8, 32)
unitList.Size = UDim2.new(1, -16, 1, -40)
unitList.BackgroundTransparency = 1
unitList.BorderSizePixel = 0
unitList.ScrollBarThickness = 4
unitList.ScrollBarImageColor3 = TEAL
unitList.CanvasSize = UDim2.new()
unitList.AutomaticCanvasSize = Enum.AutomaticSize.Y
unitList.Parent = unitsPanel
local unitLayout = Instance.new("UIListLayout")
unitLayout.Padding = UDim.new(0, 6)
unitLayout.SortOrder = Enum.SortOrder.LayoutOrder
unitLayout.Parent = unitList
local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 2)
listPad.PaddingLeft = UDim.new(0, 2)
listPad.PaddingRight = UDim.new(0, 6)
listPad.Parent = unitList

-- ===== The shrine (right): the picked unit and its summoning circle =====
local shrine = frame(window, UDim2.fromOffset(318, 76), UDim2.fromOffset(346, 366), GLASS, 0.25)
corner(shrine, 14)
stroke(shrine, WHITE, 1, 0.88)
shrine.ClipsDescendants = true

local shardPill = frame(shrine, UDim2.new(1, -150, 0, 12), UDim2.fromOffset(138, 26), darker(SHARD, 0.72))
corner(shardPill, "round")
stroke(shardPill, SHARD, 1.5, 0.3)
local shardIcon = diamond(shardPill, 10, SHARD)
shardIcon.Position = UDim2.fromOffset(15, 13)
local shardLabel = label(shardPill, "", UDim2.fromOffset(26, 0), UDim2.new(1, -32, 1, 0), 12, SHARD, Enum.Font.GothamBlack)
shardLabel.TextXAlignment = Enum.TextXAlignment.Left

local unitName = label(shrine, "", UDim2.fromOffset(16, 10), UDim2.new(1, -176, 0, 24), 20, WHITE, Enum.Font.GothamBlack)
unitName.TextXAlignment = Enum.TextXAlignment.Left
unitName.TextTruncate = Enum.TextTruncate.AtEnd
local unitRarity = label(shrine, "", UDim2.fromOffset(16, 34), UDim2.new(1, -176, 0, 16), 12, SUBTLE)
unitRarity.TextXAlignment = Enum.TextXAlignment.Left

-- the summoning circle
local CIRCLE_CENTER = Vector2.new(173, 166)
local function circle(size, color, transparency)
	local c = frame(shrine, UDim2.fromOffset(CIRCLE_CENTER.X, CIRCLE_CENTER.Y), UDim2.fromOffset(size, size), color, transparency)
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(c, "round")
	return c
end

local glow = circle(196, WHITE, 0.82)           -- soft colored disc behind everything
local outerRing = circle(212, WHITE, 1)
local outerStroke = stroke(outerRing, WHITE, 4)
local outerGradient = gradient(outerStroke, { WHITE, WHITE }, 0)
outerGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0.85),
	NumberSequenceKeypoint.new(1, 0),
})
local innerRing = circle(176, WHITE, 1)
local innerStroke = stroke(innerRing, WHITE, 1.5, 0.35)
local innerGradient = gradient(innerStroke, { WHITE, WHITE }, 0)
innerGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.25, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.75, 1),
	NumberSequenceKeypoint.new(1, 0),
})
local core = circle(160, WHITE, 0.1) -- white, so the gradient below sets its color
local coreGradient = gradient(core, { WHITE, WHITE }, 90)

-- what sits in the middle of the circle
local coreScale = Instance.new("UIScale")
coreScale.Parent = core
local traitCaption = label(core, "CURRENT TRAIT", UDim2.fromOffset(0, 38), UDim2.new(1, 0, 0, 14), 11, SUBTLE, Enum.Font.GothamBlack)
local traitName = label(core, "", UDim2.fromOffset(10, 56), UDim2.new(1, -20, 0, 36), 28, WHITE, Enum.Font.GothamBlack)
traitName.TextScaled = true
local nameSize = Instance.new("UITextSizeConstraint")
nameSize.MaxTextSize = 28
nameSize.Parent = traitName
traitName.TextStrokeTransparency = 0.5
local traitTier = label(core, "", UDim2.fromOffset(0, 96), UDim2.new(1, 0, 0, 16), 13, SUBTLE, Enum.Font.GothamBold)

-- crystals orbiting the circle
local orbiters = {}
for i = 1, 6 do
	local d = diamond(shrine, i % 2 == 0 and 10 or 7, WHITE)
	table.insert(orbiters, d)
end

-- an expanding ring for when a trait lands
local burst = circle(160, WHITE, 1)
local burstStroke = stroke(burst, WHITE, 6, 1)

-- stat chips under the circle ("+100% DMG" "+15% RNG")
local chipRow = frame(shrine, UDim2.fromOffset(12, 284), UDim2.new(1, -24, 0, 26), WHITE, 1)
local chipLayout = Instance.new("UIListLayout")
chipLayout.FillDirection = Enum.FillDirection.Horizontal
chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
chipLayout.Padding = UDim.new(0, 6)
chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
chipLayout.Parent = chipRow

local message = label(shrine, "", UDim2.fromOffset(16, 318), UDim2.new(1, -32, 0, 38), 13, SUBTLE, Enum.Font.Gotham)

-- ===== Buttons =====
local oddsBtn = Instance.new("TextButton")
oddsBtn.Position = UDim2.fromOffset(16, 456)
oddsBtn.Size = UDim2.fromOffset(150, 52)
oddsBtn.Text = "VIEW ODDS"
oddsBtn.Font = Enum.Font.GothamBlack
oddsBtn.TextSize = 15
oddsBtn.TextColor3 = WHITE
oddsBtn.BackgroundColor3 = GLASS
oddsBtn.BackgroundTransparency = 0.15
oddsBtn.Parent = window
corner(oddsBtn, 12)
stroke(oddsBtn, TEAL, 1.5, 0.4)

local summonBtn = Instance.new("TextButton")
summonBtn.Position = UDim2.fromOffset(178, 456)
summonBtn.Size = UDim2.new(1, -194, 0, 52)
summonBtn.Text = ""
summonBtn.AutoButtonColor = true
summonBtn.BackgroundColor3 = WHITE
summonBtn.Parent = window
corner(summonBtn, 12)
local summonGradient = gradient(summonBtn, { TEAL, PURPLE }, 0)
local summonStroke = stroke(summonBtn, WHITE, 1.5, 0.6)
local summonText = label(summonBtn, "", UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 24), 20, WHITE, Enum.Font.GothamBlack)
summonText.TextStrokeTransparency = 0.55
local summonSub = label(summonBtn, "", UDim2.fromOffset(0, 29), UDim2.new(1, 0, 0, 16), 13, Color3.fromRGB(235, 245, 255))
-- a bright band that sweeps across the button
local shine = frame(summonBtn, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE, 0)
corner(shine, 12)
local shineGradient = gradient(shine, { WHITE, WHITE }, 20)
shineGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.42, 1),
	NumberSequenceKeypoint.new(0.5, 0.65),
	NumberSequenceKeypoint.new(0.58, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- ===== Odds window =====
local odds = frame(window, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE)
odds.Active = true
odds.ZIndex = 10
odds.Visible = false
corner(odds, 18)
gradient(odds, { Color3.fromRGB(12, 26, 38), Color3.fromRGB(34, 16, 54) }, 135)
local oddsTitle = label(odds, "TRAIT ODDS", UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 30), 24, WHITE, Enum.Font.GothamBlack)
gradient(oddsTitle, { Color3.fromRGB(170, 255, 245), Color3.fromRGB(215, 175, 255) }, 0)
label(odds, string.format("Each summon costs %s and replaces the unit's current trait.", shardText(TraitData.SummonCost)),
	UDim2.fromOffset(16, 44), UDim2.new(1, -32, 0, 18), 13, SUBTLE, Enum.Font.Gotham)
local oddsClose = close:Clone()
oddsClose.Parent = odds

local oddsList = Instance.new("ScrollingFrame")
oddsList.Position = UDim2.fromOffset(16, 72)
oddsList.Size = UDim2.new(1, -32, 1, -88)
oddsList.BackgroundTransparency = 1
oddsList.BorderSizePixel = 0
oddsList.ScrollBarThickness = 4
oddsList.ScrollBarImageColor3 = TEAL
oddsList.CanvasSize = UDim2.new()
oddsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
oddsList.Parent = odds
local oddsLayout = Instance.new("UIListLayout")
oddsLayout.Padding = UDim.new(0, 4)
oddsLayout.SortOrder = Enum.SortOrder.LayoutOrder
oddsLayout.Parent = oddsList

local row = 0
for i = #TraitData.Tiers, 1, -1 do -- rarest first
	local tier = TraitData.Tiers[i]
	local tierChance = 0
	for _, trait in ipairs(TraitData.Traits) do
		if trait.Tier == tier.Name then tierChance += trait.Chance end
	end
	row += 1
	local head = frame(oddsList, UDim2.new(), UDim2.new(1, -8, 0, 26), WHITE, 1)
	head.LayoutOrder = row
	local headName = label(head, string.upper(tier.Name), UDim2.fromOffset(4, 4), UDim2.fromOffset(200, 20), 14, tier.Color, Enum.Font.GothamBlack)
	headName.TextXAlignment = Enum.TextXAlignment.Left
	local headPct = label(head, (string.format("%.1f", tierChance):gsub("%.0$", "")) .. "% total", UDim2.new(1, -150, 0, 4), UDim2.fromOffset(140, 20), 12, DIM, Enum.Font.Gotham)
	headPct.TextXAlignment = Enum.TextXAlignment.Right
	for _, trait in ipairs(TraitData.Traits) do
		if trait.Tier == tier.Name then
			row += 1
			local r = frame(oddsList, UDim2.new(), UDim2.new(1, -8, 0, 30), darker(tier.Color, 0.8))
			r.LayoutOrder = row
			corner(r, 8)
			stroke(r, tier.Color, 1, 0.7)
			local mark = diamond(r, 8, tier.Color)
			mark.Position = UDim2.fromOffset(14, 15)
			local name = label(r, trait.Name, UDim2.fromOffset(28, 0), UDim2.new(0, 130, 1, 0), 14, tier.Color, Enum.Font.GothamBlack)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local desc = label(r, TraitData.Describe(trait.Name), UDim2.fromOffset(162, 0), UDim2.new(1, -240, 1, 0), 12, SUBTLE, Enum.Font.Gotham)
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.TextTruncate = Enum.TextTruncate.AtEnd
			local pct = label(r, TraitData.ChanceText(trait.Name), UDim2.new(1, -72, 0, 0), UDim2.new(0, 62, 1, 0), 14, WHITE, Enum.Font.GothamBlack)
			pct.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
end

oddsBtn.Activated:Connect(function() odds.Visible = true end)
oddsClose.Activated:Connect(function() odds.Visible = false end)

-- ===== State =====
local selected = nil     -- the picked unit's id
local confirming = false -- true after one click on Summon over a Legendary or Mythic trait
local busy = false       -- waiting on the server or playing the roulette
local ringColor = TEAL   -- the circle's current color (follows the trait's tier)
local spinSpeed = 40     -- degrees per second; the roulette speeds it up

local rarityRank = {}
for i, r in ipairs(UnitData.Rarities) do
	rarityRank[r.Name] = i
end

-- Every unit you own, rarest and strongest first, plus a lookup by id
local function readUnits()
	local list, byId = UnitData.ParseUnits(player:GetAttribute("Units"))
	table.sort(list, function(a, b)
		local ra, rb = rarityRank[UnitData.UnitRarity[a.Name]], rarityRank[UnitData.UnitRarity[b.Name]]
		if ra ~= rb then return ra > rb end
		if a.Name ~= b.Name then return a.Name < b.Name end
		if a.Stars ~= b.Stars then return a.Stars > b.Stars end
		if a.XP ~= b.XP then return a.XP > b.XP end
		return a.Id < b.Id
	end)
	return list, byId
end

local function selectedUnit()
	if not selected then return nil end
	local _, byId = UnitData.ParseUnits(player:GetAttribute("Units"))
	return byId[selected]
end

local function setMessage(text, color)
	message.Text = text
	message.TextColor3 = color or SUBTLE
end

local function currentTrait()
	local u = selectedUnit()
	return u and TraitData.Get(u.Trait) or nil
end

-- Legendary and Mythic traits ask before being replaced
local function isPrecious(trait)
	return trait ~= nil and (trait.Tier == "Legendary" or trait.Tier == "Mythic")
end

local function setRingColor(color)
	ringColor = color
	outerStroke.Color = color
	innerStroke.Color = color
	glow.BackgroundColor3 = color
	coreGradient.Color = ColorSequence.new(darker(color, 0.72), Color3.fromRGB(10, 14, 26))
	for _, d in ipairs(orbiters) do
		d.BackgroundColor3 = color
	end
end

local function setChips(traitNameText)
	for _, c in ipairs(chipRow:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local trait = TraitData.Get(traitNameText)
	if not trait then return end
	local order = 0
	for part in string.gmatch(TraitData.Describe(trait.Name), "[^,]+") do
		part = part:gsub("^%s+", "")
		order += 1
		local chip = frame(chipRow, UDim2.new(), UDim2.fromOffset(#part * 8 + 20, 26), darker(trait.Color, 0.72))
		chip.LayoutOrder = order
		corner(chip, "round")
		stroke(chip, trait.Color, 1, 0.35)
		label(chip, part, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 12, WHITE, Enum.Font.GothamBlack)
	end
end

-- Shows a trait (or "no trait") in the middle of the circle
local function showTrait(trait)
	if trait then
		traitName.Text = trait.Name
		traitName.TextColor3 = trait.Color
		traitTier.Text = string.upper(trait.Tier) .. "  ·  " .. TraitData.ChanceText(trait.Name)
		traitTier.TextColor3 = trait.Color
		setRingColor(trait.Color)
		setChips(trait.Name)
	else
		traitName.Text = selected and "No trait" or "?"
		traitName.TextColor3 = SUBTLE
		traitTier.Text = selected and "Summon to give it one" or "Pick a unit"
		traitTier.TextColor3 = DIM
		setRingColor(TEAL)
		setChips(nil)
	end
end

local function refreshSummonButton()
	local trait = currentTrait()
	if busy then
		summonText.Text = "SUMMONING..."
		summonSub.Text = ""
		summonGradient.Color = ColorSequence.new(PURPLE, PINK)
	elseif not selected then
		summonText.Text = "PICK A UNIT"
		summonSub.Text = "Choose one on the left"
		summonGradient.Color = ColorSequence.new(Color3.fromRGB(70, 78, 100), Color3.fromRGB(60, 64, 88))
	elseif confirming and trait then
		summonText.Text = "REPLACE " .. string.upper(trait.Name) .. "?"
		summonSub.Text = "Click again to summon anyway"
		summonGradient.Color = ColorSequence.new(Color3.fromRGB(220, 100, 60), Color3.fromRGB(200, 50, 100))
	elseif shards() < TraitData.SummonCost then
		summonText.Text = "SUMMON TRAIT"
		summonSub.Text = "Out of Trait Shards. Win levels to earn more"
		summonGradient.Color = ColorSequence.new(Color3.fromRGB(70, 78, 100), Color3.fromRGB(60, 64, 88))
	else
		summonText.Text = "SUMMON TRAIT"
		summonSub.Text = shardText(TraitData.SummonCost)
		summonGradient.Color = ColorSequence.new(TEAL, PURPLE)
	end
end

local function refreshPicked()
	shardLabel.Text = shardText(shards())
	if busy then
		refreshSummonButton()
		return -- the roulette owns the circle right now
	end
	if not selected then
		unitName.Text = "No unit picked"
		unitRarity.Text = "Choose one of your units on the left"
		unitRarity.TextColor3 = SUBTLE
		traitCaption.Text = ""
	else
		local u = selectedUnit()
		local rarityName = u and UnitData.UnitRarity[u.Name] or ""
		unitName.Text = u and u.Name or ""
		unitRarity.Text = u and string.format("%s  ·  Lv %d %s", rarityName, ProgressData.LevelFromXP(u.XP), string.rep("★", u.Stars)) or ""
		unitRarity.TextColor3 = UnitData.RarityColor[rarityName] or SUBTLE
		traitCaption.Text = "CURRENT TRAIT"
	end
	traitCaption.TextColor3 = SUBTLE
	showTrait(currentTrait())
	refreshSummonButton()
end

local refreshUnits -- defined below (rows call it when clicked)

local function makeRow(u, rarity, order)
	local name, traitName_ = u.Name, u.Trait
	local isPicked = u.Id == selected
	local r = Instance.new("TextButton")
	r.LayoutOrder = order
	r.Size = UDim2.new(1, 0, 0, 52)
	r.Text = ""
	r.AutoButtonColor = true
	r.BackgroundColor3 = isPicked and darker(rarity.Color, 0.55) or Color3.fromRGB(30, 36, 56)
	r.BackgroundTransparency = isPicked and 0 or 0.2
	r.Parent = unitList
	corner(r, 10)
	stroke(r, isPicked and TEAL or rarity.Color, isPicked and 2 or 1, isPicked and 0 or 0.7)

	-- portrait badge with the unit's initials
	local initials = ""
	for word in string.gmatch(name, "%a+") do
		if #initials < 2 then initials ..= string.sub(word, 1, 1) end
	end
	local badge = frame(r, UDim2.fromOffset(9, 9), UDim2.fromOffset(34, 34), darker(rarity.Color, 0.45))
	corner(badge, "round")
	stroke(badge, rarity.Color, 2)
	gradient(badge, { WHITE, Color3.fromRGB(170, 170, 170) }, 90)
	label(badge, string.upper(initials), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 13, WHITE, Enum.Font.GothamBlack)

	local n = label(r, name, UDim2.fromOffset(52, 8), UDim2.new(1, -150, 0, 18), 14, WHITE, Enum.Font.GothamBold)
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.TextTruncate = Enum.TextTruncate.AtEnd
	local rar = label(r, string.format("%s  ·  Lv %d %s", rarity.Name, ProgressData.LevelFromXP(u.XP), string.rep("★", u.Stars)), UDim2.fromOffset(52, 27), UDim2.new(1, -150, 0, 14), 11, rarity.Color, Enum.Font.Gotham)
	rar.TextXAlignment = Enum.TextXAlignment.Left

	-- trait pill
	local trait = TraitData.Get(traitName_)
	local pill = frame(r, UDim2.new(1, -94, 0.5, -11), UDim2.fromOffset(86, 22), trait and darker(trait.Color, 0.7) or Color3.fromRGB(40, 44, 62))
	corner(pill, "round")
	stroke(pill, trait and trait.Color or DIM, 1, trait and 0.25 or 0.6)
	local pillText = label(pill, trait and trait.Name or "No trait", UDim2.fromOffset(6, 0), UDim2.new(1, -12, 1, 0), 11,
		trait and WHITE or DIM, Enum.Font.GothamBlack)
	pillText.TextTruncate = Enum.TextTruncate.AtEnd
	if trait and trait.Tier == "Mythic" then
		gradient(pill, { WHITE, Color3.fromRGB(255, 200, 230) }, 0)
	end

	r.Activated:Connect(function()
		if busy then return end
		selected = u.Id
		confirming = false
		setMessage("")
		refreshUnits()
		refreshPicked()
	end)
end

refreshUnits = function()
	for _, c in ipairs(unitList:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
	local list, byId = readUnits()
	if selected and not byId[selected] then
		selected = nil -- deleted or fused away
		confirming = false
	end

	local order, withTrait = 0, 0
	for _, u in ipairs(list) do
		order += 1
		if u.Trait then withTrait += 1 end
		makeRow(u, UnitData.Rarities[rarityRank[UnitData.UnitRarity[u.Name]]], order)
	end
	unitsCount.Text = order > 0 and string.format("%d / %d with traits", withTrait, order) or ""
	if order == 0 then
		local holder = frame(unitList, UDim2.new(), UDim2.new(1, 0, 0, 70), WHITE, 1)
		label(holder, "You have no units yet.\nSummon some at the Wishing Fountain!", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14, SUBTLE, Enum.Font.Gotham)
	end
end

-- ===== Summoning =====
local function pop(fromScale)
	coreScale.Scale = fromScale
	TweenService:Create(coreScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function playBurst(color, size)
	burst.Size = UDim2.fromOffset(160, 160)
	burstStroke.Color = color
	burstStroke.Transparency = 0
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(burst, info, { Size = UDim2.fromOffset(size, size) }):Play()
	TweenService:Create(burstStroke, info, { Transparency = 1 }):Play()
end

-- Cycles through random traits, slowing down, then lands on the real result
local function roulette(result)
	traitCaption.Text = "SUMMONING..."
	traitCaption.TextColor3 = WHITE
	setChips(nil)
	local steps = 16
	for i = 1, steps do
		local t = TraitData.Traits[math.random(1, #TraitData.Traits)]
		traitName.Text = t.Name
		traitName.TextColor3 = t.Color
		traitTier.Text = string.upper(t.Tier)
		traitTier.TextColor3 = t.Color
		setRingColor(t.Color)
		pop(1.06)
		spinSpeed = 420 - i * 20
		task.wait(0.04 + (i / steps) ^ 2 * 0.2)
	end

	spinSpeed = 40
	local big = isPrecious(result)
	traitCaption.Text = big and ("★ NEW " .. string.upper(result.Tier) .. " ★") or "NEW TRAIT"
	traitCaption.TextColor3 = result.Tier == "Mythic" and PINK or (big and GOLD or result.Color)
	showTrait(result)
	pop(big and 1.35 or 1.2)
	playBurst(result.Color, big and 360 or 270)
	glow.BackgroundTransparency = 0.4
	TweenService:Create(glow, TweenInfo.new(1.2), { BackgroundTransparency = 0.82 }):Play()
	if big then
		task.delay(0.25, function() playBurst(GOLD, 420) end)
	end
end

summonBtn.Activated:Connect(function()
	if busy then return end
	if not selected then
		setMessage("Pick one of your units on the left first.", ERROR_COLOR)
		return
	end
	if shards() < TraitData.SummonCost then
		setMessage("You're out of Trait Shards. Win levels to earn more.", ERROR_COLOR)
		return
	end
	-- don't throw away a great trait by accident
	if isPrecious(currentTrait()) and not confirming then
		confirming = true
		refreshSummonButton()
		setMessage("This replaces the unit's " .. currentTrait().Name .. " trait for good.", GOLD)
		return
	end
	confirming = false

	busy = true
	setMessage("")
	refreshSummonButton()
	local target = selected
	local targetName = selectedUnit() and selectedUnit().Name or "Your unit"
	local ok, res = pcall(function()
		return inventoryRemote:InvokeServer("SummonTrait", target)
	end)
	local trait = ok and type(res) == "table" and res.Success and TraitData.Get(res.Trait)
	if trait then
		roulette(trait)
		setMessage(string.format("%s got %s %s!", targetName, trait.Tier, trait.Name), trait.Color)
	elseif not ok or type(res) ~= "table" then
		setMessage("Couldn't reach the server. Try again.", ERROR_COLOR)
	else
		setMessage(res.Error or "That didn't work.", ERROR_COLOR)
	end
	busy = false
	refreshUnits()
	refreshSummonButton()
	shardLabel.Text = shardText(shards())
end)

close.Activated:Connect(function()
	window.Visible = false
end)

-- Rebuild once per frame when your units, traits or Trait Shards change
-- (held back while the roulette plays, so the list doesn't give the result away)
local queued = false
local function scheduleRefresh()
	if queued then return end
	queued = true
	task.defer(function()
		queued = false
		if busy then
			shardLabel.Text = shardText(shards())
			return
		end
		refreshUnits()
		refreshPicked()
	end)
end
for _, attribute in ipairs({ "Units", "Shards" }) do
	player:GetAttributeChangedSignal(attribute):Connect(scheduleRefresh)
end
refreshUnits()
refreshPicked()

-- ===== Animation: spinning rings, orbiting crystals, drifting background, button shine =====
local clock = 0
local ringAngle = 0
RunService.RenderStepped:Connect(function(dt)
	if not window.Visible then return end
	clock += dt
	ringAngle += spinSpeed * dt
	outerGradient.Rotation = ringAngle % 360
	innerGradient.Rotation = (-ringAngle * 0.7) % 360
	borderGlow.Rotation = (clock * 50) % 360

	for i, d in ipairs(orbiters) do
		local a = math.rad(ringAngle * 0.6) + (i - 1) * math.pi / 3
		local radius = 114 + math.sin(clock * 2 + i) * 3
		d.Position = UDim2.fromOffset(CIRCLE_CENTER.X + math.cos(a) * radius, CIRCLE_CENTER.Y + math.sin(a) * radius)
		d.Rotation = 45 + ringAngle
	end

	for _, c in ipairs(driftCrystals) do
		c.Y -= c.Speed * dt
		if c.Y < -10 then c.Y = HEIGHT + 10 end
		c.Frame.Position = UDim2.fromOffset(c.X + math.sin(clock + c.Speed) * 6, c.Y)
		c.Frame.Rotation = 45 + clock * c.Speed * 2
	end

	-- the shine sweeps across every 2.5 seconds
	shineGradient.Offset = Vector2.new(((clock % 2.5) / 2.5) * 2.4 - 1.2, 0)
	summonStroke.Transparency = 0.45 + math.sin(clock * 3) * 0.2
	glow.Size = UDim2.fromOffset(196 + math.sin(clock * 2) * 6, 196 + math.sin(clock * 2) * 6)
end)

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
			confirming = false
			setMessage("")
			odds.Visible = false
			if not busy then
				refreshUnits()
				refreshPicked()
			end
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
