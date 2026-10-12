-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: InventoryUI
-- (replaces the earlier version: adds unit traits - each card shows its trait and has a
--  Roll button (costs Gold), and "Trait Odds" lists every trait with its chance)
-- Lobby only. Locked units can't be deleted. Deleting asks for confirmation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local inventoryRemote = ReplicatedStorage:WaitForChild("InventoryRemote")
local player = Players.LocalPlayer

local GREEN = Color3.fromRGB(60, 160, 90)
local GRAY = Color3.fromRGB(55, 55, 72)

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1
-- children always draw on top of their parent (so the Trait Odds and delete windows show
-- their contents above the cards)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Open button (left side of the screen)
local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(130, 40)
button.Position = UDim2.new(0, 10, 0.5, -20)
button.Text = "Inventory"
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.TextColor3 = Color3.new(1, 1, 1)
button.BackgroundColor3 = Color3.fromRGB(70, 110, 220)
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

-- Window
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(560, 540)
frame.Position = UDim2.new(0.5, -280, 0.5, -270)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
frame.Visible = false
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function plainLabel(parent, text, pos, size, textSize, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextWrapped = true
	l.Parent = parent
	return l
end

plainLabel(frame, "Inventory", UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 34), 22)
local summary = plainLabel(frame, "", UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 22), 15, Color3.fromRGB(200, 200, 220))
summary.Font = Enum.Font.Gotham

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(32, 32)
close.Position = UDim2.new(1, -40, 0, 6)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromRGB(190, 70, 70)
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)

local ERROR_COLOR = Color3.fromRGB(255, 130, 130)
local message = plainLabel(frame, "", UDim2.new(0, 10, 1, -32), UDim2.new(1, -20, 0, 24), 15, ERROR_COLOR)
local messageToken = 0
local function showMessage(text, color)
	messageToken += 1
	local mine = messageToken
	message.Text = text
	message.TextColor3 = color or ERROR_COLOR
	task.delay(3, function()
		if messageToken == mine then message.Text = "" end
	end)
end

button.Activated:Connect(function() frame.Visible = not frame.Visible end)
close.Activated:Connect(function() frame.Visible = false end)

-- ===== Settings: auto-equip + auto-delete =====
local function call(action, name, arg)
	local res = inventoryRemote:InvokeServer(action, name, arg)
	if not res.Success then
		showMessage(res.Error or "That didn't work.")
	end
	return res.Success, res
end

local autoEquipBtn = Instance.new("TextButton")
autoEquipBtn.Position = UDim2.fromOffset(10, 64)
autoEquipBtn.Size = UDim2.fromOffset(300, 28)
autoEquipBtn.Font = Enum.Font.GothamBold
autoEquipBtn.TextSize = 14
autoEquipBtn.TextColor3 = Color3.new(1, 1, 1)
autoEquipBtn.Parent = frame
Instance.new("UICorner", autoEquipBtn).CornerRadius = UDim.new(0, 6)
autoEquipBtn.Activated:Connect(function()
	call("AutoEquip", "", not (player:GetAttribute("AutoEquip") == true))
end)

local deleteLabel = plainLabel(frame, "Auto-delete:", UDim2.fromOffset(10, 98), UDim2.fromOffset(90, 28), 14)
deleteLabel.TextXAlignment = Enum.TextXAlignment.Left

local autoDeleteButtons = {}
for i, rarity in ipairs(UnitData.Rarities) do
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(100 + (i - 1) * 88, 98)
	b.Size = UDim2.fromOffset(86, 28)
	b.Text = rarity.Name
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Parent = frame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
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
	autoEquipBtn.Text = autoOn and "Auto-equip best damage: ON" or "Auto-equip best damage: OFF"
	autoEquipBtn.BackgroundColor3 = autoOn and GREEN or GRAY

	local active = {}
	for name in string.gmatch(player:GetAttribute("AutoDelete") or "", "[^,]+") do
		active[name] = true
	end
	for _, rarity in ipairs(UnitData.Rarities) do
		local b = autoDeleteButtons[rarity.Name]
		if active[rarity.Name] then
			b.BackgroundColor3 = rarity.Color:Lerp(Color3.new(0, 0, 0), 0.25)
			b.TextColor3 = Color3.new(1, 1, 1)
		else
			b.BackgroundColor3 = GRAY
			b.TextColor3 = rarity.Color
		end
	end
end

-- ===== Unit list =====
local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(10, 136)
scroll.Size = UDim2.new(1, -20, 1, -176)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = frame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(170, 164)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll

