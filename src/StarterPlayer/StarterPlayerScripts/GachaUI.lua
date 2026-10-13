-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: GachaUI
-- (replaces the earlier version: a redesigned summon window with a rotating 3D model of the
--  featured unit, and a full-screen reveal where cards flip over one by one)
-- The summon window pops up when you walk onto the lobby's Summon Altar (the Wishing
-- Fountain) and closes when you step off (or press the X). Summoning plays a reveal: an orb
-- charges toward the color of your best pull, bursts, and the cards flip in order.
-- Legendary and Mythic cards shake and glow before they turn. Click during the reveal to
-- skip to the end.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local UnitModels = require(ReplicatedStorage:WaitForChild("UnitModels"))
local summonRemote = ReplicatedStorage:WaitForChild("SummonRemote")
local player = Players.LocalPlayer

local PITY_THRESHOLD = 50 -- keep in sync with GachaService
local SINGLE_COST, TEN_COST = 100, 900 -- keep in sync with GachaService
local WIDTH, HEIGHT = 720, 480

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local INK = Color3.fromRGB(14, 13, 24)        -- the window's base
local GLASS = Color3.fromRGB(30, 28, 48)      -- raised surfaces
local SUBTLE = Color3.fromRGB(176, 172, 205)
local DIM = Color3.fromRGB(112, 108, 140)
local GEM = Color3.fromRGB(130, 220, 255)
local GOLD = Color3.fromRGB(255, 205, 90)
local ERROR_COLOR = Color3.fromRGB(255, 130, 130)

-- the house animation vocabulary
local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BOUNCY = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local event = UnitData.Event
local featuredName = event and event.Featured
local featuredRarity = featuredName and UnitData.UnitRarity[featuredName]
local featuredColor = featuredRarity and UnitData.RarityColor[featuredRarity] or GOLD

local rarityRank = {}
for i, r in ipairs(UnitData.Rarities) do
	rarityRank[r.Name] = i
end

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

local function gradient(parent, a, b, rotation)
	local g = Instance.new("UIGradient")
	g.Color = typeof(a) == "ColorSequence" and a or ColorSequence.new(a, b or a)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

local function fade(parent, from, to, rotation)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(from, to)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
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
	l.TextWrapped = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
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

local function diamond(parent, size, color)
	local d = frame(parent, UDim2.new(), UDim2.fromOffset(size, size), color)
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Rotation = 45
	return d
end

local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function darker(color, amount)
	return color:Lerp(BLACK, amount)
end

-- A ViewportFrame showing a unit's model, framed from its bounding box.
-- Returns the viewport and the model (spin it with model:PivotTo).
local function unitViewport(parent, unitName, yaw)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(170, 170, 190)
	vp.LightColor = Color3.fromRGB(255, 245, 235)
	vp.LightDirection = Vector3.new(-0.4, -1, 0.6)
	vp.Parent = parent

	local ok, model = pcall(UnitModels.Build, unitName)
	if not ok or not model then
		return vp, nil
	end
	model:PivotTo(CFrame.Angles(0, math.rad(yaw or 0), 0))
	model.Parent = vp

	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	local boxCf, boxSize = model:GetBoundingBox()
	local center = boxCf.Position
	local distance = math.max(boxSize.Y, boxSize.X * 1.2) / 2 / math.tan(math.rad(camera.FieldOfView / 2)) * 1.25
	-- the model faces -Z, so the camera stands on the -Z side looking back at it
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, boxSize.Y * 0.08, -distance), center)
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp, model
end

