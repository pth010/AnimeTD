-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: TraitCaveUI
-- The Traits Cave window: pick one of your units, then summon a trait onto it for Gold.
-- The unit keeps that trait until you summon on it again (the new trait replaces the old).
-- Pops up when you walk into the lobby's Traits Cave and closes when you walk out (or press X).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
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
local ERROR_COLOR = Color3.fromRGB(255, 130, 130)

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

local function button(parent, text, pos, size, textSize, a, b)
	local btn = Instance.new("TextButton")
	btn.Position = pos
	btn.Size = size
	btn.Text = text
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = textSize
	btn.TextColor3 = WHITE
	btn.BackgroundColor3 = WHITE
	btn.AutoButtonColor = true
	btn.Parent = parent
	corner(btn, 10)
	local g = gradient(btn, a, b or a, 0)
	return btn, g
end

-- ===== Window =====
local gui = Instance.new("ScreenGui")
gui.Name = "TraitCaveGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- the odds window draws over everything
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
local subtitle = label(header, "Pick a unit, then summon a trait onto it. It keeps the trait until you summon again.",
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

-- ===== Your units (left) =====
local unitsPanel = frame(window, UDim2.fromOffset(16, 72), UDim2.fromOffset(300, 356), PANEL_LIGHT)
corner(unitsPanel, 12)
local unitsTitle = label(unitsPanel, "PICK A UNIT", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 18), 13, SUBTLE, Enum.Font.GothamBlack)
unitsTitle.TextXAlignment = Enum.TextXAlignment.Left

local unitList = Instance.new("ScrollingFrame")
unitList.Position = UDim2.fromOffset(8, 30)
unitList.Size = UDim2.new(1, -16, 1, -38)
unitList.BackgroundTransparency = 1
unitList.BorderSizePixel = 0
unitList.ScrollBarThickness = 5
unitList.CanvasSize = UDim2.new()
unitList.AutomaticCanvasSize = Enum.AutomaticSize.Y
unitList.Parent = unitsPanel
local unitLayout = Instance.new("UIListLayout")
unitLayout.Padding = UDim.new(0, 4)
unitLayout.SortOrder = Enum.SortOrder.LayoutOrder
unitLayout.Parent = unitList

-- ===== The picked unit (right) =====
local picked = frame(window, UDim2.fromOffset(328, 72), UDim2.fromOffset(296, 356), PANEL_LIGHT)
corner(picked, 12)

local goldLabel = label(picked, "", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 18, GOLD, Enum.Font.GothamBlack)
goldLabel.TextXAlignment = Enum.TextXAlignment.Left

local unitName = label(picked, "", UDim2.fromOffset(14, 44), UDim2.new(1, -28, 0, 28), 22, WHITE, Enum.Font.GothamBlack)
unitName.TextXAlignment = Enum.TextXAlignment.Left
unitName.TextTruncate = Enum.TextTruncate.AtEnd
local unitRarity = label(picked, "", UDim2.fromOffset(14, 72), UDim2.new(1, -28, 0, 18), 13, SUBTLE)
unitRarity.TextXAlignment = Enum.TextXAlignment.Left

-- the trait card: shows the unit's trait, and flashes when a new one lands
local traitCard = frame(picked, UDim2.fromOffset(14, 102), UDim2.new(1, -28, 0, 150), PANEL)
corner(traitCard, 10)
local traitStroke = stroke(traitCard, SUBTLE, 2)
local traitCaption = label(traitCard, "CURRENT TRAIT", UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 16), 12, SUBTLE, Enum.Font.GothamBlack)
local traitName = label(traitCard, "", UDim2.fromOffset(8, 34), UDim2.new(1, -16, 0, 40), 30, WHITE, Enum.Font.GothamBlack)
traitName.TextStrokeTransparency = 0.6
local traitTier = label(traitCard, "", UDim2.fromOffset(8, 76), UDim2.new(1, -16, 0, 18), 14, SUBTLE)
local traitDesc = label(traitCard, "", UDim2.fromOffset(8, 98), UDim2.new(1, -16, 0, 40), 14, WHITE, Enum.Font.Gotham)

local message = label(picked, "", UDim2.fromOffset(14, 262), UDim2.new(1, -28, 0, 84), 14, SUBTLE, Enum.Font.Gotham)
message.TextYAlignment = Enum.TextYAlignment.Top

-- ===== Buttons =====
local oddsBtn = button(window, "ODDS", UDim2.fromOffset(16, 442), UDim2.fromOffset(140, 48), 18,
	Color3.fromRGB(40, 70, 90), Color3.fromRGB(50, 60, 100))
local summonBtn, summonGradient = button(window, "", UDim2.fromOffset(168, 442), UDim2.new(1, -184, 0, 48), 19,
	Color3.fromRGB(20, 150, 160), Color3.fromRGB(120, 70, 220))

