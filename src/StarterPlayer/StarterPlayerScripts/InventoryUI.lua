-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: InventoryUI
-- (replaces the earlier version: every unit is its own slot in a grid, with its own trait,
--  level, stars and lock. Click a unit to see it on the right and lock, equip, fuse,
--  evolve or delete it. The top shows how many of your slots are used.)
-- Lobby only. Locked units can't be deleted or fed. Deleting asks for confirmation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local ProgressData = require(ReplicatedStorage:WaitForChild("ProgressData"))
local inventoryRemote = ReplicatedStorage:WaitForChild("InventoryRemote")
local player = Players.LocalPlayer

local WIDTH, HEIGHT = 780, 580
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local PANEL = Color3.fromRGB(22, 22, 36)
local GLASS = Color3.fromRGB(34, 34, 52)
local SUBTLE = Color3.fromRGB(180, 180, 205)
local DIM = Color3.fromRGB(120, 120, 145)
local GREEN = Color3.fromRGB(60, 160, 90)
local TEAM_GREEN = Color3.fromRGB(110, 230, 140)
local LOCK_GOLD = Color3.fromRGB(255, 215, 80)
local GRAY = Color3.fromRGB(62, 62, 80)
local RED = Color3.fromRGB(190, 70, 70)
local ERROR_COLOR = Color3.fromRGB(255, 130, 130)

local rarityRank, rarityByName = {}, {}
for i, r in ipairs(UnitData.Rarities) do
	rarityRank[r.Name] = i
	rarityByName[r.Name] = r
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

local function button(parent, text, pos, size, color, textSize)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = textSize or 13
	b.TextColor3 = WHITE
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

local function darker(color, amount)
	return color:Lerp(BLACK, amount)
end

local function unitStats(u)
	return ProgressData.Apply(TraitData.StatsFor(u.Name, u.Trait), u.XP, u.Stars)
end

-- ===== Window =====
local gui = Instance.new("ScreenGui")
gui.Name = "InventoryGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1
-- children always draw on top of their parent (so the fuse and delete windows show
-- their contents above the grid)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Open button (left side of the screen)
local openBtn = button(gui, "Inventory", UDim2.new(0, 10, 0.5, -20), UDim2.fromOffset(130, 40), Color3.fromRGB(70, 110, 220), 18)

