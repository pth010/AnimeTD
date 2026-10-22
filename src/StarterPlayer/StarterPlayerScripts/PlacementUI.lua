-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: PlacementUI
-- (replaces the earlier version: during a Damage Challenge the top bar shows the challenge's
--  timer and damage, and "Cash: unlimited")
-- During a match your lighting takes the map's theme (see ArenaThemes).
-- Switches your lighting to daylight during a match and back to the lobby's night sky
-- afterwards (see LobbyBuilder), with the map's own lighting on top during the match.
-- The team bar at the bottom (see InventoryUI) is the hotbar in matches too, so this script
-- doesn't draw its own. Keys 1-6 follow the team slots.
-- HUD (wave, base HP, cash) and click-to-place with a range preview.
-- Controls: click a unit on the team bar, then click a green plot to place it.
-- Click a placed unit (with nothing selected) to upgrade or sell it.
-- Keys 1-6 pick the unit in that team slot (press the same key again to put it away).
-- The team bar shows each unit's cost and how many you've placed out of its limit (e.g. 2/5).
-- It talks to this script through the "SelectUnit" BindableEvent (team bar -> pick a unit)
-- and the "PlacingUnit" attribute on the player (this script -> which unit is being placed).
-- Q or right-click cancels / closes. (When nothing is open, Q is sprint/dash: see MovementController.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local ProgressData = require(ReplicatedStorage:WaitForChild("ProgressData"))
local StatIcons = require(ReplicatedStorage:WaitForChild("StatIcons"))
local placeRemote = ReplicatedStorage:WaitForChild("PlaceUnitRemote")
local actionRemote = ReplicatedStorage:WaitForChild("UnitActionRemote")
local placeable = nil   -- this match's PlaceableArea (set when a match starts)
local unitsFolder = nil -- this match's Units folder

local player = Players.LocalPlayer

-- A unit's stats with your trait, level and stars applied (cost, range...)
local function myStats(name)
	local traits = TraitData.Parse(player:GetAttribute("UnitTraits"))
	local progress = ProgressData.Parse(player:GetAttribute("UnitProgress"))[name]
	return ProgressData.Apply(TraitData.StatsFor(name, traits[name]), progress and progress.XP, progress and progress.Stars)
end
local camera = workspace.CurrentCamera

-- Each team plays in its own arena; the server tells us which one via ArenaId
local function updateArenaRefs()
	local id = player:GetAttribute("ArenaId")
	local arenas = workspace:FindFirstChild("Arenas")
	local arena = id and arenas and arenas:FindFirstChild("Arena" .. id)
	placeable = arena and arena:FindFirstChild("PlaceableArea") or nil
	unitsFolder = arena and arena:FindFirstChild("Units") or nil
end

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "TowerDefenseHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local hud = Instance.new("TextLabel")
hud.Size = UDim2.fromOffset(560, 36)
hud.Position = UDim2.new(0.5, -280, 0, 10)
hud.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
hud.TextColor3 = Color3.new(1, 1, 1)
hud.Font = Enum.Font.GothamBold
hud.TextSize = 16
hud.Parent = gui
Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 8)

local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromOffset(320, 28)
toast.Position = UDim2.new(0.5, -160, 1, -190) -- above the team bar
toast.BackgroundTransparency = 1
toast.TextColor3 = Color3.fromRGB(255, 120, 120)
toast.TextStrokeTransparency = 0.5
toast.Font = Enum.Font.GothamBold
toast.TextSize = 18
toast.Text = ""
toast.Parent = gui

-- (the old hotbar frame is kept but never shown: the team bar replaced it)
local hotbar = Instance.new("Frame")
hotbar.Visible = false
hotbar.Size = UDim2.fromOffset(720, 70)
hotbar.Position = UDim2.new(0.5, -360, 1, -90)
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = hotbar

local toastToken = 0
local function showToast(text)
	toastToken += 1
	local mine = toastToken
	toast.Text = text
	task.delay(2, function()
		if toastToken == mine then toast.Text = "" end
	end)
