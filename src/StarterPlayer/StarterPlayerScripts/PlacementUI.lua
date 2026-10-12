-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: PlacementUI
-- (replaces the earlier version: adds the click-a-unit upgrade/sell panel)
-- HUD (wave, base HP, cash), unit hotbar, click-to-place with a range preview.
-- Controls: click a unit in the hotbar, then click a green plot to place it.
-- Click a placed unit (with nothing selected) to upgrade or sell it.
-- Keys 1-6 pick the unit in that hotbar slot (press the same key again to put it away).
-- Q or right-click cancels / closes. (When nothing is open, Q is sprint/dash: see MovementController.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local placeRemote = ReplicatedStorage:WaitForChild("PlaceUnitRemote")
local actionRemote = ReplicatedStorage:WaitForChild("UnitActionRemote")
local placeable = nil   -- this match's PlaceableArea (set when a match starts)
local unitsFolder = nil -- this match's Units folder

local player = Players.LocalPlayer
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
toast.Position = UDim2.new(0.5, -160, 1, -130)
toast.BackgroundTransparency = 1
toast.TextColor3 = Color3.fromRGB(255, 120, 120)
toast.TextStrokeTransparency = 0.5
toast.Font = Enum.Font.GothamBold
toast.TextSize = 18
toast.Text = ""
toast.Parent = gui

local hotbar = Instance.new("Frame")
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
for _, name in ipairs({ "MatchStatus", "BaseHealth", "Wave", "MaxWave" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshHud)
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshHud)

-- ===== UPGRADE / SELL PANEL =====
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(210, 190)
panel.Position = UDim2.new(1, -230, 0.5, -95)
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
local panelStats = panelLabel(36, 56, 14)
local upgradeBtn = panelButton(92, Color3.fromRGB(60, 160, 90))
local sellBtn = panelButton(138, Color3.fromRGB(190, 70, 70))

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

local function closePanel()
	panel.Visible = false
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
	local statsText = string.format("Damage: %d\nRange: %.1f", math.floor(damage), range)
	if inspected:GetAttribute("HighGround") then
		statsText ..= "\nHigh ground bonus!"
	end
	panelStats.Text = statsText
	upgradeBtn.Text = cost >= 0 and string.format("Upgrade ($%d)", cost) or "MAX LEVEL"
	sellBtn.Text = string.format("Sell (+$%d)", sellValue)

	rangeRing.Size = Vector3.new(0.2, range * 2, range * 2)
	rangeRing.CFrame = CFrame.new(inspected.Position - Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function openPanel(part)
	closePanel()
	inspected = part
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
		selectedRange = UnitData.GetStats(name).Range
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local slot = SLOT_KEYS[input.KeyCode]
	if slot then
		if player:GetAttribute("InMatch") ~= true then return end
		local name = hotbarNames[slot]
		if not name then
			showToast("No unit in slot " .. slot .. ".")
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

-- ===== HOTBAR =====
local hotbarButtons = {} -- [unit name] = its hotbar button

-- Outlines the hotbar slot of the unit you're currently placing
function refreshHotbarHighlight()
	for name, b in pairs(hotbarButtons) do
		b.UIStroke.Enabled = name == selected
	end
end

local function rebuildHotbar()
	for _, c in ipairs(hotbar:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	local names = {}
	for name in string.gmatch(player:GetAttribute("Equipped") or "", "[^,]+") do
		if UnitData.GetStats(name) then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		local ca, cb = UnitData.GetStats(a).Cost, UnitData.GetStats(b).Cost
		if ca ~= cb then return ca < cb end
		return a < b
	end)

	hotbarNames = names
	table.clear(hotbarButtons)

	for i, name in ipairs(names) do
		local stats = UnitData.GetStats(name)
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(100, 64)
		b.BackgroundColor3 = UnitData.RarityColor[UnitData.UnitRarity[name]]
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextStrokeTransparency = 0.2
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.TextWrapped = true
		b.Text = string.format("[%d] %s\n$%d", i, name, stats.Cost)
		b.Parent = hotbar
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 3
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Enabled = false
		stroke.Parent = b
		hotbarButtons[name] = b
		b.Activated:Connect(function()
			selectUnit(name)
		end)
	end
end
rebuildHotbar()
refreshHotbarHighlight()
player:GetAttributeChangedSignal("Equipped"):Connect(function()
	rebuildHotbar()
	if selected and not hotbarButtons[selected] then
		selectUnit(nil) -- the unit you were placing left your team
	else
		refreshHotbarHighlight()
	end
end)

-- ===== LOBBY vs MATCH =====
-- The HUD and hotbar only show while you're in a match
local function updateMatchVisibility()
	local inMatch = player:GetAttribute("InMatch") == true
	hud.Visible = inMatch
	hotbar.Visible = inMatch
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