-- ===== Odds window =====
local odds = frame(window, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), PANEL)
odds.Active = true
odds.ZIndex = 10
odds.Visible = false
corner(odds, 14)
label(odds, "TRAIT ODDS", UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 28), 22, WHITE, Enum.Font.GothamBlack)
label(odds, string.format("Each summon costs %d Gold and replaces the unit's current trait.", TraitData.SummonCost),
	UDim2.fromOffset(16, 40), UDim2.new(1, -32, 0, 18), 13, SUBTLE, Enum.Font.Gotham)
local oddsClose = Instance.new("TextButton")
oddsClose.Size = UDim2.fromOffset(34, 34)
oddsClose.Position = UDim2.new(1, -46, 0, 10)
oddsClose.Text = "X"
oddsClose.Font = Enum.Font.GothamBlack
oddsClose.TextSize = 16
oddsClose.TextColor3 = WHITE
oddsClose.BackgroundColor3 = Color3.fromRGB(190, 70, 70)
oddsClose.Parent = odds
corner(oddsClose, 17)

local oddsList = Instance.new("ScrollingFrame")
oddsList.Position = UDim2.fromOffset(16, 68)
oddsList.Size = UDim2.new(1, -32, 1, -84)
oddsList.BackgroundTransparency = 1
oddsList.BorderSizePixel = 0
oddsList.ScrollBarThickness = 5
oddsList.CanvasSize = UDim2.new()
oddsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
oddsList.Parent = odds
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
			local r = frame(oddsList, UDim2.new(), UDim2.new(1, -8, 0, 28), tier.Color:Lerp(Color3.new(0, 0, 0), 0.78))
			r.LayoutOrder = row
			corner(r, 6)
			local name = label(r, trait.Name, UDim2.fromOffset(10, 0), UDim2.new(0, 120, 1, 0), 14, tier.Color)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local tierText = label(r, tier.Name, UDim2.fromOffset(130, 0), UDim2.new(0, 80, 1, 0), 12, tier.Color, Enum.Font.Gotham)
			tierText.TextXAlignment = Enum.TextXAlignment.Left
			local desc = label(r, TraitData.Describe(trait.Name), UDim2.fromOffset(212, 0), UDim2.new(1, -290, 1, 0), 12, SUBTLE, Enum.Font.Gotham)
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.TextTruncate = Enum.TextTruncate.AtEnd
			local pct = label(r, TraitData.ChanceText(trait.Name), UDim2.new(1, -72, 0, 0), UDim2.new(0, 62, 1, 0), 14, WHITE)
			pct.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
end

oddsBtn.Activated:Connect(function() odds.Visible = true end)
oddsClose.Activated:Connect(function() odds.Visible = false end)

-- ===== State =====
local selected = nil     -- the picked unit's name
local confirming = false -- true after one click on Summon over a Legendary or Mythic trait
local busy = false

local function parseCounts()
	local counts = {}
	for name, n in string.gmatch(player:GetAttribute("UnitCounts") or "", "([^;=]+)=(%d+)") do
		counts[name] = tonumber(n)
	end
	return counts
end

local function setMessage(text, color)
	message.Text = text
	message.TextColor3 = color or SUBTLE
end

local function currentTrait()
	return selected and TraitData.Get(TraitData.Parse(player:GetAttribute("UnitTraits"))[selected]) or nil
end

-- Legendary and Mythic traits ask before being replaced
local function isPrecious(trait)
	return trait ~= nil and (trait.Tier == "Legendary" or trait.Tier == "Mythic")
end

local function refreshSummonButton()
	local trait = currentTrait()
	if not selected then
		summonBtn.Text = "PICK A UNIT FIRST"
		summonGradient.Color = ColorSequence.new(Color3.fromRGB(70, 75, 90))
	elseif confirming and trait then
		summonBtn.Text = string.format("REPLACE %s? CLICK AGAIN", string.upper(trait.Name))
		summonGradient.Color = ColorSequence.new(Color3.fromRGB(210, 90, 60), Color3.fromRGB(190, 50, 90))
	else
		summonBtn.Text = string.format("SUMMON TRAIT  -  %d Gold", TraitData.SummonCost)
		summonGradient.Color = ColorSequence.new(Color3.fromRGB(20, 150, 160), Color3.fromRGB(120, 70, 220))
	end
end

local function refreshPicked()
	goldLabel.Text = string.format("%d Gold", player:GetAttribute("Gold") or 0)
	if not selected then
		unitName.Text = "No unit picked"
		unitRarity.Text = "Choose one of your units on the left."
		unitRarity.TextColor3 = SUBTLE
		traitCard.Visible = false
	else
		local rarityName = UnitData.UnitRarity[selected]
		unitName.Text = selected
		unitRarity.Text = rarityName
		unitRarity.TextColor3 = UnitData.RarityColor[rarityName] or SUBTLE
		traitCard.Visible = true
		local trait = currentTrait()
		if trait then
			traitName.Text = trait.Name
			traitName.TextColor3 = trait.Color
			traitTier.Text = trait.Tier .. "  -  " .. TraitData.ChanceText(trait.Name) .. " chance"
			traitTier.TextColor3 = trait.Color
			traitDesc.Text = TraitData.Describe(trait.Name)
			traitStroke.Color = trait.Color
		else
			traitName.Text = "No trait"
			traitName.TextColor3 = SUBTLE
			traitTier.Text = ""
			traitDesc.Text = "Summon to give this unit a trait."
			traitStroke.Color = SUBTLE
		end
	end
	refreshSummonButton()