end

local function refreshHud()
	if player:GetAttribute("Challenge") == true then
		-- the Damage Challenge: the timer and damage are in the status, and cash is unlimited
		hud.Text = (player:GetAttribute("MatchStatus") or "") .. "   |   Cash: unlimited"
		return
	end
	hud.Text = string.format(
		"%s   |   Base HP: %d   |   Wave %d/%d   |   Cash: $%d",
		player:GetAttribute("MatchStatus") or "",
		player:GetAttribute("BaseHealth") or 0,
		player:GetAttribute("Wave") or 0,
		player:GetAttribute("MaxWave") or 0,
		player:GetAttribute("Cash") or 0
	)
end
refreshHud()
for _, name in ipairs({ "MatchStatus", "BaseHealth", "Wave", "MaxWave", "Challenge" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshHud)
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshHud)

-- ===== UPGRADE / SELL PANEL =====
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(210, 220)
panel.Position = UDim2.new(1, -230, 0.5, -110)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local function panelLabel(posY, height, size)
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromOffset(8, posY)
	l.Size = UDim2.new(1, -16, 0, height)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextWrapped = true
	l.Parent = panel
	return l
end

local function panelButton(posY, color)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(10, posY)
	b.Size = UDim2.new(1, -20, 0, 36)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local panelTitle = panelLabel(8, 24, 17)
-- stats as icon chips (two rows), with the trait written underneath
local STAT_CHIP = 20
local function chipRow(posY)
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(8, posY)
	row.Size = UDim2.new(1, -16, 0, STAT_CHIP)
	row.BackgroundTransparency = 1
	row.Parent = panel
	return row
end
local statRow = chipRow(36)
local statRow2 = chipRow(60)
local panelStats = panelLabel(82, 40, 12)

-- Refills a chip row only when what it shows has changed (the panel refreshes on every attack)
local function showChips(row, chips)
	local parts = {}
	for _, c in ipairs(chips) do
		table.insert(parts, c[1] .. "=" .. c[2])
	end
	local key = table.concat(parts, ";")
	if row:GetAttribute("Shown") ~= key then
		row:SetAttribute("Shown", key)
		StatIcons.Fill(row, chips, STAT_CHIP)
	end
end
local upgradeBtn = panelButton(122, Color3.fromRGB(60, 160, 90))
local sellBtn = panelButton(168, Color3.fromRGB(190, 70, 70))

local rangeRing = Instance.new("Part")
rangeRing.Shape = Enum.PartType.Cylinder
rangeRing.Anchored = true
rangeRing.CanCollide = false
rangeRing.CanQuery = false
rangeRing.CanTouch = false
rangeRing.Material = Enum.Material.Neon
rangeRing.Color = Color3.fromRGB(120, 180, 255)
rangeRing.Transparency = 0.75

local inspected = nil
local inspectConns = {}

-- Units' name tags are hidden (GameService makes them switched off). Show the clicked one's.
-- This only changes your own screen.
local function setNameTagShown(part, shown)
	local tag = part and part:FindFirstChild("NameTag")
	if tag and tag:IsA("BillboardGui") then
		tag.Enabled = shown
	end
end

local function closePanel()
	panel.Visible = false
	setNameTagShown(inspected, false)
	inspected = nil
	rangeRing.Parent = nil
	for _, c in ipairs(inspectConns) do c:Disconnect() end
	table.clear(inspectConns)
end