local emptyLabel = plainLabel(frame, "Your inventory is empty.\nWalk onto the Summon Altar to get your first units!",
	UDim2.new(0.5, -200, 0.5, -10), UDim2.fromOffset(400, 80), 18, Color3.fromRGB(170, 170, 190))
emptyLabel.Visible = false

-- ===== Delete confirmation =====
local modal = Instance.new("Frame")
modal.Size = UDim2.fromScale(1, 1)
modal.BackgroundColor3 = Color3.new(0, 0, 0)
modal.BackgroundTransparency = 0.45
modal.Active = true -- blocks clicks on the cards underneath
modal.ZIndex = 10
modal.Visible = false
modal.Parent = frame
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 12)

local dialog = Instance.new("Frame")
dialog.Size = UDim2.fromOffset(340, 170)
dialog.Position = UDim2.new(0.5, -170, 0.5, -85)
dialog.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
dialog.Parent = modal
Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 10)

local dialogText = plainLabel(dialog, "", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 70), 16)

local function dialogButton(text, x, width, color)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, 110)
	b.Size = UDim2.fromOffset(width, 40)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.Parent = dialog
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local deleteOne = dialogButton("Delete 1", 12, 96, Color3.fromRGB(190, 70, 70))
local deleteAll = dialogButton("Delete all", 118, 104, Color3.fromRGB(150, 40, 40))
local cancel = dialogButton("Cancel", 232, 96, Color3.fromRGB(80, 80, 100))

local pendingDelete = nil

local function closeDialog()
	modal.Visible = false
	pendingDelete = nil
end

local function askDelete(name, count)
	pendingDelete = name
	if count > 1 then
		dialogText.Text = string.format("Delete %s?\nYou own %d copies. This can't be undone.", name, count)
		deleteOne.Text = "Delete 1"
		deleteAll.Visible = true
	else
		dialogText.Text = string.format("Delete %s?\nThis can't be undone.", name)
		deleteOne.Text = "Delete"
		deleteAll.Visible = false
	end
	modal.Visible = true
end

local function runDelete(amount)
	local name = pendingDelete
	closeDialog()
	if name then
		call("Delete", name, amount)
	end
end

deleteOne.Activated:Connect(function() runDelete(1) end)
deleteAll.Activated:Connect(function() runDelete("All") end)
cancel.Activated:Connect(closeDialog)

-- ===== Cards =====
local function parseCounts()
	local counts = {}
	for name, n in string.gmatch(player:GetAttribute("UnitCounts") or "", "([^;=]+)=(%d+)") do
		counts[name] = tonumber(n)
	end
	return counts
end

local function parseSet(attribute, separator)
	local set = {}
	for name in string.gmatch(player:GetAttribute(attribute) or "", "[^" .. separator .. "]+") do
		set[name] = true
	end
	return set
end

local function addLabel(parent, text, pos, size, textSize, color, align)
	local l = plainLabel(parent, text, pos, size, textSize, color)
	l.TextWrapped = false
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	return l
end

local function cardButton(parent, text, x, color, y, width)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, y or 108)
	b.Size = UDim2.fromOffset(width or 50, 24)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

-- Clicking Roll on a unit with a Legendary or Mythic trait asks you to click again
local confirmRoll = nil