-- ===== Window =====
local gui = Instance.new("ScreenGui")
gui.Name = "GachaGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- holder carries the fit-to-screen scale; the window's own scale is for the open animation
local holder = frame(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(WIDTH, HEIGHT), WHITE, 1)
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Visible = false
local fitScale = Instance.new("UIScale")
fitScale.Parent = holder
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	fitScale.Scale = math.min(1, (vp.X - 24) / WIDTH, (vp.Y - 48) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local window = frame(holder, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE)
corner(window, 20)
gradient(window, Color3.fromRGB(16, 15, 28), Color3.fromRGB(26, 20, 42), 120)
local edge = stroke(window, WHITE, 1.5, 0.15)
local edgeGlow = gradient(edge, ColorSequence.new({
	ColorSequenceKeypoint.new(0, darker(featuredColor, 0.1)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(60, 56, 90)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(60, 56, 90)),
	ColorSequenceKeypoint.new(1, darker(featuredColor, 0.1)),
}))
local openScale = Instance.new("UIScale")
openScale.Parent = window

-- ===== Featured showcase (left half) =====
local hero = Instance.new("Frame")
hero.ClipsDescendants = true -- keeps the rays and glow inside the card
hero.Position = UDim2.fromOffset(10, 10)
hero.Size = UDim2.new(0, 340, 1, -20)
hero.BackgroundColor3 = WHITE
hero.BorderSizePixel = 0
hero.Parent = window
corner(hero, 14)
gradient(hero, darker(featuredColor, 0.62), Color3.fromRGB(12, 10, 20), 90)

-- soft halo behind the model
local halo = frame(hero, UDim2.fromOffset(170, 165), UDim2.fromOffset(300, 300), featuredColor, 0.55)
halo.AnchorPoint = Vector2.new(0.5, 0.5)
corner(halo, "round")
local haloFade = Instance.new("UIGradient")
haloFade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.15),
	NumberSequenceKeypoint.new(1, 1),
})
haloFade.Parent = halo

-- light rays turning slowly behind the model
local rays = frame(hero, UDim2.fromOffset(170, 165), UDim2.fromOffset(1, 1), WHITE, 1)
rays.AnchorPoint = Vector2.new(0.5, 0.5)
for i = 1, 6 do
	local ray = frame(rays, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(46, 520), featuredColor, 0.86)
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Rotation = i * 30
	fade(ray, 1, 1, 90).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- floor glow under the model's feet
local floorGlow = frame(hero, UDim2.fromOffset(170, 280), UDim2.fromOffset(190, 26), featuredColor, 0.35)
floorGlow.AnchorPoint = Vector2.new(0.5, 0.5)
corner(floorGlow, "round")
fade(floorGlow, 0, 1, 0).Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})

local modelBox = frame(hero, UDim2.fromOffset(20, 34), UDim2.new(1, -40, 0, 270), WHITE, 1)
local heroModel = nil
if featuredName then
	local _, model = unitViewport(modelBox, featuredName, 200)
	heroModel = model
end

-- bottom fade so the text reads over the art
local textShade = frame(hero, UDim2.new(0, 0, 1, -170), UDim2.new(1, 0, 0, 170), BLACK, 0)
fade(textShade, 1, 0.15, 90)

local eventTag = frame(hero, UDim2.fromOffset(16, 16), UDim2.fromOffset(84, 22), BLACK, 0.45)
corner(eventTag, "round")
local eventTagStroke = stroke(eventTag, GOLD, 1, 0.2)
local eventTagText = label(eventTag, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 11, GOLD, Enum.Font.GothamBlack)

local countdown = label(hero, "", UDim2.new(1, -176, 0, 16), UDim2.fromOffset(160, 22), 12, SUBTLE, Enum.Font.GothamBold, Enum.TextXAlignment.Right)