local window = frame(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(WIDTH, HEIGHT), PANEL)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Visible = false
corner(window, 14)
stroke(window, WHITE, 1, 0.85)
local fit = Instance.new("UIScale")
fit.Parent = window
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	fit.Scale = math.min(1, (vp.X - 20) / WIDTH, (vp.Y - 40) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

label(window, "Inventory", UDim2.fromOffset(18, 10), UDim2.fromOffset(200, 30), 22, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
local closeBtn = button(window, "X", UDim2.new(1, -44, 0, 10), UDim2.fromOffset(32, 32), RED, 15)

-- slot meter: "37 / 100 units" + bar + "+ Slots"
local slotText = label(window, "", UDim2.fromOffset(200, 10), UDim2.fromOffset(250, 18), 14, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
local slotBack = frame(window, UDim2.fromOffset(250, 32), UDim2.fromOffset(200, 6), GLASS)
corner(slotBack, "round")
local slotFill = frame(slotBack, UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), Color3.fromRGB(110, 200, 255))
corner(slotFill, "round")
local moreSlotsBtn = button(window, "+ Slots", UDim2.fromOffset(462, 12), UDim2.fromOffset(84, 28), Color3.fromRGB(70, 130, 220), 13)

local messageLabel = label(window, "", UDim2.new(0, 14, 1, -30), UDim2.new(1, -28, 0, 22), 14, ERROR_COLOR, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
local messageToken = 0
local function showMessage(text, color)
	messageToken += 1
	local mine = messageToken
	messageLabel.Text = text
	messageLabel.TextColor3 = color or ERROR_COLOR
	task.delay(4, function()
		if messageToken == mine then messageLabel.Text = "" end
	end)
end

local function call(action, a, b)
	local ok, res = pcall(function()
		return inventoryRemote:InvokeServer(action, a, b)
	end)
	if not ok or type(res) ~= "table" then
		showMessage("Couldn't reach the server. Try again.")
		return false, {}
	end
	if not res.Success then
		showMessage(res.Error or "That didn't work.")
	end
	return res.Success, res
end

-- ===== Settings: auto-equip + auto-delete =====
local autoEquipBtn = button(window, "", UDim2.fromOffset(14, 52), UDim2.fromOffset(230, 28), GRAY, 13)
autoEquipBtn.Activated:Connect(function()
	call("AutoEquip", not (player:GetAttribute("AutoEquip") == true))
end)

label(window, "Auto-delete new:", UDim2.fromOffset(256, 52), UDim2.fromOffset(110, 28), 13, SUBTLE, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
local autoDeleteButtons = {}
for i, rarity in ipairs(UnitData.Rarities) do
	local b = button(window, rarity.Name, UDim2.fromOffset(366 + (i - 1) * 80, 52), UDim2.fromOffset(76, 28), GRAY, 12)
	autoDeleteButtons[rarity.Name] = b
	b.Activated:Connect(function()
		local on = false
		for name in string.gmatch(player:GetAttribute("AutoDelete") or "", "[^,]+") do
			if name == rarity.Name then on = true end
		end
		call("AutoDelete", rarity.Name, not on)
	end)
end

local function refreshSettings()
	local autoOn = player:GetAttribute("AutoEquip") == true
	autoEquipBtn.Text = autoOn and "Auto-equip best team: ON" or "Auto-equip best team: OFF"
	autoEquipBtn.BackgroundColor3 = autoOn and GREEN or GRAY

	local active = {}
	for name in string.gmatch(player:GetAttribute("AutoDelete") or "", "[^,]+") do
		active[name] = true
	end
	for _, rarity in ipairs(UnitData.Rarities) do
		local b = autoDeleteButtons[rarity.Name]
		if active[rarity.Name] then
			b.BackgroundColor3 = darker(rarity.Color, 0.25)
			b.TextColor3 = WHITE
		else
			b.BackgroundColor3 = GRAY
			b.TextColor3 = rarity.Color
		end
	end
end

-- ===== The grid (left) =====
local GRID_W = 520
local grid = Instance.new("ScrollingFrame")
grid.Position = UDim2.fromOffset(12, 92)
grid.Size = UDim2.fromOffset(GRID_W, HEIGHT - 92 - 36)
grid.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 6
grid.CanvasSize = UDim2.new()
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.Parent = window
corner(grid, 10)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(76, 94)
gridLayout.CellPadding = UDim2.fromOffset(6, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 8)
gridPad.PaddingLeft = UDim.new(0, 8)
gridPad.PaddingBottom = UDim.new(0, 8)
gridPad.Parent = grid

-- ===== The detail panel (right) =====
local detail = frame(window, UDim2.fromOffset(GRID_W + 22, 92), UDim2.fromOffset(WIDTH - GRID_W - 34, HEIGHT - 92 - 36), GLASS)
corner(detail, 10)
local detailHint = label(detail, "Click a unit to see it here.", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14, DIM, Enum.Font.Gotham)
local detailBody = frame(detail, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), WHITE, 1)
detailBody.Visible = false

local DW = WIDTH - GRID_W - 34 - 24 -- usable width inside the detail panel
local dName = label(detailBody, "", UDim2.fromOffset(12, 10), UDim2.fromOffset(DW, 24), 18, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
dName.TextTruncate = Enum.TextTruncate.AtEnd
local dRarity = label(detailBody, "", UDim2.fromOffset(12, 34), UDim2.fromOffset(DW, 16), 12, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
local dLevel = label(detailBody, "", UDim2.fromOffset(12, 54), UDim2.fromOffset(DW, 18), 14, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
local dXPBack = frame(detailBody, UDim2.fromOffset(12, 76), UDim2.fromOffset(DW, 5), PANEL)
corner(dXPBack, "round")
local dXPFill = frame(dXPBack, UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), Color3.fromRGB(110, 200, 255))
corner(dXPFill, "round")
local dStats = label(detailBody, "", UDim2.fromOffset(12, 88), UDim2.fromOffset(DW, 36), 13, SUBTLE, Enum.Font.Gotham, Enum.TextXAlignment.Left)
dStats.TextYAlignment = Enum.TextYAlignment.Top

local dTraitBox = frame(detailBody, UDim2.fromOffset(12, 128), UDim2.fromOffset(DW, 50), PANEL)
corner(dTraitBox, 8)
local dTraitStroke = stroke(dTraitBox, DIM, 1, 0.4)
local dTraitName = label(dTraitBox, "", UDim2.fromOffset(10, 6), UDim2.new(1, -20, 0, 18), 14, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
local dTraitDesc = label(dTraitBox, "", UDim2.fromOffset(10, 26), UDim2.new(1, -20, 0, 18), 12, SUBTLE, Enum.Font.Gotham, Enum.TextXAlignment.Left)
dTraitDesc.TextTruncate = Enum.TextTruncate.AtEnd

local dStatus = label(detailBody, "", UDim2.fromOffset(12, 184), UDim2.fromOffset(DW, 16), 12, TEAM_GREEN, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)

local function actionButton(y, color)
	return button(detailBody, "", UDim2.fromOffset(12, y), UDim2.fromOffset(DW, 32), color, 13)
end
local equipBtn = actionButton(208, GREEN)
local lockBtn = actionButton(246, Color3.fromRGB(70, 110, 190))
local fuseBtn = actionButton(284, Color3.fromRGB(50, 140, 200))
local evolveBtn = actionButton(322, Color3.fromRGB(220, 160, 40))
local deleteBtn = actionButton(360, RED)
local evolveNote = label(detailBody, "", UDim2.fromOffset(12, 396), UDim2.fromOffset(DW, 30), 11, DIM, Enum.Font.Gotham, Enum.TextXAlignment.Left)
evolveNote.TextYAlignment = Enum.TextYAlignment.Top

-- ===== State =====
local units, byId = {}, {}
local equipped = {}  -- [id] = true
local selectedId = nil
local confirmEvolve = false
local openFuse, askDelete -- set further down

local function readState()
	units, byId = UnitData.ParseUnits(player:GetAttribute("Units"))
	equipped = {}
	for id in string.gmatch(player:GetAttribute("EquippedIds") or "", "%d+") do
		equipped[tonumber(id)] = true
	end
	table.sort(units, function(a, b)
		local ra, rb = rarityRank[UnitData.UnitRarity[a.Name]], rarityRank[UnitData.UnitRarity[b.Name]]
		if ra ~= rb then return ra > rb end
		if a.Name ~= b.Name then return a.Name < b.Name end
		if a.Stars ~= b.Stars then return a.Stars > b.Stars end
		if a.XP ~= b.XP then return a.XP > b.XP end
		return a.Id < b.Id
	end)
end

-- Spare copies Evolve would use (same rules as the server: same name, not locked,
-- not on the team, no stars)
local function spareCopies(unit)
	local n = 0
	for _, u in ipairs(units) do
		if u.Id ~= unit.Id and u.Name == unit.Name and not u.Locked and u.Stars == 0 and not equipped[u.Id] then
			n += 1
		end
	end
	return n
end

local function refreshDetail()
	local u = selectedId and byId[selectedId]
	detailHint.Visible = u == nil
	detailBody.Visible = u ~= nil
	if not u then return end

	local rarityName = UnitData.UnitRarity[u.Name]
	local rarity = rarityByName[rarityName]
	local level, into, need = ProgressData.LevelFromXP(u.XP)
	local onTeam = equipped[u.Id] == true
	local autoOn = player:GetAttribute("AutoEquip") == true

	dName.Text = u.Name
	dRarity.Text = rarityName
	dRarity.TextColor3 = rarity.Color
	dLevel.Text = string.format("Lv %d   %s", level, ProgressData.StarText(u.Stars))
	dLevel.TextColor3 = ProgressData.StarColor
	dXPFill.Size = UDim2.fromScale(need > 0 and into / need or 1, 1)
	dXPFill.BackgroundColor3 = need > 0 and Color3.fromRGB(110, 200, 255) or ProgressData.StarColor

	local s = unitStats(u)
	if UnitData.IsFarm(u.Name) then
		dStats.Text = string.format("Cash unit  ·  pays cash every wave\nPlace for $%d", s.Cost)
	else
		dStats.Text = string.format("DMG %d   RNG %d   %.2fs\nPlace for $%d", math.floor(s.Damage), math.floor(s.Range), s.Cooldown, s.Cost)
	end

	local trait = TraitData.Get(u.Trait)
	if trait then
		dTraitName.Text = trait.Name .. "  ·  " .. trait.Tier
		dTraitName.TextColor3 = trait.Color
		dTraitDesc.Text = TraitData.Describe(trait.Name)
		dTraitStroke.Color = trait.Color
	else
		dTraitName.Text = "No trait"
		dTraitName.TextColor3 = SUBTLE
		dTraitDesc.Text = "Summon one in the Traits Cave"
		dTraitStroke.Color = DIM
	end

	local status = {}
	if onTeam then table.insert(status, "ON YOUR TEAM") end
	if u.Locked then table.insert(status, "LOCKED") end
	dStatus.Text = table.concat(status, "  ·  ")
	dStatus.TextColor3 = onTeam and TEAM_GREEN or LOCK_GOLD

	equipBtn.Text = onTeam and "Remove from team" or "Put on team"
	equipBtn.BackgroundColor3 = autoOn and GRAY or (onTeam and Color3.fromRGB(150, 110, 60) or GREEN)
	lockBtn.Text = u.Locked and "Unlock" or "Lock"
	lockBtn.BackgroundColor3 = u.Locked and Color3.fromRGB(200, 160, 40) or Color3.fromRGB(70, 110, 190)
	fuseBtn.Text = level >= ProgressData.MaxLevel and "Max level" or "Fuse (feed units for XP)"
	fuseBtn.BackgroundColor3 = level >= ProgressData.MaxLevel and GRAY or Color3.fromRGB(50, 140, 200)

	local step = ProgressData.Evolutions[u.Stars + 1]
	local spare = spareCopies(u)
	if not step then
		evolveBtn.Text = "Fully evolved"
		evolveBtn.BackgroundColor3 = GRAY
		evolveNote.Text = ""
	else
		local ready = spare >= step.Copies
		evolveBtn.Text = confirmEvolve and string.format("Sure? Uses %d copies + %d Gold", step.Copies, step.Gold)
			or string.format("Evolve  (%d/%d spare copies)", math.min(spare, step.Copies), step.Copies)
		evolveBtn.BackgroundColor3 = confirmEvolve and Color3.fromRGB(200, 90, 60) or (ready and Color3.fromRGB(220, 160, 40) or GRAY)
		evolveNote.Text = string.format("Uses spare %s that aren't locked, on your team or evolved. %d Gold.", u.Name, step.Gold)
	end
	deleteBtn.BackgroundColor3 = u.Locked and GRAY or RED
	deleteBtn.Text = u.Locked and "Delete (unlock first)" or "Delete"
end

-- ===== Tiles =====
local function makeTile(u, order)
	local rarityName = UnitData.UnitRarity[u.Name]
	local color = rarityByName[rarityName].Color
	local isSelected = u.Id == selectedId

	local tile = Instance.new("TextButton")
	tile.LayoutOrder = order
	tile.Text = ""
	tile.AutoButtonColor = true
	tile.BackgroundColor3 = darker(color, 0.62)
	tile.Parent = grid
	corner(tile, 8)
	stroke(tile, isSelected and WHITE or color, isSelected and 2.5 or 1, isSelected and 0 or 0.45)

	local nameLabel = label(tile, u.Name, UDim2.fromOffset(4, 3), UDim2.new(1, -8, 0, 26), 11, WHITE, Enum.Font.GothamBold)
	nameLabel.TextScaled = true
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MaxTextSize = 11
	nameSize.Parent = nameLabel

	local level = ProgressData.LevelFromXP(u.XP)
	label(tile, "Lv " .. level, UDim2.fromOffset(5, 32), UDim2.fromOffset(44, 16), 13, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
	if u.Stars > 0 then
		label(tile, string.rep("★", u.Stars), UDim2.fromOffset(5, 48), UDim2.fromOffset(60, 14), 12, ProgressData.StarColor, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	end

	-- team and lock badges
	local bx = 76 - 18
	if u.Locked then
		local lock = frame(tile, UDim2.fromOffset(bx, 32), UDim2.fromOffset(14, 14), LOCK_GOLD)
		corner(lock, 3)
		label(lock, "L", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, BLACK, Enum.Font.GothamBlack)
		bx -= 17
	end
	if equipped[u.Id] then
		local team = frame(tile, UDim2.fromOffset(bx, 32), UDim2.fromOffset(14, 14), TEAM_GREEN)
		corner(team, "round")
		label(team, "T", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, BLACK, Enum.Font.GothamBlack)
	end

	-- trait strip along the bottom
	local trait = TraitData.Get(u.Trait)
	if trait then
		local strip = frame(tile, UDim2.new(0, 3, 1, -21), UDim2.new(1, -6, 0, 18), darker(trait.Color, 0.55))
		corner(strip, 5)
		stroke(strip, trait.Color, 1, 0.2)
		local t = label(strip, trait.Name, UDim2.fromOffset(3, 0), UDim2.new(1, -6, 1, 0), 10, WHITE, Enum.Font.GothamBlack)
		t.TextTruncate = Enum.TextTruncate.AtEnd
	end

	tile.Activated:Connect(function()
		if selectedId ~= u.Id then
			selectedId = u.Id
			confirmEvolve = false
		end
		-- restyle just the selection instead of rebuilding the whole grid
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("TextButton") then
				local s = c:FindFirstChildOfClass("UIStroke")
				local id = c:GetAttribute("UnitId")
				local cu = byId[id]
				if s and cu then
					local selectedNow = id == selectedId
					s.Color = selectedNow and WHITE or rarityByName[UnitData.UnitRarity[cu.Name]].Color
					s.Thickness = selectedNow and 2.5 or 1
					s.Transparency = selectedNow and 0 or 0.45
				end
			end
		end
		refreshDetail()
	end)
	tile:SetAttribute("UnitId", u.Id)
end

local function emptyTile(order)
	local slot = frame(grid, UDim2.new(), UDim2.new(), WHITE, 1)
	slot.LayoutOrder = order
	corner(slot, 8)
	stroke(slot, WHITE, 1, 0.9)
end

local function rebuildGrid()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local maxSlots = player:GetAttribute("MaxSlots") or UnitData.BaseSlots
	for i, u in ipairs(units) do
		makeTile(u, i)
	end
	for i = #units + 1, maxSlots do
		emptyTile(i)
	end

	local used = #units
	slotText.Text = string.format("%d / %d units", used, maxSlots)
	slotText.TextColor3 = used >= maxSlots and ERROR_COLOR or WHITE
	slotFill.Size = UDim2.fromScale(math.clamp(used / math.max(1, maxSlots), 0, 1), 1)
	slotFill.BackgroundColor3 = used >= maxSlots and ERROR_COLOR or (used / maxSlots > 0.85 and LOCK_GOLD or Color3.fromRGB(110, 200, 255))
end

-- ===== Detail actions =====
equipBtn.Activated:Connect(function()
	local u = selectedId and byId[selectedId]
	if not u then return end
	if player:GetAttribute("AutoEquip") == true then
		showMessage("Turn off auto-equip to pick your team by hand.")
		return
	end
	call("Equip", u.Id, not equipped[u.Id])
end)

lockBtn.Activated:Connect(function()
	local u = selectedId and byId[selectedId]
	if u then call("Lock", u.Id, not u.Locked) end
end)

fuseBtn.Activated:Connect(function()
	local u = selectedId and byId[selectedId]
	if not u then return end
	if ProgressData.LevelFromXP(u.XP) >= ProgressData.MaxLevel then
		showMessage(u.Name .. " is already max level.")
		return
	end
	openFuse(u.Id)
end)

evolveBtn.Activated:Connect(function()
	local u = selectedId and byId[selectedId]
	if not u then return end
	local step = ProgressData.Evolutions[u.Stars + 1]
	if not step then
		showMessage(u.Name .. " is fully evolved.")
		return
	end
	if spareCopies(u) < step.Copies then
		showMessage(string.format("Evolving needs %d spare %s and %d Gold.", step.Copies, u.Name, step.Gold))
		return
	end
	if not confirmEvolve then
		confirmEvolve = true
		refreshDetail()
		return
	end
	confirmEvolve = false
	if call("Evolve", u.Id) then
		showMessage(string.format("%s evolved to %s!", u.Name, ProgressData.StarText(u.Stars + 1)), ProgressData.StarColor)
	end
	refreshDetail()
end)

deleteBtn.Activated:Connect(function()
	local u = selectedId and byId[selectedId]
	if not u then return end
	if u.Locked then
		showMessage("Unlock " .. u.Name .. " before deleting it.")
		return
	end
	askDelete(u)
end)

-- ===== Delete confirmation =====
local modal = frame(window, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), BLACK, 0.45)
modal.Active = true -- blocks clicks underneath
modal.ZIndex = 10
modal.Visible = false
corner(modal, 14)
local dialog = frame(modal, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(360, 170), Color3.fromRGB(35, 35, 55))
dialog.AnchorPoint = Vector2.new(0.5, 0.5)
corner(dialog, 12)
local dialogText = label(dialog, "", UDim2.fromOffset(16, 14), UDim2.new(1, -32, 0, 80), 16, WHITE, Enum.Font.GothamBold)
local confirmDelete = button(dialog, "Delete", UDim2.fromOffset(16, 112), UDim2.fromOffset(156, 42), RED, 15)
local cancelDelete = button(dialog, "Cancel", UDim2.fromOffset(188, 112), UDim2.fromOffset(156, 42), GRAY, 15)
local pendingDelete = nil

askDelete = function(u)
	pendingDelete = u.Id
	local level = ProgressData.LevelFromXP(u.XP)
	local extra = u.Trait and (", " .. u.Trait) or ""
	dialogText.Text = string.format("Delete %s (Lv %d%s)?\nThis can't be undone.", u.Name, level, extra)
	modal.Visible = true
end
local function closeDialog()
	modal.Visible = false
	pendingDelete = nil
end
confirmDelete.Activated:Connect(function()
	local id = pendingDelete
	closeDialog()
	if id and call("Delete", { id }) then
		if selectedId == id then selectedId = nil end
	end
end)
cancelDelete.Activated:Connect(closeDialog)

-- ===== Fuse window =====
-- Pick which units to feed into the selected unit, then press FUSE.
local fuseTarget = nil
local fuseSelection = {} -- [id] = true

local fuseWin = frame(window, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(18, 24, 36))
fuseWin.Active = true
fuseWin.ZIndex = 10
fuseWin.Visible = false
corner(fuseWin, 14)

local fuseTitle = label(fuseWin, "", UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 30), 22, WHITE, Enum.Font.GothamBlack)
local fuseInfo = label(fuseWin, "", UDim2.fromOffset(10, 40), UDim2.new(1, -20, 0, 20), 15, Color3.fromRGB(110, 200, 255))
local fuseClose = button(fuseWin, "X", UDim2.new(1, -44, 0, 10), UDim2.fromOffset(32, 32), RED, 15)
local addCommons = button(fuseWin, "Add spare Commons", UDim2.fromOffset(14, 70), UDim2.fromOffset(170, 28), Color3.fromRGB(110, 110, 125), 13)
local addRares = button(fuseWin, "Add spare Rares", UDim2.fromOffset(190, 70), UDim2.fromOffset(150, 28), Color3.fromRGB(60, 110, 190), 13)
local clearBtn = button(fuseWin, "Clear", UDim2.fromOffset(346, 70), UDim2.fromOffset(80, 28), GRAY, 13)
label(fuseWin, "Spare = Lv 1, no trait, no stars. Locked units and your team never show here.",
	UDim2.fromOffset(434, 70), UDim2.new(1, -448, 0, 28), 11, DIM, Enum.Font.Gotham, Enum.TextXAlignment.Left)

local fuseList = Instance.new("ScrollingFrame")
fuseList.Position = UDim2.fromOffset(14, 106)
fuseList.Size = UDim2.new(1, -28, 1, -170)
fuseList.BackgroundTransparency = 1
fuseList.BorderSizePixel = 0
fuseList.ScrollBarThickness = 6
fuseList.CanvasSize = UDim2.new()
fuseList.AutomaticCanvasSize = Enum.AutomaticSize.Y
fuseList.Parent = fuseWin
local fuseGrid = Instance.new("UIGridLayout")
fuseGrid.CellSize = UDim2.new(0.5, -4, 0, 32)
fuseGrid.CellPadding = UDim2.fromOffset(8, 4)
fuseGrid.SortOrder = Enum.SortOrder.LayoutOrder
fuseGrid.Parent = fuseList

local fuseGo = button(fuseWin, "FUSE", UDim2.new(0.5, -110, 1, -54), UDim2.fromOffset(220, 42), Color3.fromRGB(50, 160, 90), 18)

local function canFeed(u)
	return u.Id ~= fuseTarget and not u.Locked and not equipped[u.Id]
end

local function isSpare(u)
	return canFeed(u) and u.XP == 0 and u.Stars == 0 and not u.Trait
end

local function selectionXP()
	local total = 0
	for id in pairs(fuseSelection) do
		local u = byId[id]
		if u then total += ProgressData.FodderXP[UnitData.UnitRarity[u.Name]] end
	end
	return total
end

local function refreshFuse()
	local target = fuseTarget and byId[fuseTarget]
	if not target then
		fuseWin.Visible = false
		fuseTarget = nil
		return
	end
	-- drop picks that are gone or no longer allowed
	for id in pairs(fuseSelection) do
		local u = byId[id]
		if not u or not canFeed(u) then fuseSelection[id] = nil end
	end

	local count = 0
	for _ in pairs(fuseSelection) do count += 1 end
	local gain = selectionXP()
	local before = ProgressData.LevelFromXP(target.XP)
	local after = ProgressData.LevelFromXP(math.min(target.XP + gain, ProgressData.MaxXP()))
	fuseTitle.Text = "Fuse into " .. target.Name
	fuseInfo.Text = gain > 0 and string.format("Lv %d  ->  Lv %d   (+%d XP from %d unit%s)", before, after, gain, count, count == 1 and "" or "s")
		or string.format("Lv %d   -   pick units below to feed in", before)
	fuseGo.Text = count > 0 and string.format("FUSE %d", count) or "FUSE"
	fuseGo.BackgroundColor3 = gain > 0 and Color3.fromRGB(50, 160, 90) or GRAY

	for _, c in ipairs(fuseList:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local order = 0
	for i = #units, 1, -1 do -- weakest first: they're the usual food
		local u = units[i]
		if canFeed(u) then
			order += 1
			local picked = fuseSelection[u.Id] == true
			local rarityName = UnitData.UnitRarity[u.Name]
			local color = rarityByName[rarityName].Color
			local row = Instance.new("TextButton")
			row.LayoutOrder = order
			row.Text = ""
			row.AutoButtonColor = true
			row.BackgroundColor3 = darker(color, picked and 0.45 or 0.78)
			row.Parent = fuseList
			corner(row, 6)
			if picked then stroke(row, Color3.fromRGB(110, 200, 255), 2) end

			local box = frame(row, UDim2.fromOffset(8, 9), UDim2.fromOffset(14, 14), picked and Color3.fromRGB(110, 200, 255) or PANEL)
			corner(box, 3)
			stroke(box, WHITE, 1, 0.5)
			local extra = ""
			if u.Trait then extra ..= " [" .. u.Trait .. "]" end
			if u.Stars > 0 then extra ..= " " .. string.rep("★", u.Stars) end
			local n = label(row, string.format("%s  Lv %d%s", u.Name, ProgressData.LevelFromXP(u.XP), extra),
				UDim2.fromOffset(30, 0), UDim2.new(1, -96, 1, 0), 12, color, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
			n.TextTruncate = Enum.TextTruncate.AtEnd
			label(row, "+" .. ProgressData.FodderXP[rarityName] .. " XP", UDim2.new(1, -66, 0, 0), UDim2.new(0, 60, 1, 0), 12,
				Color3.fromRGB(110, 200, 255), Enum.Font.GothamBold, Enum.TextXAlignment.Right)

			row.Activated:Connect(function()
				fuseSelection[u.Id] = not picked or nil
				refreshFuse()
			end)
		end
	end
	if order == 0 then
		local holder = frame(fuseList, UDim2.new(), UDim2.new(), WHITE, 1)
		holder.LayoutOrder = 1
		label(holder, "No units to feed in.", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 14, DIM, Enum.Font.Gotham)
	end
end

local function addSpares(rarityName)
	for _, u in ipairs(units) do
		if UnitData.UnitRarity[u.Name] == rarityName and isSpare(u) then
			fuseSelection[u.Id] = true
		end
	end
	refreshFuse()
end

addCommons.Activated:Connect(function() addSpares("Common") end)
addRares.Activated:Connect(function() addSpares("Rare") end)
clearBtn.Activated:Connect(function()
	table.clear(fuseSelection)
	refreshFuse()
end)
fuseClose.Activated:Connect(function()
	fuseWin.Visible = false
	fuseTarget = nil
end)

fuseGo.Activated:Connect(function()
	local target = fuseTarget and byId[fuseTarget]
	if not target then return end
	local ids = {}
	for id in pairs(fuseSelection) do
		table.insert(ids, id)
	end
	if #ids == 0 then
		showMessage("Pick some units to feed in first.")
		return
	end
	local ok, res = call("Fuse", target.Id, ids)
	if ok then
		table.clear(fuseSelection)
		showMessage(string.format("%s gained %d XP!", target.Name, res.XP or 0), Color3.fromRGB(110, 200, 255))
	end
end)

openFuse = function(id)
	confirmEvolve = false
	fuseTarget = id
	table.clear(fuseSelection)
	fuseWin.Visible = true
	refreshFuse()
end

-- ===== More slots (game passes) =====
moreSlotsBtn.Activated:Connect(function()
	local any = false
	for _, pass in ipairs(UnitData.SlotPasses) do
		if pass.Id and pass.Id ~= 0 then
			any = true
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and not owns then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				return
			end
		end
	end
	showMessage(any and "You already own every slot pass." or "Slot passes aren't available yet.", SUBTLE)
end)

-- ===== Rebuild =====
local function rebuild()
	readState()
	if selectedId and not byId[selectedId] then
		selectedId = nil
		confirmEvolve = false
	end
	if pendingDelete and not byId[pendingDelete] then closeDialog() end
	refreshSettings()
	rebuildGrid()
	refreshDetail()
	if fuseWin.Visible then refreshFuse() end
end

-- Several attributes change together; rebuild once per frame
local rebuildQueued = false
local function scheduleRebuild()
	if rebuildQueued then return end
	rebuildQueued = true
	task.defer(function()
		rebuildQueued = false
		rebuild()
	end)
end

rebuild()
for _, attribute in ipairs({ "Units", "EquippedIds", "AutoEquip", "AutoDelete", "MaxSlots", "Gold" }) do
	player:GetAttributeChangedSignal(attribute):Connect(scheduleRebuild)
end

openBtn.Activated:Connect(function()
	window.Visible = not window.Visible
end)
closeBtn.Activated:Connect(function()
	window.Visible = false
end)

-- Lobby only
local function updateVisibility()
	local inMatch = player:GetAttribute("InMatch") == true
	openBtn.Visible = not inMatch
	if inMatch then
		window.Visible = false
		closeDialog()
		fuseWin.Visible = false
	end
end
updateVisibility()
player:GetAttributeChangedSignal("InMatch"):Connect(updateVisibility)