local function makeCard(name, rarity, count, locked, equipped, autoEquipOn, order, traitName)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.BackgroundColor3 = rarity.Color:Lerp(Color3.new(0, 0, 0), 0.5)
	card.Parent = scroll
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = locked and Color3.fromRGB(255, 215, 80) or (equipped and Color3.fromRGB(110, 230, 140) or rarity.Color)
	stroke.Parent = card

	addLabel(card, name, UDim2.fromOffset(8, 6), UDim2.new(1, -50, 0, 20), 15)
	addLabel(card, "x" .. count, UDim2.new(1, -46, 0, 6), UDim2.fromOffset(40, 20), 15, Color3.new(1, 1, 1), Enum.TextXAlignment.Right)
	addLabel(card, locked and (rarity.Name .. "  -  LOCKED") or rarity.Name,
		UDim2.fromOffset(8, 28), UDim2.new(1, -16, 0, 16), 12, locked and Color3.fromRGB(255, 215, 80) or rarity.Color)

	local s = TraitData.StatsFor(name, traitName)
	local statLine = UnitData.IsFarm(name) and "Cash unit"
		or string.format("DMG %d   RNG %d", math.floor(s.Damage), math.floor(s.Range))
	addLabel(card, statLine, UDim2.fromOffset(8, 50), UDim2.new(1, -16, 0, 16), 13, Color3.fromRGB(230, 230, 240))
	addLabel(card, string.format("Cost $%d", s.Cost),
		UDim2.fromOffset(8, 68), UDim2.new(1, -16, 0, 16), 13, Color3.fromRGB(230, 230, 240))
	if equipped then
		addLabel(card, "TEAM", UDim2.new(1, -54, 0, 68), UDim2.fromOffset(46, 16), 12, Color3.fromRGB(110, 230, 140), Enum.TextXAlignment.Right)
	end

	local trait = TraitData.Get(traitName)
	local traitLabel = addLabel(card, trait and ("Trait: " .. trait.Name) or "No trait",
		UDim2.fromOffset(8, 86), UDim2.new(1, -16, 0, 16), 13, trait and trait.Color or Color3.fromRGB(150, 150, 165))
	if trait and trait.Tier == "Mythic" then
		local glow = Instance.new("UIStroke")
		glow.Color = trait.Color
		glow.Thickness = 1
		glow.Parent = traitLabel
	end

	local lockBtn = cardButton(card, locked and "Unlock" or "Lock", 6,
		locked and Color3.fromRGB(200, 160, 40) or Color3.fromRGB(70, 110, 190))
	local deleteBtn = cardButton(card, "Delete", 60,
		locked and Color3.fromRGB(80, 80, 90) or Color3.fromRGB(190, 70, 70))
	local equipBtn = cardButton(card, equipped and "Remove" or "Equip", 114,
		autoEquipOn and Color3.fromRGB(80, 80, 90) or (equipped and Color3.fromRGB(150, 110, 60) or GREEN))

	local rollBtn = cardButton(card, string.format("Roll Trait (%d Gold)", TraitData.RollCost), 6,
		Color3.fromRGB(120, 80, 200), 136, 158)
	if confirmRoll == name and trait then
		rollBtn.Text = "Click again to confirm"
		rollBtn.BackgroundColor3 = Color3.fromRGB(200, 90, 60)
	end

	lockBtn.Activated:Connect(function()
		call("Lock", name, not locked)
	end)

	rollBtn.Activated:Connect(function()
		-- don't throw away a great trait by accident
		if trait and (trait.Tier == "Mythic" or trait.Tier == "Legendary") and confirmRoll ~= name then
			confirmRoll = name
			rollBtn.Text = "Click again to confirm"
			rollBtn.BackgroundColor3 = Color3.fromRGB(200, 90, 60)
			return
		end
		confirmRoll = nil
		local ok, res = call("RollTrait", name)
		if ok and res.Trait then
			local got = TraitData.Get(res.Trait)
			showMessage(string.format("%s rolled %s %s! (%s)", name, got.Tier, got.Name, TraitData.Describe(got.Name)), got.Color)
		end
	end)

	deleteBtn.Activated:Connect(function()
		if locked then
			showMessage("Unlock " .. name .. " before deleting it.")
		else
			askDelete(name, count)
		end
	end)

	equipBtn.Activated:Connect(function()
		if autoEquipOn then
			showMessage("Turn off auto-equip to pick your team by hand.")
		else
			call("Equip", name, not equipped)
		end
	end)
end

-- ===== Trait odds =====
local oddsBtn = Instance.new("TextButton")
oddsBtn.Position = UDim2.fromOffset(320, 64)
oddsBtn.Size = UDim2.fromOffset(150, 28)
oddsBtn.Text = "Trait Odds"
oddsBtn.Font = Enum.Font.GothamBold
oddsBtn.TextSize = 14
oddsBtn.TextColor3 = Color3.new(1, 1, 1)
oddsBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 200)
oddsBtn.Parent = frame
Instance.new("UICorner", oddsBtn).CornerRadius = UDim.new(0, 6)

local odds = Instance.new("Frame")
odds.Size = UDim2.fromScale(1, 1)
odds.BackgroundColor3 = Color3.fromRGB(20, 18, 34)
odds.Active = true
odds.ZIndex = 10
odds.Visible = false
odds.Parent = frame
Instance.new("UICorner", odds).CornerRadius = UDim.new(0, 12)

plainLabel(odds, "Trait Odds", UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 30), 22)
plainLabel(odds, string.format("Each roll costs %d Gold and replaces the unit's current trait.", TraitData.RollCost),
	UDim2.fromOffset(10, 38), UDim2.new(1, -20, 0, 20), 14, Color3.fromRGB(200, 200, 220)).Font = Enum.Font.Gotham