local heroRarity = label(hero, "", UDim2.new(0, 20, 1, -126), UDim2.new(1, -40, 0, 16), 12, featuredColor, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
local heroName = label(hero, featuredName or "", UDim2.new(0, 20, 1, -110), UDim2.new(1, -40, 0, 34), 30, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
heroName.TextScaled = true
local heroNameSize = Instance.new("UITextSizeConstraint")
heroNameSize.MaxTextSize = 30
heroNameSize.Parent = heroName
local heroTagline = label(hero, event and event.Tagline or "", UDim2.new(0, 20, 1, -74), UDim2.new(1, -40, 0, 32), 12, SUBTLE, Enum.Font.Gotham, Enum.TextXAlignment.Left)
heroTagline.TextYAlignment = Enum.TextYAlignment.Top

local statRow = frame(hero, UDim2.new(0, 20, 1, -36), UDim2.new(1, -40, 0, 22), WHITE, 1)
local statLayout = Instance.new("UIListLayout")
statLayout.FillDirection = Enum.FillDirection.Horizontal
statLayout.Padding = UDim.new(0, 6)
statLayout.Parent = statRow
if featuredName then
	local s = UnitData.GetStats(featuredName)
	for _, text in ipairs({
		string.format("DMG %d", s.Damage),
		string.format("RNG %d", s.Range),
		string.format("%.2fs", s.Cooldown),
	}) do
		local chip = frame(statRow, UDim2.new(), UDim2.fromOffset(#text * 7 + 18, 22), BLACK, 0.5)
		corner(chip, "round")
		stroke(chip, WHITE, 1, 0.8)
		label(chip, text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 11, WHITE, Enum.Font.GothamBold)
	end
else
	hero.Visible = false
end

-- ===== Info column (right half) =====
local RX = 368 -- left edge of the right column
local RW = WIDTH - RX - 22

label(window, "WISHING FOUNTAIN", UDim2.fromOffset(RX, 22), UDim2.fromOffset(RW - 40, 14), 11, DIM, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
local title = label(window, "", UDim2.fromOffset(RX, 38), UDim2.fromOffset(RW - 40, 30), 24, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
title.TextScaled = true
local titleSize = Instance.new("UITextSizeConstraint")
titleSize.MaxTextSize = 24
titleSize.Parent = title

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(32, 32)
close.Position = UDim2.new(1, -48, 0, 18)
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextSize = 13
close.TextColor3 = SUBTLE
close.BackgroundColor3 = GLASS
close.Parent = window
corner(close, "round")
stroke(close, WHITE, 1, 0.85)

-- gems
local gemRow = frame(window, UDim2.fromOffset(RX, 84), UDim2.fromOffset(RW, 52), GLASS, 0.2)
corner(gemRow, 12)
stroke(gemRow, WHITE, 1, 0.9)
local gemIcon = diamond(gemRow, 14, GEM)
gemIcon.Position = UDim2.fromOffset(24, 26)
gradient(gemIcon, WHITE, Color3.fromRGB(120, 180, 220), 90)
local gemsLabel = label(gemRow, "", UDim2.fromOffset(44, 0), UDim2.new(0.6, -44, 1, 0), 22, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
label(gemRow, "GEMS", UDim2.new(0.6, 0, 0, 0), UDim2.new(0.4, -16, 1, 0), 11, DIM, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)

-- pity
local pityLabel = label(window, "", UDim2.fromOffset(RX, 150), UDim2.fromOffset(RW - 60, 16), 12, SUBTLE, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
local pityCount = label(window, "", UDim2.fromOffset(RX + RW - 60, 150), UDim2.fromOffset(60, 16), 12, DIM, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
local pityBack = frame(window, UDim2.fromOffset(RX, 172), UDim2.fromOffset(RW, 6), GLASS)
corner(pityBack, "round")
local pityFill = frame(pityBack, UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), WHITE)
corner(pityFill, "round")
gradient(pityFill, UnitData.RarityColor.Legendary, UnitData.RarityColor.Mythic)

-- drop rates: one bar split by chance, then a legend
label(window, "DROP RATES", UDim2.fromOffset(RX, 196), UDim2.fromOffset(RW, 14), 11, DIM, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)

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

local rateBar = Instance.new("CanvasGroup")
rateBar.Position = UDim2.fromOffset(RX, 216)
rateBar.Size = UDim2.fromOffset(RW, 8)
rateBar.BackgroundColor3 = GLASS
rateBar.BorderSizePixel = 0
rateBar.Parent = window
corner(rateBar, "round")
local rateLayout = Instance.new("UIListLayout")
rateLayout.FillDirection = Enum.FillDirection.Horizontal
rateLayout.SortOrder = Enum.SortOrder.LayoutOrder
rateLayout.Padding = UDim.new(0, 2) -- keep in sync with GAP below
rateLayout.Parent = rateBar
-- Each segment's width is its share of the bar, plus a 3px minimum so even the rarest
-- shows. The offsets are balanced so the segments and the 2px gaps add up exactly.
local MIN_SEG, GAP = 3, 2
local fixed = MIN_SEG * #UnitData.Rarities + GAP * (#UnitData.Rarities - 1)
for i, r in ipairs(UnitData.Rarities) do
	local share = r.Weight / totalWeight
	local seg = frame(rateBar, UDim2.new(), UDim2.new(share, MIN_SEG - fixed * share, 1, 0), r.Color)
	seg.LayoutOrder = i
end

local legend = frame(window, UDim2.fromOffset(RX, 232), UDim2.fromOffset(RW, 96), WHITE, 1)
local legendGrid = Instance.new("UIGridLayout")
legendGrid.CellSize = UDim2.new(0.5, -6, 0, 20)
legendGrid.CellPadding = UDim2.fromOffset(12, 2)
legendGrid.SortOrder = Enum.SortOrder.LayoutOrder
legendGrid.Parent = legend
for i = #UnitData.Rarities, 1, -1 do -- rarest first
	local r = UnitData.Rarities[i]
	local cell = frame(legend, UDim2.new(), UDim2.new(), WHITE, 1)
	cell.LayoutOrder = #UnitData.Rarities - i
	local dot = frame(cell, UDim2.fromOffset(0, 6), UDim2.fromOffset(8, 8), r.Color)
	corner(dot, "round")
	label(cell, r.Name, UDim2.fromOffset(14, 0), UDim2.new(1, -60, 1, 0), 13, r.Color, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	label(cell, (string.format("%.1f", rarityPercent(r.Name)):gsub("%.0$", "")) .. "%", UDim2.new(1, -50, 0, 0), UDim2.new(0, 50, 1, 0), 13, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
end

local featuredRate = label(window, "", UDim2.fromOffset(RX, 300), UDim2.fromOffset(RW, 30), 11, GOLD, Enum.Font.Gotham, Enum.TextXAlignment.Left)
featuredRate.TextYAlignment = Enum.TextYAlignment.Top

local message = label(window, "", UDim2.fromOffset(RX, 336), UDim2.fromOffset(RW, 20), 12, ERROR_COLOR, Enum.Font.GothamBold, Enum.TextXAlignment.Left)

-- ===== Summon buttons =====
local function summonButton(x, width, titleText, cost, primary)
	local btn = Instance.new("TextButton")
	btn.Position = UDim2.fromOffset(x, 364)
	btn.Size = UDim2.fromOffset(width, 96)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = primary and WHITE or GLASS
	btn.Parent = window
	corner(btn, 14)
	local s = stroke(btn, WHITE, 1, primary and 0.55 or 0.85)
	if primary then
		gradient(btn, featuredColor:Lerp(GOLD, 0.25), darker(featuredColor, 0.35), 25)
	end
	local scale = Instance.new("UIScale")
	scale.Parent = btn

	label(btn, titleText, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 26), 22, WHITE, Enum.Font.GothamBlack).TextStrokeTransparency = primary and 0.7 or 1
	local costRow = frame(btn, UDim2.new(0.5, 0, 0, 56), UDim2.fromOffset(1, 20), WHITE, 1)
	costRow.AnchorPoint = Vector2.new(0.5, 0)
	costRow.AutomaticSize = Enum.AutomaticSize.X
	local costLayout = Instance.new("UIListLayout")
	costLayout.FillDirection = Enum.FillDirection.Horizontal
	costLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	costLayout.Padding = UDim.new(0, 8)
	costLayout.SortOrder = Enum.SortOrder.LayoutOrder
	costLayout.Parent = costRow
	local iconBox = frame(costRow, UDim2.new(), UDim2.fromOffset(12, 12), WHITE, 1)
	iconBox.LayoutOrder = 1
	local icon = diamond(iconBox, 9, GEM)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local costText = label(costRow, commas(cost), UDim2.new(), UDim2.fromOffset(0, 20), 15, primary and WHITE or GEM, Enum.Font.GothamBold)
	costText.AutomaticSize = Enum.AutomaticSize.X
	costText.LayoutOrder = 2

	-- hover lifts the border, press pops
	btn.MouseEnter:Connect(function()
		TweenService:Create(s, FAST, { Transparency = primary and 0.2 or 0.5 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(s, FAST, { Transparency = primary and 0.55 or 0.85 }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 0.96 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, BOUNCY, { Scale = 1 }):Play()
	end)
	return btn, scale
end

local half = (RW - 10) / 2
local singleBtn = summonButton(RX, half, "Summon x1", SINGLE_COST, false)
local tenBtn = summonButton(RX + half + 10, half, "Summon x10", TEN_COST, true)

-- a light sweep across the x10 button (clipped to its rounded shape)
local sheenClip = Instance.new("CanvasGroup")
sheenClip.Size = UDim2.fromScale(1, 1)
sheenClip.BackgroundTransparency = 1
sheenClip.Parent = tenBtn
corner(sheenClip, 14)
local sheen = frame(sheenClip, UDim2.fromScale(-0.4, 0), UDim2.fromScale(0.3, 1), WHITE, 0.82)
fade(sheen, 1, 1, 0).Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 1),
})
local saveTag = frame(tenBtn, UDim2.new(1, -10, 0, -9), UDim2.fromOffset(64, 20), GOLD)
saveTag.AnchorPoint = Vector2.new(1, 0)
corner(saveTag, "round")
label(saveTag, "SAVE 10%", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, Color3.fromRGB(60, 35, 10), Enum.Font.GothamBlack)

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

local function refreshEvent()
	local active = UnitData.IsEventActive() and featuredRarity ~= nil
	if active then
		title.Text = event.Name
		eventTagText.Text = "LIMITED"
		eventTagText.TextColor3 = GOLD
		eventTagStroke.Color = GOLD
		countdown.Text = event.EndsAt and ("Ends in " .. formatTimeLeft(event.EndsAt - os.time())) or ""
		heroRarity.Text = string.upper(featuredRarity) .. "  ·  RATE UP"
		featuredRate.Text = string.format("%s is %.0f%% of %s pulls (%.2f%% per summon).",
			featuredName, event.RateUp * 100, featuredRarity, event.RateUp * rarityPercent(featuredRarity))
	else
		title.Text = "Standard Banner"
		eventTagText.Text = "ENDED"
		eventTagText.TextColor3 = SUBTLE
		eventTagStroke.Color = SUBTLE
		countdown.Text = ""
		heroRarity.Text = featuredRarity and (string.upper(featuredRarity) .. "  ·  NO LONGER SUMMONABLE") or ""
		featuredRate.Text = ""
	end
end

local function refreshPlayerInfo()
	local gems = player:GetAttribute("Gems") or 0
	local pity = player:GetAttribute("Pity") or 0
	gemsLabel.Text = commas(gems)
	pityLabel.Text = string.format("Legendary+ guaranteed in %d", math.max(1, PITY_THRESHOLD - pity))
	pityCount.Text = string.format("%d / %d", pity, PITY_THRESHOLD)
	TweenService:Create(pityFill, SMOOTH, { Size = UDim2.fromScale(math.clamp(pity / PITY_THRESHOLD, 0, 1), 1) }):Play()
end

refreshEvent()
refreshPlayerInfo()
player:GetAttributeChangedSignal("Gems"):Connect(refreshPlayerInfo)
player:GetAttributeChangedSignal("Pity"):Connect(refreshPlayerInfo)

task.spawn(function()
	while true do
		task.wait(1)
		if holder.Visible then refreshEvent() end
	end
end)

local function openWindow()
	refreshEvent()
	refreshPlayerInfo()
	message.Text = ""
	holder.Visible = true
	openScale.Scale = 0.92
	TweenService:Create(openScale, BOUNCY, { Scale = 1 }):Play()
end

local function closeWindow()
	holder.Visible = false
end
close.Activated:Connect(closeWindow)

-- ===== The reveal =====
local revealGui = Instance.new("ScreenGui")
revealGui.Name = "SummonRevealGui"
revealGui.ResetOnSpawn = false
revealGui.IgnoreGuiInset = true
revealGui.DisplayOrder = 6
revealGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
revealGui.Enabled = false
revealGui.Parent = player:WaitForChild("PlayerGui")

-- the whole backdrop is a button: clicking it skips the reveal
local backdrop = Instance.new("TextButton")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = INK
backdrop.BackgroundTransparency = 1
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.Parent = revealGui

local stage = frame(revealGui, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(760, 560), WHITE, 1)
stage.AnchorPoint = Vector2.new(0.5, 0.5)
local stageScale = Instance.new("UIScale")
stageScale.Parent = stage
local function fitStage()
	local vp = workspace.CurrentCamera.ViewportSize
	stageScale.Scale = math.min(1, (vp.X - 24) / 760, (vp.Y - 24) / 560)
end
fitStage()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitStage)

local revealTitle = label(stage, "", UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 34), 28, WHITE, Enum.Font.GothamBlack)
revealTitle.TextTransparency = 1
local revealSub = label(stage, "", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 0, 18), 13, SUBTLE, Enum.Font.GothamBold)
revealSub.TextTransparency = 1

-- the orb that charges before the cards appear
local orb = frame(stage, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(120, 120), WHITE)
orb.AnchorPoint = Vector2.new(0.5, 0.5)
corner(orb, "round")
local orbFade = Instance.new("UIGradient")
orbFade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.85),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0.85),
})
orbFade.Parent = orb
local orbRing = frame(stage, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(160, 160), WHITE, 1)
orbRing.AnchorPoint = Vector2.new(0.5, 0.5)
corner(orbRing, "round")
local orbRingStroke = stroke(orbRing, WHITE, 2, 0.3)

local cardsArea = frame(stage, UDim2.fromOffset(0, 76), UDim2.new(1, 0, 0, 390), WHITE, 1)

local doneRow = frame(stage, UDim2.new(0.5, 0, 1, -64), UDim2.fromOffset(420, 52), WHITE, 1)
doneRow.AnchorPoint = Vector2.new(0.5, 0)
doneRow.Visible = false
local function revealButton(text, x, width, primary)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, 0)
	b.Size = UDim2.fromOffset(width, 52)
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 17
	b.TextColor3 = WHITE
	b.BackgroundColor3 = primary and WHITE or GLASS
	b.Parent = doneRow
	corner(b, 12)
	stroke(b, WHITE, 1, primary and 0.5 or 0.8)
	if primary then
		gradient(b, featuredColor:Lerp(GOLD, 0.25), darker(featuredColor, 0.35), 25)
	end
	return b