local function refreshPanel()
	if not inspected or not inspected.Parent then
		closePanel()
		return
	end

	local level = inspected:GetAttribute("Level") or 1
	local maxLevel = inspected:GetAttribute("MaxLevel") or 1
	local damage = inspected:GetAttribute("Damage") or 0
	local range = inspected:GetAttribute("Range") or 0
	local cost = inspected:GetAttribute("UpgradeCost") or -1
	local sellValue = inspected:GetAttribute("SellValue") or 0

	panelTitle.Text = string.format("%s  Lv %d/%d", inspected.Name, level, maxLevel)
	local trait = TraitData.Get(inspected:GetAttribute("Trait"))
	local isFarm = inspected:GetAttribute("IsFarm") == true
	if isFarm then
		local nextIncome = inspected:GetAttribute("NextIncome") or 0
		local every = inspected:GetAttribute("PayEvery") or 10
		showChips(statRow, { { "Income", string.format("$%d / %ds", inspected:GetAttribute("Income") or 0, every) } })
		showChips(statRow2, { { "Income", nextIncome > 0 and string.format("Next lv: $%d", nextIncome) or "Max income!" } })
	else
		local row = { { "Damage", tostring(math.floor(damage)) }, { "Range", string.format("%.1f", range) } }
		local cooldown = inspected:GetAttribute("Cooldown")
		if cooldown then
			table.insert(row, { "Speed", string.format("%.2fs", cooldown) })
		end
		showChips(statRow, row)
		local below = TraitData.EffectChips(inspected.Name, inspected:GetAttribute("Trait")) -- (with its trait)
		if inspected:GetAttribute("HighGround") then
			table.insert(below, 1, { "HighGround", "High ground" })
		end
		showChips(statRow2, below)
	end
	panelStats.Text = trait and string.format("Trait: %s (%s)", trait.Name, TraitData.Describe(trait.Name)) or ""
	upgradeBtn.Text = cost >= 0 and string.format("Upgrade ($%d)", cost) or "MAX LEVEL"
	sellBtn.Text = string.format("Sell (+$%d)", sellValue)

	rangeRing.Transparency = isFarm and 1 or 0.75 -- cash units have no attack range
	rangeRing.Size = Vector3.new(0.2, range * 2, range * 2)
	-- on the ground under the unit's hitbox
	rangeRing.CFrame = CFrame.new(inspected.Position - Vector3.new(0, inspected.Size.Y / 2 - 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function openPanel(part)
	closePanel()
	inspected = part
	setNameTagShown(part, true)
	table.insert(inspectConns, part.AttributeChanged:Connect(refreshPanel))
	table.insert(inspectConns, part.AncestryChanged:Connect(refreshPanel))
	panel.Visible = true
	rangeRing.Parent = workspace
	refreshPanel()
end

local function doAction(action)
	if not inspected then return end
	local res = actionRemote:InvokeServer(action, inspected)
	if not res.Success then
		showToast(res.Error)
	end
end

upgradeBtn.Activated:Connect(function() doAction("Upgrade") end)
sellBtn.Activated:Connect(function() doAction("Sell") end)

-- ===== PLACEMENT GHOST =====
local selected = nil
local selectedRange = 0
local refreshHotbarHighlight -- defined in the HOTBAR section

local ghost = Instance.new("Part")
ghost.Shape = Enum.PartType.Cylinder
ghost.Anchored = true
ghost.CanCollide = false
ghost.CanQuery = false
ghost.CanTouch = false
ghost.Material = Enum.Material.Neon
ghost.Transparency = 0.7

local function selectUnit(name)
	selected = name
	if name then
		closePanel()
		selectedRange = myStats(name).Range
		ghost.Parent = workspace
	else
		ghost.Parent = nil
	end
	refreshHotbarHighlight()
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function mouseRaycast()
	local loc = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(loc.X, loc.Y)
	rayParams.FilterDescendantsInstances = { ghost, rangeRing, player.Character }
	return workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
end

RunService.RenderStepped:Connect(function()
	if not selected then return end
	local hit = mouseRaycast()
	if hit then
		local ok = placeable ~= nil and hit.Instance:IsDescendantOf(placeable)
		local mult = hit.Instance:GetAttribute("HighGround") and UnitData.HighGroundRangeMult or 1
		local r = selectedRange * mult
		ghost.Size = Vector3.new(0.2, r * 2, r * 2)
		ghost.Color = ok and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 80)
		ghost.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ghost.Transparency = 0.7
	else
		ghost.Transparency = 1
	end
end)

-- Number keys 1-6 -> hotbar slots 1-6
local SLOT_KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4, [Enum.KeyCode.KeypadFive] = 5, [Enum.KeyCode.KeypadSix] = 6,
}
local hotbarNames = {} -- unit name in each hotbar slot, filled by rebuildHotbar