local oddsClose = Instance.new("TextButton")
oddsClose.Size = UDim2.fromOffset(32, 32)
oddsClose.Position = UDim2.new(1, -40, 0, 6)
oddsClose.Text = "X"
oddsClose.Font = Enum.Font.GothamBold
oddsClose.TextSize = 16
oddsClose.TextColor3 = Color3.new(1, 1, 1)
oddsClose.BackgroundColor3 = Color3.fromRGB(190, 70, 70)
oddsClose.Parent = odds
Instance.new("UICorner", oddsClose).CornerRadius = UDim.new(0, 8)

local oddsList = Instance.new("ScrollingFrame")
oddsList.Position = UDim2.fromOffset(10, 66)
oddsList.Size = UDim2.new(1, -20, 1, -76)
oddsList.BackgroundTransparency = 1
oddsList.BorderSizePixel = 0
oddsList.ScrollBarThickness = 6
oddsList.CanvasSize = UDim2.new()
oddsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
oddsList.Parent = odds
local oddsLayout = Instance.new("UIListLayout")
oddsLayout.Padding = UDim.new(0, 4)
oddsLayout.SortOrder = Enum.SortOrder.LayoutOrder
oddsLayout.Parent = oddsList

-- rarest tier first
local row = 0
for i = #TraitData.Tiers, 1, -1 do
	local tier = TraitData.Tiers[i]
	row += 1
	local header = plainLabel(oddsList, tier.Name, UDim2.new(), UDim2.new(1, -10, 0, 24), 17, tier.Color)
	header.LayoutOrder = row
	header.TextXAlignment = Enum.TextXAlignment.Left
	for _, trait in ipairs(TraitData.Traits) do
		if trait.Tier == tier.Name then
			row += 1
			local r = Instance.new("Frame")
			r.LayoutOrder = row
			r.Size = UDim2.new(1, -10, 0, 26)
			r.BackgroundColor3 = tier.Color:Lerp(Color3.new(0, 0, 0), 0.75)
			r.Parent = oddsList
			Instance.new("UICorner", r).CornerRadius = UDim.new(0, 6)
			addLabel(r, trait.Name, UDim2.fromOffset(8, 0), UDim2.new(0, 120, 1, 0), 14, tier.Color)
			addLabel(r, TraitData.Describe(trait.Name), UDim2.fromOffset(130, 0), UDim2.new(1, -210, 1, 0), 13, Color3.fromRGB(230, 230, 240))
			addLabel(r, TraitData.ChanceText(trait.Name), UDim2.new(1, -78, 0, 0), UDim2.new(0, 70, 1, 0), 14, Color3.new(1, 1, 1), Enum.TextXAlignment.Right)
		end
	end
end

oddsBtn.Activated:Connect(function() odds.Visible = true end)
oddsClose.Activated:Connect(function() odds.Visible = false end)

local function rebuild()
	closeDialog() -- the unit under the dialog may have changed
	refreshSettings()
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	local counts = parseCounts()
	local locks = parseSet("UnitLocks", ";")
	local equippedSet = parseSet("Equipped", ",")
	local traits = TraitData.Parse(player:GetAttribute("UnitTraits"))
	local autoEquipOn = player:GetAttribute("AutoEquip") == true
	local types, copies, order, teamSize = 0, 0, 0, 0

	-- Only units you own show up, rarest first
	for i = #UnitData.Rarities, 1, -1 do
		local rarity = UnitData.Rarities[i]
		local list = table.clone(UnitData.Units[rarity.Name])
		table.sort(list)
		for _, name in ipairs(list) do
			local count = counts[name]
			if count and count > 0 then
				types += 1
				copies += count
				order += 1
				local isEquipped = equippedSet[name] == true
				if isEquipped then teamSize += 1 end
				makeCard(name, rarity, count, locks[name] == true, isEquipped, autoEquipOn, order, traits[name])
			end
		end
	end

	emptyLabel.Visible = types == 0
	summary.Text = types == 0 and "No units yet"
		or string.format("%d unique   |   %d total   |   Team %d/%d", types, copies, teamSize, UnitData.TeamSize)
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
for _, attribute in ipairs({ "UnitCounts", "UnitLocks", "Equipped", "AutoEquip", "AutoDelete", "UnitTraits" }) do
	player:GetAttributeChangedSignal(attribute):Connect(scheduleRebuild)
end

-- Lobby only
local function updateVisibility()
	local inMatch = player:GetAttribute("InMatch") == true
	button.Visible = not inMatch
	if inMatch then
		frame.Visible = false
		closeDialog()
	end
end
updateVisibility()
player:GetAttributeChangedSignal("InMatch"):Connect(updateVisibility)
