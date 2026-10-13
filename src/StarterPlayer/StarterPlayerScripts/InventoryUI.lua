-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: InventoryUI
-- (replaces the earlier version: the team bar stays on screen in matches too, as the unit
--  hotbar: click a slot (or press 1-6) to place that unit; slots show cost and placed/limit)
-- The team bar runs along the bottom of the screen. In the lobby, "Put on team" asks you to
-- click the slot to put the unit in. It hides while the level select, summon or Traits Cave
-- window is open, so it can't cover their buttons.
-- Every unit is its own slot in the grid, with its own trait, level, stars and lock. Click a
-- unit to see it on the right and lock, equip, fuse, evolve or delete it. The top shows
-- how many of your slots are used.
-- Lobby only. Locked units can't be deleted or fed. Deleting asks for confirmation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local ProgressData = require(ReplicatedStorage:WaitForChild("ProgressData"))
local UnitModels = require(ReplicatedStorage:WaitForChild("UnitModels"))
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
gridLayout.CellSize = UDim2.fromOffset(78, 100)
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
-- portrait on the left, name / rarity / level beside it
local dPortrait = frame(detailBody, UDim2.fromOffset(12, 10), UDim2.fromOffset(72, 72), PANEL)
corner(dPortrait, 10)
dPortrait.ClipsDescendants = true
local dPortraitStroke = stroke(dPortrait, WHITE, 2, 0)
local dPortraitName = nil -- whose picture is in dPortrait right now
local TX = 94 -- text column beside the portrait
local dName = label(detailBody, "", UDim2.fromOffset(TX, 12), UDim2.fromOffset(DW + 12 - TX, 22), 16, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
dName.TextTruncate = Enum.TextTruncate.AtEnd
local dRarity = label(detailBody, "", UDim2.fromOffset(TX, 34), UDim2.fromOffset(DW + 12 - TX, 16), 12, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
local dLevel = label(detailBody, "", UDim2.fromOffset(TX, 52), UDim2.fromOffset(DW + 12 - TX, 18), 13, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
local dXPBack = frame(detailBody, UDim2.fromOffset(TX, 74), UDim2.fromOffset(DW + 12 - TX, 5), PANEL)
corner(dXPBack, "round")
local dXPFill = frame(dXPBack, UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), Color3.fromRGB(110, 200, 255))
corner(dXPFill, "round")
local dStats = label(detailBody, "", UDim2.fromOffset(12, 90), UDim2.fromOffset(DW, 36), 13, SUBTLE, Enum.Font.Gotham, Enum.TextXAlignment.Left)
dStats.TextYAlignment = Enum.TextYAlignment.Top

local dTraitBox = frame(detailBody, UDim2.fromOffset(12, 130), UDim2.fromOffset(DW, 50), PANEL)
corner(dTraitBox, 8)
local dTraitStroke = stroke(dTraitBox, DIM, 1, 0.4)
local dTraitIconSlot = frame(dTraitBox, UDim2.fromOffset(7, 7), UDim2.fromOffset(36, 36), WHITE, 1)
local dTraitName = label(dTraitBox, "", UDim2.fromOffset(50, 6), UDim2.new(1, -58, 0, 18), 14, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
local dTraitDesc = label(dTraitBox, "", UDim2.fromOffset(50, 26), UDim2.new(1, -58, 0, 18), 12, SUBTLE, Enum.Font.Gotham, Enum.TextXAlignment.Left)
dTraitDesc.TextTruncate = Enum.TextTruncate.AtEnd

local dStatus = label(detailBody, "", UDim2.fromOffset(12, 186), UDim2.fromOffset(DW, 16), 12, TEAM_GREEN, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)

local function actionButton(y, color)
	return button(detailBody, "", UDim2.fromOffset(12, y), UDim2.fromOffset(DW, 32), color, 13)
end
local equipBtn = actionButton(208, GREEN)
local lockBtn = actionButton(245, Color3.fromRGB(70, 110, 190))
local fuseBtn = actionButton(282, Color3.fromRGB(50, 140, 200))
local evolveBtn = actionButton(319, Color3.fromRGB(220, 160, 40))
local deleteBtn = actionButton(356, RED)
local evolveNote = label(detailBody, "", UDim2.fromOffset(12, 393), UDim2.fromOffset(DW, 30), 11, DIM, Enum.Font.Gotham, Enum.TextXAlignment.Left)
evolveNote.TextYAlignment = Enum.TextYAlignment.Top

-- ===== State =====
local units, byId = {}, {}
local equipped = {}  -- [id] = true
local teamOrder = {} -- unit ids in team slot order
local selectedId = nil
local confirmEvolve = false
local openFuse, askDelete -- set further down
local refreshTeamBar, startPicking -- the team bar, further down
local rebuild -- defined at the bottom
local barCovered -- defined at the bottom

local function readState()
	units, byId = UnitData.ParseUnits(player:GetAttribute("Units"))
	equipped = {}
	teamOrder = {}
	for id in string.gmatch(player:GetAttribute("EquippedIds") or "", "%d+") do
		equipped[tonumber(id)] = true
		table.insert(teamOrder, tonumber(id))
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

	if dPortraitName ~= u.Name then
		dPortraitName = u.Name
		for _, c in ipairs(dPortrait:GetChildren()) do
			if c:IsA("ViewportFrame") then c:Destroy() end
		end
		UnitModels.Portrait(u.Name).Parent = dPortrait
	end
	dPortrait.BackgroundColor3 = darker(rarity.Color, 0.55)
	dPortraitStroke.Color = rarity.Color

	dName.Text = u.Name
	dRarity.Text = rarityName
	dRarity.TextColor3 = rarity.Color
	-- the level's bonus: +10% base damage (or income for cash units) per level above 1
	local bonus = math.floor(ProgressData.PerLevel * (level - 1) * 100 + 0.5)
	dLevel.Text = string.format("Lv %d%s   %s", level, level >= ProgressData.MaxLevel and " MAX" or "",
		ProgressData.StarText(u.Stars))
	if bonus > 0 then
		dLevel.Text ..= string.format("   +%d%% %s", bonus, UnitData.IsFarm(u.Name) and "cash" or "DMG")
	end
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
	for _, c in ipairs(dTraitIconSlot:GetChildren()) do
		c:Destroy()
	end
	if trait then
		TraitData.MakeIcon(trait.Name, 36).Parent = dTraitIconSlot
	else
		local none = frame(dTraitIconSlot, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(24, 24), GLASS)
		none.AnchorPoint = Vector2.new(0.5, 0.5)
		none.Rotation = 45
		corner(none, 4)
		stroke(none, DIM, 1, 0.3)
	end
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

	equipBtn.Text = onTeam and "Remove from team" or "Put on team..."
	equipBtn.BackgroundColor3 = onTeam and Color3.fromRGB(150, 110, 60) or GREEN
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
-- One tile per unit, kept between refreshes (keyed by unit id) so its picture is only built
-- once. Refreshing just updates the text, badges, trait icon and position.
local tiles = {}      -- [unitId] = tile parts
local emptyTiles = {} -- spare empty-slot frames

local function styleSelection(t)
	local selectedNow = t.Id == selectedId
	t.Stroke.Color = selectedNow and WHITE or t.Color
	t.Stroke.Thickness = selectedNow and 2.5 or 1
	t.Stroke.Transparency = selectedNow and 0 or 0.45
end

-- A unit card: picture, name, level, stars, trait icon, team + lock badges. Used by the
-- inventory grid and the fuse picker, so both look the same.
local function makeUnitCard(parent, u)
	local color = rarityByName[UnitData.UnitRarity[u.Name]].Color
	local btn = Instance.new("TextButton")
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.BackgroundColor3 = darker(color, 0.55)
	btn.ClipsDescendants = true
	btn.Parent = parent
	corner(btn, 8)
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(WHITE, Color3.fromRGB(110, 110, 120))
	shade.Rotation = 90
	shade.Parent = btn

	-- the picture fills the top of the card
	local pic = frame(btn, UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 66), WHITE, 1)
	UnitModels.Portrait(u.Name).Parent = pic

	-- name + level under the picture, on a dark band so they read over any color
	local band = frame(btn, UDim2.new(0, 0, 1, -34), UDim2.new(1, 0, 0, 34), BLACK, 0.35)
	local nameLabel = label(band, u.Name, UDim2.fromOffset(4, 2), UDim2.new(1, -8, 0, 14), 10, WHITE, Enum.Font.GothamBold)
	nameLabel.TextWrapped = false
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local levelLabel = label(band, "", UDim2.fromOffset(4, 17), UDim2.fromOffset(40, 14), 11, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
	local starsLabel = label(band, "", UDim2.new(1, -40, 0, 17), UDim2.fromOffset(36, 14), 10, ProgressData.StarColor, Enum.Font.GothamBold, Enum.TextXAlignment.Right)

	-- badges over the picture: team + lock (top left), trait icon (top right)
	local teamBadge = frame(btn, UDim2.fromOffset(4, 4), UDim2.fromOffset(15, 15), TEAM_GREEN)
	corner(teamBadge, "round")
	label(teamBadge, "T", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, BLACK, Enum.Font.GothamBlack)
	local lockBadge = frame(btn, UDim2.fromOffset(4, 4), UDim2.fromOffset(15, 15), LOCK_GOLD)
	corner(lockBadge, 3)
	label(lockBadge, "L", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, BLACK, Enum.Font.GothamBlack)
	local traitSlot = frame(btn, UDim2.new(1, -27, 0, 3), UDim2.fromOffset(24, 24), WHITE, 1)

	return {
		Id = u.Id, Button = btn, Color = color, Stroke = stroke(btn, color, 1, 0.45), Picture = pic,
		Level = levelLabel, Stars = starsLabel, Team = teamBadge, Lock = lockBadge,
		TraitSlot = traitSlot, TraitShown = false,
	}
end

-- Updates the parts of a card that change: level, stars, badges, trait icon
local function updateUnitCard(card, u)
	card.Level.Text = "Lv " .. ProgressData.LevelFromXP(u.XP)
	card.Stars.Text = string.rep("★", u.Stars)
	local onTeam = equipped[u.Id] == true
	card.Team.Visible = onTeam
	card.Lock.Visible = u.Locked
	card.Lock.Position = UDim2.fromOffset(onTeam and 22 or 4, 4)
	if card.TraitShown ~= (u.Trait or false) then
		card.TraitShown = u.Trait or false
		for _, c in ipairs(card.TraitSlot:GetChildren()) do
			c:Destroy()
		end
		local icon = u.Trait and TraitData.MakeIcon(u.Trait, 24)
		if icon then icon.Parent = card.TraitSlot end
	end
end

local function createTile(u)
	local t = makeUnitCard(grid, u)
	t.Button.Activated:Connect(function()
		if selectedId ~= t.Id then
			selectedId = t.Id
			confirmEvolve = false
		end
		for _, other in pairs(tiles) do
			styleSelection(other)
		end
		refreshDetail()
	end)
	return t
end

local function updateTile(t, u, order)
	t.Button.LayoutOrder = order
	updateUnitCard(t, u)
	styleSelection(t)
end

local function rebuildGrid()
	local maxSlots = player:GetAttribute("MaxSlots") or UnitData.BaseSlots
	local alive = {}
	for i, u in ipairs(units) do
		alive[u.Id] = true
		local t = tiles[u.Id]
		if not t then
			t = createTile(u)
			tiles[u.Id] = t
		end
		updateTile(t, u, i)
	end
	for id, t in pairs(tiles) do
		if not alive[id] then
			t.Button:Destroy()
			tiles[id] = nil
		end
	end

	-- empty slots after the units, up to your capacity
	local emptyCount = math.max(0, maxSlots - #units)
	while #emptyTiles < emptyCount do
		local slot = frame(grid, UDim2.new(), UDim2.new(), WHITE, 1)
		corner(slot, 8)
		stroke(slot, WHITE, 1, 0.9)
		table.insert(emptyTiles, slot)
	end
	while #emptyTiles > emptyCount do
		table.remove(emptyTiles):Destroy()
	end
	for i, slot in ipairs(emptyTiles) do
		slot.LayoutOrder = #units + i
	end

	local used = #units
	slotText.Text = string.format("%d / %d units", used, maxSlots)
	slotText.TextColor3 = used >= maxSlots and ERROR_COLOR or WHITE
	slotFill.Size = UDim2.fromScale(math.clamp(used / math.max(1, maxSlots), 0, 1), 1)
	slotFill.BackgroundColor3 = used >= maxSlots and ERROR_COLOR or (used / maxSlots > 0.85 and LOCK_GOLD or Color3.fromRGB(110, 200, 255))
end

-- ===== Team bar (bottom of the lobby screen) =====
-- Your team's slots, always visible in the lobby. "Put on team" starts picking: the slots
-- light up and you click the one to put the unit in. Clicking a filled slot otherwise opens
-- the inventory with that unit selected.
local SLOT_W, SLOT_H, SLOT_GAP = 78, 100, 8
local playerGuiRoot = player:WaitForChild("PlayerGui")
local PICK_GOLD = Color3.fromRGB(255, 215, 80)

local barGui = Instance.new("ScreenGui")
barGui.Name = "TeamBarGui"
barGui.ResetOnSpawn = false
barGui.DisplayOrder = 4 -- above the inventory window, so slots stay clickable while picking
barGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
barGui.Parent = player:WaitForChild("PlayerGui")

local barW = UnitData.TeamSize * SLOT_W + (UnitData.TeamSize - 1) * SLOT_GAP + 20
local bar = frame(barGui, UDim2.new(0.5, 0, 1, -12), UDim2.fromOffset(barW, SLOT_H + 34), PANEL, 0.15)
bar.AnchorPoint = Vector2.new(0.5, 1)
corner(bar, 12)
local barStroke = stroke(bar, WHITE, 1, 0.8)
local barScale = Instance.new("UIScale")
barScale.Parent = bar
local function fitBar()
	local vp = workspace.CurrentCamera.ViewportSize
	barScale.Scale = math.min(1, (vp.X - 20) / barW)
end
fitBar()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBar)

local barTitle = label(bar, "TEAM", UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, 20), 12, SUBTLE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
local barHint = label(bar, "", UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, 20), 11, DIM, Enum.Font.Gotham, Enum.TextXAlignment.Right)

-- the "pick a slot" banner that appears above the bar
local pickBanner = frame(barGui, UDim2.new(0.5, 0, 1, -(SLOT_H + 56)), UDim2.fromOffset(380, 40), Color3.fromRGB(40, 34, 14))
pickBanner.AnchorPoint = Vector2.new(0.5, 1)
pickBanner.Visible = false
corner(pickBanner, 10)
stroke(pickBanner, PICK_GOLD, 1.5)
local pickText = label(pickBanner, "", UDim2.fromOffset(12, 0), UDim2.new(1, -110, 1, 0), 14, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
pickText.TextTruncate = Enum.TextTruncate.AtEnd
local pickCancel = button(pickBanner, "Cancel", UDim2.new(1, -90, 0.5, -14), UDim2.fromOffset(80, 28), GRAY, 13)

local slots = {} -- [slotIndex] = { Frame, Stroke, Plus, Number, Card, CardId, Cost, CostText, Full }
local pickingId = nil
local placedCounts = {} -- [unitName] = placed in the current match
local readPlacedCounts -- defined below

local function inMatch()
	return player:GetAttribute("InMatch") == true
end

-- In a match, a slot picks that unit to place (PlacementUI does the placing)
local function selectForPlacement(i)
	local u = teamOrder[i] and byId[teamOrder[i]]
	local hud = playerGuiRoot:FindFirstChild("TowerDefenseHUD")
	local event = hud and hud:FindFirstChild("SelectUnit")
	if u and event then
		event:Fire(u.Name)
	end
end

local function onSlotClicked(i)
	if inMatch() then
		selectForPlacement(i)
		return
	end
	if pickingId then
		local id = pickingId
		pickingId = nil
		local wasAuto = player:GetAttribute("AutoEquip") == true
		if call("EquipSlot", id, i) and wasAuto then
			showMessage("Auto-equip is off now that you're picking your team.", SUBTLE)
		end
		refreshTeamBar()
		return
	end
	-- not picking: open the inventory on this unit
	local id = teamOrder[i]
	if id and byId[id] then
		selectedId = id
		confirmEvolve = false
		window.Visible = true
		rebuild()
	end
end

for i = 1, UnitData.TeamSize do
	local x = 10 + (i - 1) * (SLOT_W + SLOT_GAP)
	local slot = Instance.new("TextButton")
	slot.Position = UDim2.fromOffset(x, 26)
	slot.Size = UDim2.fromOffset(SLOT_W, SLOT_H)
	slot.Text = ""
	slot.AutoButtonColor = true
	slot.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
	slot.Parent = bar
	corner(slot, 8)
	local slotStroke = stroke(slot, WHITE, 1, 0.8)
	local plus = label(slot, "+", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 26, DIM, Enum.Font.GothamBold)
	local number = label(slot, tostring(i), UDim2.new(1, -18, 1, -18), UDim2.fromOffset(14, 14), 11, DIM, Enum.Font.GothamBlack)
	number.ZIndex = 3

	-- match only: the unit's cost and how many you've placed out of its limit
	local cost = frame(slot, UDim2.fromOffset(3, 48), UDim2.new(1, -6, 0, 15), BLACK, 0.25)
	cost.ZIndex = 3
	corner(cost, "round")
	local costText = label(cost, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, WHITE, Enum.Font.GothamBlack)
	costText.ZIndex = 3
	cost.Visible = false
	-- match only: darkens the slot when you've placed as many as you can
	local full = frame(slot, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), BLACK, 0.45)
	full.ZIndex = 4
	corner(full, 8)
	local fullText = label(full, "MAX", UDim2.fromScale(0, 0.15), UDim2.new(1, 0, 0, 20), 14, WHITE, Enum.Font.GothamBlack)
	fullText.ZIndex = 4
	full.Visible = false

	slots[i] = { Frame = slot, Stroke = slotStroke, Plus = plus, Number = number, Card = nil, CardId = nil,
		Cost = cost, CostText = costText, Full = full }

	slot.Activated:Connect(function() onSlotClicked(i) end)
end

refreshTeamBar = function()
	for i, s in ipairs(slots) do
		local id = teamOrder[i]
		local u = id and byId[id]
		-- (re)build the card only when a different unit lands in the slot
		if s.CardId ~= (u and u.Id or nil) then
			if s.Card then s.Card.Button:Destroy() end
			s.Card, s.CardId = nil, nil
			if u then
				local card = makeUnitCard(s.Frame, u)
				card.Button.Size = UDim2.fromScale(1, 1)
				card.Button.Activated:Connect(function() onSlotClicked(i) end) -- the card covers the slot
				card.Team.Visible = false
				s.Card, s.CardId = card, u.Id
			end
		end
		if s.Card and u then
			updateUnitCard(s.Card, u)
			s.Card.Team.Visible = false -- everything here is on the team
		end
		s.Plus.Visible = u == nil

		-- in a match: cost + placed/limit, MAX when full, a white outline on the unit being placed
		local match = inMatch()
		local placing = match and u and player:GetAttribute("PlacingUnit") == u.Name
		s.Cost.Visible = match and u ~= nil
		s.Full.Visible = false
		if match and u then
			local limit = UnitData.GetPlacementLimit(u.Name)
			local placed = placedCounts[u.Name] or 0
			local unitCost = unitStats(u).Cost
			s.CostText.Text = string.format("$%d  ·  %d/%d", unitCost, placed, limit)
			s.CostText.TextColor3 = (player:GetAttribute("Cash") or 0) >= unitCost and WHITE or ERROR_COLOR
			s.Full.Visible = placed >= limit
		end

		-- picking (lobby): every slot glows gold
		if placing then
			s.Stroke.Color, s.Stroke.Thickness, s.Stroke.Transparency = WHITE, 3, 0
		else
			s.Stroke.Color = pickingId and PICK_GOLD or WHITE
			s.Stroke.Thickness = pickingId and 2.5 or 1
			s.Stroke.Transparency = pickingId and 0 or 0.8
		end
		s.Plus.TextColor3 = pickingId and PICK_GOLD or DIM
	end

	local picking = pickingId and byId[pickingId]
	if pickingId and not picking then pickingId = nil end
	pickBanner.Visible = picking ~= nil
	if picking then
		pickText.Text = "Click a slot for " .. picking.Name
	end
	barStroke.Color = picking and PICK_GOLD or WHITE
	barStroke.Transparency = picking and 0.2 or 0.8
	local autoOn = player:GetAttribute("AutoEquip") == true
	if inMatch() then
		barHint.Text = "Click a unit or press 1-" .. UnitData.TeamSize .. " to place it"
	else
		barHint.Text = picking and "" or (autoOn and "Auto-equip ON" or string.format("%d / %d", #teamOrder, UnitData.TeamSize))
	end
end

-- How many of each unit you have placed in the current match (kept up to date by the server)
readPlacedCounts = function()
	table.clear(placedCounts)
	for unit, n in string.gmatch(player:GetAttribute("PlacedCounts") or "", "([^;=]+)=(%d+)") do
		placedCounts[unit] = tonumber(n)
	end
end
readPlacedCounts()
player:GetAttributeChangedSignal("PlacedCounts"):Connect(function()
	readPlacedCounts()
	refreshTeamBar()
end)
for _, attribute in ipairs({ "PlacingUnit", "Cash", "InMatch" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		refreshTeamBar()
	end)
end

startPicking = function(id)
	pickingId = id
	refreshTeamBar()
end

pickCancel.Activated:Connect(function()
	pickingId = nil
	refreshTeamBar()
end)

-- ===== Detail actions =====
equipBtn.Activated:Connect(function()
	local u = selectedId and byId[selectedId]
	if not u then return end
	if equipped[u.Id] then
		call("Equip", u.Id, false)
	else
		startPicking(u.Id) -- choose a slot on the team bar
	end
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

-- the unit being fused into: its picture, name and the level it will reach
local fusePortrait = frame(fuseWin, UDim2.fromOffset(14, 8), UDim2.fromOffset(54, 54), PANEL)
corner(fusePortrait, 10)
fusePortrait.ClipsDescendants = true
local fusePortraitStroke = stroke(fusePortrait, WHITE, 2, 0)
local fusePortraitName = nil
local fuseTitle = label(fuseWin, "", UDim2.fromOffset(78, 10), UDim2.new(1, -140, 0, 26), 20, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
local fuseInfo = label(fuseWin, "", UDim2.fromOffset(78, 38), UDim2.new(1, -140, 0, 20), 14, Color3.fromRGB(110, 200, 255), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
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
fuseGrid.CellSize = UDim2.fromOffset(78, 100)
fuseGrid.CellPadding = UDim2.fromOffset(6, 6)
fuseGrid.SortOrder = Enum.SortOrder.LayoutOrder
fuseGrid.Parent = fuseList
local fuseEmpty = label(fuseWin, "No units to feed in. Locked units and your team can't be fed.", UDim2.fromOffset(14, 106),
	UDim2.new(1, -28, 0, 60), 14, DIM, Enum.Font.Gotham)
fuseEmpty.Visible = false

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

-- Fuse cards, kept between refreshes like the inventory tiles (keyed by unit id)
local fuseCards = {}
local PICK_BLUE = Color3.fromRGB(110, 200, 255)

local function stylePick(card)
	local picked = fuseSelection[card.Id] == true
	card.PickTint.Visible = picked
	card.Stroke.Color = picked and PICK_BLUE or card.Color
	card.Stroke.Thickness = picked and 3 or 1
	card.Stroke.Transparency = picked and 0 or 0.45
end

-- Title, level preview and the FUSE button
local function refreshFuseHeader(target)
	local count = 0
	for _ in pairs(fuseSelection) do count += 1 end
	local gain = selectionXP()
	local before = ProgressData.LevelFromXP(target.XP)
	local after = ProgressData.LevelFromXP(math.min(target.XP + gain, ProgressData.MaxXP()))
	fuseTitle.Text = "Fuse into " .. target.Name
	fuseInfo.Text = gain > 0 and string.format("Lv %d  ->  Lv %d   (+%d XP from %d unit%s)", before, after, gain, count, count == 1 and "" or "s")
		or string.format("Lv %d   -   click units below to feed them in", before)
	-- units cap at max level, so XP past it is lost
	local wasted = target.XP + gain - ProgressData.MaxXP()
	if gain > 0 and wasted > 0 then
		fuseInfo.Text ..= string.format("   ·   %d XP wasted past max level", wasted)
	end
	fuseInfo.TextColor3 = (gain > 0 and wasted > 0) and LOCK_GOLD or Color3.fromRGB(110, 200, 255)
	fuseGo.Text = count > 0 and string.format("FUSE %d", count) or "FUSE"
	fuseGo.BackgroundColor3 = gain > 0 and Color3.fromRGB(50, 160, 90) or GRAY

	if fusePortraitName ~= target.Name then
		fusePortraitName = target.Name
		for _, c in ipairs(fusePortrait:GetChildren()) do
			if c:IsA("ViewportFrame") then c:Destroy() end
		end
		UnitModels.Portrait(target.Name).Parent = fusePortrait
	end
	local color = rarityByName[UnitData.UnitRarity[target.Name]].Color
	fusePortrait.BackgroundColor3 = darker(color, 0.55)
	fusePortraitStroke.Color = color
end

local function createFuseCard(u)
	local card = makeUnitCard(fuseList, u)
	-- picked: a blue tint over the picture with a check mark
	local tint = frame(card.Button, UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 66), PICK_BLUE, 0.55)
	tint.Visible = false
	local check = frame(tint, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(28, 28), PICK_BLUE)
	check.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(check, "round")
	stroke(check, WHITE, 2)
	label(check, "✓", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 18, WHITE, Enum.Font.GothamBlack)
	card.PickTint = tint
	-- how much XP this unit gives, just above the name band
	local xpTag = frame(card.Button, UDim2.new(0, 3, 1, -50), UDim2.fromOffset(52, 14), BLACK, 0.3)
	corner(xpTag, "round")
	label(xpTag, "+" .. ProgressData.FodderXP[UnitData.UnitRarity[u.Name]] .. " XP", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 9, PICK_BLUE, Enum.Font.GothamBlack)

	card.Button.Activated:Connect(function()
		local cu = byId[card.Id]
		local target = fuseTarget and byId[fuseTarget]
		if not cu or not target or not canFeed(cu) then return end
		fuseSelection[card.Id] = not fuseSelection[card.Id] or nil
		stylePick(card)
		refreshFuseHeader(target)
	end)
	return card
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

	-- weakest first: they're the usual food. Units that can't be fed stay hidden.
	local order = 0
	for i = #units, 1, -1 do
		local u = units[i]
		local card = fuseCards[u.Id]
		if canFeed(u) then
			order += 1
			if not card then
				card = createFuseCard(u)
				fuseCards[u.Id] = card
			end
			card.Button.Visible = true
			card.Button.LayoutOrder = order
			updateUnitCard(card, u)
			stylePick(card)
		elseif card then
			card.Button.Visible = false
		end
	end
	for id, card in pairs(fuseCards) do
		if not byId[id] then
			card.Button:Destroy()
			fuseCards[id] = nil
		end
	end
	fuseEmpty.Visible = order == 0
	refreshFuseHeader(target)
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
rebuild = function()
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
	refreshTeamBar()
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
-- Other windows the team bar must never cover (it's drawn above them). Each of these
-- ScreenGuis has one window frame; the bar hides while any of them is showing.
local COVERING_GUIS = { "LevelSelectGui", "GachaGui", "TraitCaveGui", "SummonRevealGui", "ResultsGui" }
local playerGui = player:WaitForChild("PlayerGui")
barCovered = function()
	for _, name in ipairs(COVERING_GUIS) do
		local other = playerGui:FindFirstChild(name)
		if other and other:IsA("ScreenGui") and other.Enabled then
			for _, child in ipairs(other:GetChildren()) do
				if child:IsA("GuiObject") and child.Visible then
					return true
				end
			end
		end
	end
	return false
end

local function updateVisibility()
	local inMatch = player:GetAttribute("InMatch") == true
	openBtn.Visible = not inMatch
	barGui.Enabled = not barCovered() -- on screen in the lobby and in matches
	if inMatch and pickingId then
		pickingId = nil
		refreshTeamBar()
	end
	if inMatch then
		window.Visible = false
		closeDialog()
		fuseWin.Visible = false
	end
end
updateVisibility()
player:GetAttributeChangedSignal("InMatch"):Connect(updateVisibility)

-- those windows open and close on their own (walking onto pads, the fountain, the cave)
task.spawn(function()
	while true do
		task.wait(0.25)
		local shouldShow = not barCovered()
		if barGui.Enabled ~= shouldShow then
			if not shouldShow and pickingId then
				pickingId = nil
				refreshTeamBar()
			end
			barGui.Enabled = shouldShow
		end
	end
end)