-- How many of each unit you have placed right now (the server keeps this up to date)
local function placedCount(name)
	for unit, n in string.gmatch(player:GetAttribute("PlacedCounts") or "", "([^;=]+)=(%d+)") do
		if unit == name then return tonumber(n) end
	end
	return 0
end

local function atLimit(name)
	return placedCount(name) >= UnitData.GetPlacementLimit(name)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local slot = SLOT_KEYS[input.KeyCode]
	if slot then
		if player:GetAttribute("InMatch") ~= true then return end
		local name = hotbarNames[slot]
		if not name then
			showToast("No unit in slot " .. slot .. ".")
		elseif atLimit(name) and selected ~= name then
			showToast(string.format("%s limit reached (%d/%d).", name, placedCount(name), UnitData.GetPlacementLimit(name)))
		elseif selected == name then
			selectUnit(nil) -- same key again puts it away
		else
			selectUnit(name)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Q or input.UserInputType == Enum.UserInputType.MouseButton2 then
		-- Tell MovementController this Q press was a cancel, not a dash
		if input.KeyCode == Enum.KeyCode.Q and (selected or inspected) then
			player:SetAttribute("QConsumedAt", os.clock())
		end
		selectUnit(nil)
		closePanel()
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local hit = mouseRaycast()

	if selected then
		-- Placing a unit
		if hit and placeable and hit.Instance:IsDescendantOf(placeable) then
			local res = placeRemote:InvokeServer(selected, hit.Position)
			if not res.Success then
				showToast(res.Error)
			end
		else
			showToast("Place units on the green plots.")
		end
	else
		-- Inspecting a placed unit
		if hit and unitsFolder and hit.Instance.Parent == unitsFolder then
			if hit.Instance:GetAttribute("OwnerId") == player.UserId then
				openPanel(hit.Instance)
			else
				showToast("That's another player's unit.")
			end
		else
			closePanel()
		end
	end
end)

-- ===== HOTBAR (drawn by the team bar in InventoryUI) =====
-- Tells the team bar which unit you're placing, so it can outline that slot
function refreshHotbarHighlight()
	player:SetAttribute("PlacingUnit", selected or "")
end

-- Stop placing a unit once you've hit its limit
local function refreshHotbarCounts()
	if selected and atLimit(selected) then
		selectUnit(nil)
	end
end

-- The units in team slot order (the "Equipped" attribute is already in slot order), so
-- key 1 is slot 1 on the team bar
local function rebuildHotbar()
	local names = {}
	for name in string.gmatch(player:GetAttribute("Equipped") or "", "[^,]+") do
		if UnitData.GetStats(name) then
			table.insert(names, name)
		end
	end
	hotbarNames = names
end

-- The team bar asks to pick a unit through this event: the same rules as the number keys
local selectEvent = Instance.new("BindableEvent")
selectEvent.Name = "SelectUnit"
selectEvent.Parent = gui
selectEvent.Event:Connect(function(name)
	if player:GetAttribute("InMatch") ~= true or typeof(name) ~= "string" then return end
	if not table.find(hotbarNames, name) then return end
	if selected == name then
		selectUnit(nil) -- clicking the same slot again puts it away
	elseif atLimit(name) then
		showToast(string.format("%s limit reached (%d/%d).", name, placedCount(name), UnitData.GetPlacementLimit(name)))
	else
		selectUnit(name)
	end
end)

rebuildHotbar()
refreshHotbarCounts()
refreshHotbarHighlight()
player:GetAttributeChangedSignal("PlacedCounts"):Connect(refreshHotbarCounts)
local function onTeamChanged()
	rebuildHotbar()
	refreshHotbarCounts()
	if selected and not table.find(hotbarNames, selected) then
		selectUnit(nil) -- the unit you were placing left your team
	else
		refreshHotbarHighlight()
	end
