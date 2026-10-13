-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: InventoryUI
-- (replaces the earlier version: the Trait Odds button is gone, the odds are in the Traits Cave)
-- Lobby only. Locked units can't be deleted. Deleting asks for confirmation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local ProgressData = require(ReplicatedStorage:WaitForChild("ProgressData"))
local inventoryRemote = ReplicatedStorage:WaitForChild("InventoryRemote")
local player = Players.LocalPlayer

local GREEN = Color3.fromRGB(60, 160, 90)
local GRAY = Color3.fromRGB(55, 55, 72)

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1
-- children always draw on top of their parent (so the fuse and delete windows show
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
grid.CellSize = UDim2.fromOffset(170, 194)
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

-- Evolve asks you to click again too (it uses up copies and Gold)
local confirmEvolve = nil
local openFuse -- opens the fuse window, set further down

local function makeCard(name, rarity, count, locked, equipped, autoEquipOn, order, traitName, progress)
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
	addLabel(card, locked and (rarity.Name .. " - LOCKED") or rarity.Name,
		UDim2.fromOffset(8, 28), UDim2.new(1, -100, 0, 16), 12, locked and Color3.fromRGB(255, 215, 80) or rarity.Color)

	-- level, stars and an XP bar
	local xp, stars = progress and progress.XP or 0, progress and progress.Stars or 0
	local level, into, need = ProgressData.LevelFromXP(xp)
	addLabel(card, string.format("Lv%d %s", level, ProgressData.StarText(stars)),
		UDim2.new(1, -96, 0, 28), UDim2.fromOffset(88, 16), 12, ProgressData.StarColor, Enum.TextXAlignment.Right)
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(8, 46)
	bar.Size = UDim2.new(1, -16, 0, 3)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	bar.BorderSizePixel = 0
	bar.Parent = card
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(need > 0 and into / need or 1, 1)
	fill.BackgroundColor3 = need > 0 and Color3.fromRGB(110, 200, 255) or ProgressData.StarColor
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local s = ProgressData.Apply(TraitData.StatsFor(name, traitName), xp, stars)
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

	addLabel(card, "Summon traits in the Traits Cave", UDim2.fromOffset(8, 140), UDim2.new(1, -16, 0, 16), 11,
		Color3.fromRGB(150, 150, 170), Enum.TextXAlignment.Center)

	local fuseBtn = cardButton(card, level >= ProgressData.MaxLevel and "MAX LV" or "Fuse", 6,
		level >= ProgressData.MaxLevel and Color3.fromRGB(80, 80, 90) or Color3.fromRGB(50, 140, 200), 164, 77)
	local step = ProgressData.Evolutions[stars + 1]
	local evolveBtn = cardButton(card, step and string.format("Evolve %d/%d", count - 1, step.Copies) or "MAX ★", 87,
		(step and count - 1 >= step.Copies) and Color3.fromRGB(220, 160, 40) or Color3.fromRGB(80, 80, 90), 164, 77)
	if confirmEvolve == name and step then
		evolveBtn.Text = string.format("Sure? %dG", step.Gold)
		evolveBtn.BackgroundColor3 = Color3.fromRGB(200, 90, 60)
	end

	lockBtn.Activated:Connect(function()
		call("Lock", name, not locked)
	end)

	fuseBtn.Activated:Connect(function()
		if level >= ProgressData.MaxLevel then
			showMessage(name .. " is already max level.")
		else
			openFuse(name)
		end
	end)

	evolveBtn.Activated:Connect(function()
		if not step then
			showMessage(name .. " is fully evolved.")
			return
		end
		if count - 1 < step.Copies then
			showMessage(string.format("Evolving needs %d extra %s and %d Gold (you have %d extra).",
				step.Copies, name, step.Gold, count - 1))
			return
		end
		if confirmEvolve ~= name then
			confirmEvolve = name
			evolveBtn.Text = string.format("Sure? %dG", step.Gold)
			evolveBtn.BackgroundColor3 = Color3.fromRGB(200, 90, 60)
			return
		end
		confirmEvolve = nil
		if call("Evolve", name) then
			showMessage(string.format("%s evolved to %s!", name, ProgressData.StarText(stars + 1)), ProgressData.StarColor)
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

-- ===== Fuse window =====
-- Pick a unit's Fuse button, choose which other units to feed it, press FUSE.
local fuseTarget = nil
local fuseSelection = {} -- [unitName] = copies to feed

local fuseWin = Instance.new("Frame")
fuseWin.Size = UDim2.fromScale(1, 1)
fuseWin.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
fuseWin.Active = true
fuseWin.ZIndex = 10
fuseWin.Visible = false
fuseWin.Parent = frame
Instance.new("UICorner", fuseWin).CornerRadius = UDim.new(0, 12)

local fuseTitle = plainLabel(fuseWin, "", UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 30), 22)
local fuseInfo = plainLabel(fuseWin, "", UDim2.fromOffset(10, 38), UDim2.new(1, -20, 0, 20), 15, Color3.fromRGB(110, 200, 255))

local function smallButton(parent, text, pos, size, color)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local fuseClose = smallButton(fuseWin, "X", UDim2.new(1, -40, 0, 6), UDim2.fromOffset(32, 32), Color3.fromRGB(190, 70, 70))
fuseClose.TextSize = 16
local addCommons = smallButton(fuseWin, "Add extra Commons", UDim2.fromOffset(10, 64), UDim2.fromOffset(160, 26), Color3.fromRGB(110, 110, 120))
local addRares = smallButton(fuseWin, "Add extra Rares", UDim2.fromOffset(176, 64), UDim2.fromOffset(150, 26), Color3.fromRGB(60, 110, 190))
local clearBtn = smallButton(fuseWin, "Clear", UDim2.fromOffset(332, 64), UDim2.fromOffset(80, 26), Color3.fromRGB(80, 80, 100))
plainLabel(fuseWin, "(extra = keeps 1 copy)", UDim2.fromOffset(414, 64), UDim2.fromOffset(136, 26), 11, Color3.fromRGB(170, 170, 190)).Font = Enum.Font.Gotham

local fuseList = Instance.new("ScrollingFrame")
fuseList.Position = UDim2.fromOffset(10, 98)
fuseList.Size = UDim2.new(1, -20, 1, -156)
fuseList.BackgroundTransparency = 1
fuseList.BorderSizePixel = 0
fuseList.ScrollBarThickness = 6
fuseList.CanvasSize = UDim2.new()
fuseList.AutomaticCanvasSize = Enum.AutomaticSize.Y
fuseList.Parent = fuseWin
local fuseLayout = Instance.new("UIListLayout")
fuseLayout.Padding = UDim.new(0, 4)
fuseLayout.SortOrder = Enum.SortOrder.LayoutOrder
fuseLayout.Parent = fuseList

local fuseGo = smallButton(fuseWin, "FUSE", UDim2.new(0.5, -90, 1, -50), UDim2.fromOffset(180, 40), Color3.fromRGB(50, 160, 90))
fuseGo.TextSize = 18

-- what the target would gain from the current selection
local function selectionXP()
	local total = 0
	for name, n in pairs(fuseSelection) do
		total += n * ProgressData.FodderXP[UnitData.UnitRarity[name]]
	end
	return total
end

local function refreshFuse()
	if not fuseTarget then return end
	local counts = parseCounts()
	local locks = parseSet("UnitLocks", ";")
	local traits = TraitData.Parse(player:GetAttribute("UnitTraits"))
	local progress = ProgressData.Parse(player:GetAttribute("UnitProgress"))
	if not counts[fuseTarget] then
		fuseWin.Visible = false -- the target is gone
		fuseTarget = nil
		return
	end

	-- drop selections you no longer have enough of
	for name, n in pairs(fuseSelection) do
		local have = counts[name] or 0
		if locks[name] or have == 0 then
			fuseSelection[name] = nil
		elseif n > have then
			fuseSelection[name] = have
		end
	end

	local xp = progress[fuseTarget] and progress[fuseTarget].XP or 0
	local gain = selectionXP()
	local before = ProgressData.LevelFromXP(xp)
	local after = ProgressData.LevelFromXP(math.min(xp + gain, ProgressData.MaxXP()))
	fuseTitle.Text = "Fuse into " .. fuseTarget
	fuseInfo.Text = gain > 0 and string.format("Lv %d  ->  Lv %d   (+%d XP)", before, after, gain)
		or string.format("Lv %d   -   pick units below to feed in", before)
	fuseGo.BackgroundColor3 = gain > 0 and Color3.fromRGB(50, 160, 90) or Color3.fromRGB(80, 80, 90)

	for _, c in ipairs(fuseList:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	local row = 0
	for i = 1, #UnitData.Rarities do -- commons first: they're the usual food
		local rarity = UnitData.Rarities[i]
		local list = table.clone(UnitData.Units[rarity.Name])
		table.sort(list)
		for _, name in ipairs(list) do
			local have = counts[name]
			if have and name ~= fuseTarget then
				row += 1
				local picked = fuseSelection[name] or 0
				local r = Instance.new("Frame")
				r.LayoutOrder = row
				r.Size = UDim2.new(1, -10, 0, 30)
				r.BackgroundColor3 = rarity.Color:Lerp(Color3.new(0, 0, 0), picked > 0 and 0.45 or 0.75)
				r.Parent = fuseList
				Instance.new("UICorner", r).CornerRadius = UDim.new(0, 6)

				local extra = ""
				if traits[name] then extra ..= " [" .. traits[name] .. "]" end
				if progress[name] and progress[name].Stars > 0 then extra ..= " " .. string.rep("★", progress[name].Stars) end
				addLabel(r, name .. extra, UDim2.fromOffset(8, 0), UDim2.new(0, 190, 1, 0), 13, rarity.Color)
				addLabel(r, "x" .. have, UDim2.fromOffset(200, 0), UDim2.new(0, 40, 1, 0), 13)
				addLabel(r, "+" .. ProgressData.FodderXP[rarity.Name] .. " XP", UDim2.fromOffset(240, 0), UDim2.new(0, 80, 1, 0), 12, Color3.fromRGB(110, 200, 255))

				if locks[name] then
					addLabel(r, "LOCKED", UDim2.new(1, -90, 0, 0), UDim2.new(0, 82, 1, 0), 12, Color3.fromRGB(255, 215, 80), Enum.TextXAlignment.Right)
				else
					local minus = smallButton(r, "-", UDim2.new(1, -170, 0, 3), UDim2.fromOffset(26, 24), Color3.fromRGB(150, 60, 60))
					addLabel(r, tostring(picked), UDim2.new(1, -142, 0, 0), UDim2.new(0, 34, 1, 0), 14, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
					local plus = smallButton(r, "+", UDim2.new(1, -106, 0, 3), UDim2.fromOffset(26, 24), Color3.fromRGB(60, 150, 80))
					local all = smallButton(r, "All", UDim2.new(1, -76, 0, 3), UDim2.fromOffset(40, 24), Color3.fromRGB(70, 90, 140))
					local none = smallButton(r, "0", UDim2.new(1, -34, 0, 3), UDim2.fromOffset(26, 24), Color3.fromRGB(80, 80, 100))
					minus.Activated:Connect(function()
						fuseSelection[name] = picked > 1 and picked - 1 or nil
						refreshFuse()
					end)
					plus.Activated:Connect(function()
						fuseSelection[name] = math.min(picked + 1, have)
						refreshFuse()
					end)
					all.Activated:Connect(function()
						fuseSelection[name] = have
						refreshFuse()
					end)
					none.Activated:Connect(function()
						fuseSelection[name] = nil
						refreshFuse()
					end)
				end
			end
		end
	end
	if row == 0 then
		local l = plainLabel(fuseList, "You have no other units to fuse.", UDim2.new(), UDim2.new(1, -10, 0, 40), 15, Color3.fromRGB(170, 170, 190))
		local holder = Instance.new("Frame")
		holder.Size = UDim2.new(1, -10, 0, 40)
		holder.BackgroundTransparency = 1
		holder.Parent = fuseList
		l.Parent = holder
	end
end

-- adds every unlocked copy of a rarity except one of each (so you keep the unit)
local function addExtras(rarityName)
	local counts = parseCounts()
	local locks = parseSet("UnitLocks", ";")
	for _, name in ipairs(UnitData.Units[rarityName]) do
		local have = counts[name] or 0
		if name ~= fuseTarget and not locks[name] and have > 1 then
			fuseSelection[name] = have - 1
		end
	end
	refreshFuse()
end

addCommons.Activated:Connect(function() addExtras("Common") end)
addRares.Activated:Connect(function() addExtras("Rare") end)
clearBtn.Activated:Connect(function()
	table.clear(fuseSelection)
	refreshFuse()
end)
fuseClose.Activated:Connect(function()
	fuseWin.Visible = false
	fuseTarget = nil
end)

fuseGo.Activated:Connect(function()
	if not fuseTarget then return end
	if selectionXP() == 0 then
		showMessage("Pick some units to feed in first.")
		return
	end
	local target = fuseTarget
	local ok, res = call("Fuse", target, fuseSelection)
	if ok then
		table.clear(fuseSelection)
		local level = ProgressData.LevelFromXP((ProgressData.Parse(player:GetAttribute("UnitProgress"))[target] or {}).XP)
		showMessage(string.format("%s gained %d XP! Now Lv %d.", target, res.XP or 0, level), Color3.fromRGB(110, 200, 255))
		refreshFuse()
	end
end)

openFuse = function(name)
	confirmEvolve = nil
	fuseTarget = name
	table.clear(fuseSelection)
	fuseWin.Visible = true
	refreshFuse()
end

local function rebuild()
	closeDialog() -- the unit under the dialog may have changed
	refreshSettings()
	if fuseWin.Visible then refreshFuse() end
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	local counts = parseCounts()
	local locks = parseSet("UnitLocks", ";")
	local equippedSet = parseSet("Equipped", ",")
	local traits = TraitData.Parse(player:GetAttribute("UnitTraits"))
	local progress = ProgressData.Parse(player:GetAttribute("UnitProgress"))
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
				makeCard(name, rarity, count, locks[name] == true, isEquipped, autoEquipOn, order, traits[name], progress[name])
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
for _, attribute in ipairs({ "UnitCounts", "UnitLocks", "Equipped", "AutoEquip", "AutoDelete", "UnitTraits", "UnitProgress" }) do
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