end

local function refreshUnits()
	for _, c in ipairs(unitList:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
	local counts = parseCounts()
	local traits = TraitData.Parse(player:GetAttribute("UnitTraits"))
	if selected and not counts[selected] then
		selected = nil -- deleted or fused away
		confirming = false
	end

	local order = 0
	for i = #UnitData.Rarities, 1, -1 do -- rarest first
		local rarity = UnitData.Rarities[i]
		local list = table.clone(UnitData.Units[rarity.Name])
		table.sort(list)
		for _, name in ipairs(list) do
			if counts[name] then
				order += 1
				local isPicked = name == selected
				local r = Instance.new("TextButton")
				r.LayoutOrder = order
				r.Size = UDim2.new(1, -8, 0, 40)
				r.Text = ""
				r.AutoButtonColor = true
				r.BackgroundColor3 = rarity.Color:Lerp(Color3.new(0, 0, 0), isPicked and 0.45 or 0.78)
				r.Parent = unitList
				corner(r, 8)
				if isPicked then stroke(r, TEAL, 2) end

				local n = label(r, name, UDim2.fromOffset(10, 3), UDim2.new(1, -20, 0, 18), 14, rarity.Color)
				n.TextXAlignment = Enum.TextXAlignment.Left
				n.TextTruncate = Enum.TextTruncate.AtEnd
				local trait = TraitData.Get(traits[name])
				local t = label(r, trait and (trait.Name .. "  (" .. trait.Tier .. ")") or "No trait",
					UDim2.fromOffset(10, 20), UDim2.new(1, -20, 0, 16), 12, trait and trait.Color or SUBTLE, Enum.Font.Gotham)
				t.TextXAlignment = Enum.TextXAlignment.Left

				r.Activated:Connect(function()
					if busy then return end
					selected = name
					confirming = false
					setMessage("")
					refreshUnits()
					refreshPicked()
				end)
			end
		end
	end
	if order == 0 then
		local holder = frame(unitList, UDim2.new(), UDim2.new(1, -8, 0, 60), PANEL_LIGHT)
		holder.BackgroundTransparency = 1
		label(holder, "You have no units yet.\nSummon some at the Wishing Fountain!", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14, SUBTLE, Enum.Font.Gotham)
	end
end

-- A quick flash on the trait card when a new trait lands
local function celebrate(trait)
	local big = isPrecious(trait)
	traitCaption.Text = big and "★ NEW TRAIT ★" or "NEW TRAIT"
	traitCaption.TextColor3 = big and GOLD or trait.Color
	traitCard.BackgroundColor3 = trait.Color
	TweenService:Create(traitCard, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = PANEL }):Play()
	task.delay(2.5, function()
		traitCaption.Text = "CURRENT TRAIT"
		traitCaption.TextColor3 = SUBTLE
	end)
end

summonBtn.Activated:Connect(function()
	if busy then return end
	if not selected then
		setMessage("Pick one of your units on the left first.", ERROR_COLOR)
		return
	end
	-- don't throw away a great trait by accident
	if isPrecious(currentTrait()) and not confirming then
		confirming = true
		refreshSummonButton()
		setMessage("This replaces the unit's current trait for good.", GOLD)
		return
	end
	confirming = false

	busy = true
	local target = selected
	local ok, res = pcall(function()
		return inventoryRemote:InvokeServer("SummonTrait", target)
	end)
	busy = false
	if not ok or type(res) ~= "table" then
		setMessage("Couldn't reach the server. Try again.", ERROR_COLOR)
	elseif not res.Success then
		setMessage(res.Error or "That didn't work.", ERROR_COLOR)
	else
		local trait = TraitData.Get(res.Trait)
		refreshUnits()
		refreshPicked()
		if trait and target == selected then
			celebrate(trait)
			setMessage(string.format("%s got %s %s!", target, trait.Tier, trait.Name), trait.Color)
		end
	end
	refreshSummonButton()
end)

close.Activated:Connect(function()
	window.Visible = false
end)

-- Rebuild once per frame when your units, traits or Gold change
local queued = false
local function scheduleRefresh()
	if queued then return end
	queued = true
	task.defer(function()
		queued = false
		refreshUnits()
		refreshPicked()
	end)
end
for _, attribute in ipairs({ "UnitCounts", "UnitTraits", "Gold" }) do
	player:GetAttributeChangedSignal(attribute):Connect(scheduleRefresh)
end
refreshUnits()
refreshPicked()

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
			refreshUnits()
			refreshPicked()
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