end
local againBtn = revealButton("Summon again", 0, 205, true)
local doneBtn = revealButton("Done", 215, 205, false)

local revealing = false
local skipRequested = false
local lastCount = 1

local function clearCards()
	for _, c in ipairs(cardsArea:GetChildren()) do
		c:Destroy()
	end
end

-- Builds one face-down card. Returns a table with a :Flip() that turns it face up.
local function makeCard(unit, pos, size)
	local color = UnitData.RarityColor[unit.Rarity] or WHITE
	local rank = rarityRank[unit.Rarity] or 1
	local high = rank >= 4

	local slot = frame(cardsArea, pos, size, WHITE, 1)
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	local slotScale = Instance.new("UIScale")
	slotScale.Scale = 0.6
	slotScale.Parent = slot

	-- the card squashes horizontally to "flip"
	local card = frame(slot, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), WHITE)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.ClipsDescendants = true
	corner(card, 12)
	local cardStroke = stroke(card, WHITE, 1.5, 0.75)
	local cardGradient = gradient(card, Color3.fromRGB(40, 36, 62), Color3.fromRGB(20, 18, 34), 90)

	-- back: a crest
	local back = frame(card, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE, 1)
	local crest = diamond(back, 30, WHITE)
	crest.Position = UDim2.fromScale(0.5, 0.5)
	crest.BackgroundTransparency = 0.82
	stroke(crest, WHITE, 1.5, 0.5)
	local inner = diamond(back, 12, WHITE)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.BackgroundTransparency = 0.4

	-- front: the unit
	local front = frame(card, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE, 1)
	front.Visible = false
	local modelArea = frame(front, UDim2.fromScale(0, 0.04), UDim2.fromScale(1, 0.66), WHITE, 1)
	local nameLabel = label(front, unit.Name, UDim2.new(0, 6, 0.7, 0), UDim2.new(1, -12, 0.14, 0), 14, WHITE, Enum.Font.GothamBlack)
	nameLabel.TextScaled = true
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MaxTextSize = size.Y.Offset > 200 and 20 or 14
	nameSize.Parent = nameLabel
	local subLabel = label(front, unit.AutoDeleted and "Auto-deleted" or unit.Rarity, UDim2.new(0, 6, 0.85, 0), UDim2.new(1, -12, 0.1, 0), 11,
		unit.AutoDeleted and DIM or color, Enum.Font.GothamBlack)
	subLabel.TextScaled = true
	local subSize = Instance.new("UITextSizeConstraint")
	subSize.MaxTextSize = size.Y.Offset > 200 and 14 or 11
	subSize.Parent = subLabel
	if unit.Featured then
		local tag = frame(front, UDim2.fromOffset(6, 6), UDim2.fromOffset(54, 18), GOLD)
		corner(tag, "round")
		label(tag, "RATE UP", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 9, Color3.fromRGB(60, 35, 10), Enum.Font.GothamBlack)
	end

	-- glow that builds behind high-rarity cards before they turn
	local glowBack = frame(slot, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 30, 1, 30), color, 1)
	glowBack.AnchorPoint = Vector2.new(0.5, 0.5)
	glowBack.ZIndex = 0
	corner(glowBack, 22)

	local self = { Slot = slot, High = high, Color = color, Flipped = false }

	function self.Appear(delay)
		task.delay(delay, function()
			TweenService:Create(slotScale, BOUNCY, { Scale = 1 }):Play()
		end)
	end

	local function showFront()
		back.Visible = false
		front.Visible = true
		cardGradient.Color = ColorSequence.new(darker(color, unit.AutoDeleted and 0.8 or 0.45), Color3.fromRGB(16, 14, 28))
		cardStroke.Color = color
		cardStroke.Transparency = unit.AutoDeleted and 0.7 or 0.1
		cardStroke.Thickness = high and 2.5 or 1.5
		if not unit.AutoDeleted then
			unitViewport(modelArea, unit.Name, 200)
		else
			card.BackgroundTransparency = 0.35
			nameLabel.TextTransparency = 0.45
		end
	end

	-- instant = true skips the animation (used when the reveal is skipped)
	function self.Flip(instant)
		if self.Flipped then return end
		self.Flipped = true
		slotScale.Scale = 1
		if instant then
			showFront()
			if high then glowBack.BackgroundTransparency = 0.6 end
			return
		end
		if high and not skipRequested then
			-- anticipation: the card trembles while its glow builds
			TweenService:Create(glowBack, TweenInfo.new(0.5), { BackgroundTransparency = 0.35 }):Play()
			cardStroke.Color = color
			for i = 1, 8 do
				card.Rotation = (i % 2 == 0 and 1 or -1) * (1 + i * 0.25)
				task.wait(0.05)
			end
			card.Rotation = 0
		end
		local squash = TweenService:Create(card, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(0, 1) })
		squash:Play()
		squash.Completed:Wait()
		showFront()
		TweenService:Create(card, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
		if high then
			slotScale.Scale = 1.15
			TweenService:Create(slotScale, BOUNCY, { Scale = 1 }):Play()
			TweenService:Create(glowBack, TweenInfo.new(0.8), { BackgroundTransparency = 0.6 }):Play()
		end
	end

	return self
end

local function layoutCards(results)
	clearCards()
	local cards = {}
	if #results == 1 then
		table.insert(cards, makeCard(results[1], UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(200, 280)))
	else
		local cols = 5
		local w, h, gap = 128, 180, 14
		local rowsCount = math.ceil(#results / cols)
		for i, unit in ipairs(results) do
			local col = (i - 1) % cols
			local rowIndex = (i - 1) // cols
			local x = (col - (cols - 1) / 2) * (w + gap)
			local y = (rowIndex - (rowsCount - 1) / 2) * (h + gap)
			table.insert(cards, makeCard(unit, UDim2.new(0.5, x, 0.5, y), UDim2.fromOffset(w, h)))
		end
	end
	return cards
end

local function bestOf(results)
	local best = results[1]
	for _, u in ipairs(results) do
		if (rarityRank[u.Rarity] or 0) > (rarityRank[best.Rarity] or 0) then
			best = u
		end
	end
	return best
end

local function playReveal(results)
	revealing = true
	skipRequested = false
	clearCards()
	doneRow.Visible = false
	revealTitle.TextTransparency = 1
	revealSub.TextTransparency = 1
	revealGui.Enabled = true
	backdrop.BackgroundTransparency = 1
	TweenService:Create(backdrop, SMOOTH, { BackgroundTransparency = 0.12 }):Play()

	local best = bestOf(results)
	local bestColor = UnitData.RarityColor[best.Rarity] or WHITE
	local bestHigh = (rarityRank[best.Rarity] or 1) >= 4

	-- 1. the orb charges, drifting from white toward the best pull's color
	orb.Visible, orbRing.Visible = true, true
	orb.BackgroundColor3 = WHITE
	orb.Size = UDim2.fromOffset(40, 40)
	orbRing.Size = UDim2.fromOffset(240, 240)
	orbRingStroke.Color = WHITE
	orbRingStroke.Transparency = 1
	local charge = TweenInfo.new(bestHigh and 1.1 or 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	TweenService:Create(orb, charge, { Size = UDim2.fromOffset(120, 120), BackgroundColor3 = bestColor }):Play()
	TweenService:Create(orbRing, charge, { Size = UDim2.fromOffset(130, 130) }):Play()
	TweenService:Create(orbRingStroke, charge, { Transparency = 0.2, Color = bestColor }):Play()
	local waited = 0
	while waited < charge.Time and not skipRequested do
		waited += task.wait()
		if bestHigh then
			orb.Position = UDim2.new(0.5, math.random(-2, 2), 0.5, math.random(-2, 2))
		end
	end
	orb.Position = UDim2.fromScale(0.5, 0.5)

	-- 2. it bursts
	local burst = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(orb, burst, { Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1 }):Play()
	TweenService:Create(orbRing, burst, { Size = UDim2.fromOffset(700, 700) }):Play()
	TweenService:Create(orbRingStroke, burst, { Transparency = 1 }):Play()
	task.delay(0.4, function()
		orb.Visible, orbRing.Visible = false, false
		orb.BackgroundTransparency = 0
	end)

	-- 3. the cards land face down, then flip in order
	local gotFeatured = false
	for _, u in ipairs(results) do
		gotFeatured = gotFeatured or u.Featured
	end
	revealTitle.Text = gotFeatured and ("★  " .. featuredName .. "  ★") or (#results == 1 and "Your summon" or "Your summons")
	revealTitle.TextColor3 = gotFeatured and GOLD or WHITE
	revealSub.Text = bestHigh and (best.Rarity .. " pull!") or "Click anywhere to skip"
	revealSub.TextColor3 = bestHigh and bestColor or SUBTLE
	TweenService:Create(revealTitle, SMOOTH, { TextTransparency = 0 }):Play()
	TweenService:Create(revealSub, SMOOTH, { TextTransparency = 0 }):Play()

	local cards = layoutCards(results)
	for i, c in ipairs(cards) do
		c.Appear((i - 1) * 0.03)
	end
	if not skipRequested then task.wait(0.45) end

	for _, c in ipairs(cards) do
		if skipRequested then break end
		c.Flip(false)
		task.wait(c.High and 0.3 or 0.09)
	end
	for _, c in ipairs(cards) do
		c.Flip(true) -- anything left after a skip
	end

	againBtn.Text = lastCount == 10 and "Summon x10 again" or "Summon x1 again"
	doneRow.Visible = true
	revealing = false
end

local function closeReveal()
	if revealing then return end
	TweenService:Create(backdrop, FAST, { BackgroundTransparency = 1 }):Play()
	revealGui.Enabled = false
	clearCards()
end

backdrop.Activated:Connect(function()
	if revealing then skipRequested = true end
end)
doneBtn.Activated:Connect(closeReveal)

-- ===== Summoning =====
local busy = false
local function doSummon(count)
	if busy then return end
	local cost = count == 10 and TEN_COST or SINGLE_COST
	if (player:GetAttribute("Gems") or 0) < cost then
		message.Text = string.format("You need %s gems for that.", commas(cost))
		return
	end
	busy = true
	message.Text = ""
	lastCount = count
	local ok, res = pcall(function()
		return summonRemote:InvokeServer(count)
	end)
	if not ok or type(res) ~= "table" then
		message.Text = "Couldn't reach the server. Try again."
	elseif not res.Success then
		message.Text = res.Error or "That didn't work."
	else
		playReveal(res.Results)
	end
	busy = false
end

singleBtn.Activated:Connect(function() doSummon(1) end)
tenBtn.Activated:Connect(function() doSummon(10) end)
againBtn.Activated:Connect(function()
	if revealing or busy then return end
	if (player:GetAttribute("Gems") or 0) < (lastCount == 10 and TEN_COST or SINGLE_COST) then
		againBtn.Text = "Not enough gems"
		return
	end
	doSummon(lastCount)
end)

-- ===== Ambient motion (only while something is on screen) =====
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	if not holder.Visible then return end
	clock += dt
	edgeGlow.Rotation = (clock * 30) % 360
	rays.Rotation = (clock * 6) % 360
	halo.BackgroundTransparency = 0.55 + math.sin(clock * 1.6) * 0.08
	if heroModel then
		heroModel:PivotTo(CFrame.Angles(0, math.rad(200 + clock * 25), 0))
	end
	-- the sheen crosses the x10 button once every 3 seconds
	local t = (clock % 3) / 3
	sheen.Position = UDim2.fromScale(-0.4 + t * 1.8, 0)
end)

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
			openWindow()
		elseif not on and wasOn then
			closeWindow()
		end
		wasOn = on
	end
end)

-- Never leave anything open during a match
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		closeWindow()
		skipRequested = true
		revealGui.Enabled = false
	end
end)