end
player:GetAttributeChangedSignal("Equipped"):Connect(onTeamChanged)
player:GetAttributeChangedSignal("UnitTraits"):Connect(onTeamChanged) -- costs change with traits
player:GetAttributeChangedSignal("UnitProgress"):Connect(onTeamChanged)

-- ===== DAY / NIGHT =====
-- The lobby is night, matches are daylight. LobbyBuilder stores both versions of each lighting
-- setting on Lighting as attributes ("Day_ClockTime" / "Night_ClockTime", ...); this switches
-- your own lighting between them (only on your screen).
local Lighting = game:GetService("Lighting")
local LIGHTING_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local function applyTimeOfDay(day)
	local prefix = day and "Day_" or "Night_"
	for _, prop in ipairs(LIGHTING_PROPS) do
		local value = Lighting:GetAttribute(prefix .. prop)
		if value ~= nil then
			Lighting[prop] = value
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local density = Lighting:GetAttribute(prefix .. "AtmosphereDensity")
	if atmosphere and density then
		atmosphere.Density = density
	end
end

-- ===== MAP LIGHTING =====
-- Each map's theme can have its own lighting (see ArenaThemes). It goes on top of the
-- daylight during a match, only on your screen, and comes off again afterwards.
local ArenaThemes = require(ReplicatedStorage:WaitForChild("ArenaThemes"))
local themeColor = Instance.new("ColorCorrectionEffect")
themeColor.Name = "ArenaThemeColor"
themeColor.Enabled = false
themeColor.Parent = Lighting
local ATMOSPHERE_PROPS = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" }
local atmosphereBefore = nil -- the atmosphere as it was before a map's lighting changed it

local function clearMapLighting()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and atmosphereBefore then
		for prop, value in pairs(atmosphereBefore) do
			atmosphere[prop] = value
		end
	end
	atmosphereBefore = nil
	themeColor.Enabled = false
end

local function applyMapLighting()
	local look = ArenaThemes.Get(player:GetAttribute("ArenaTheme")).Lighting
	if not look then return end
	for _, prop in ipairs(LIGHTING_PROPS) do
		if look[prop] ~= nil then
			Lighting[prop] = look[prop]
		end
	end
	if look.Atmosphere then
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if not atmosphere then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Density = 0
			atmosphere.Parent = Lighting
		end
		atmosphereBefore = {}
		for _, prop in ipairs(ATMOSPHERE_PROPS) do
			atmosphereBefore[prop] = atmosphere[prop]
		end
		for prop, value in pairs(look.Atmosphere) do
			atmosphere[prop] = value
		end
	end
	themeColor.TintColor = look.Tint or Color3.new(1, 1, 1)
	themeColor.Saturation = look.Saturation or 0
	themeColor.Contrast = look.Contrast or 0
	themeColor.Enabled = true
end

-- Day or night, then the map's own lighting on top while in a match
local function updateLighting()
	local inMatch = player:GetAttribute("InMatch") == true
	clearMapLighting()
	applyTimeOfDay(inMatch)
	if inMatch then
		applyMapLighting()
	end
end
player:GetAttributeChangedSignal("ArenaTheme"):Connect(updateLighting)

-- ===== LOBBY vs MATCH =====
-- The HUD and hotbar only show while you're in a match
local function updateMatchVisibility()
	local inMatch = player:GetAttribute("InMatch") == true
	updateLighting()
	hud.Visible = inMatch
	if not inMatch then
		selectUnit(nil)
		closePanel()
	end
end
updateMatchVisibility()
player:GetAttributeChangedSignal("InMatch"):Connect(updateMatchVisibility)

-- Pick up this match's arena as soon as the server assigns it
player:GetAttributeChangedSignal("ArenaId"):Connect(updateArenaRefs)
updateArenaRefs()
