-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: LayoutUI
-- (replaces the earlier version: the Settings button sits right under the Inventory button,
--  half its width and the same height)
-- The Settings popup (Settings button under the Inventory button, always on screen):
--   * Screen Layout: move and resize the team bar, the Inventory button and the
--     Gems / Gold / Shards counter with sliders
--   * Trait icons over units, enemy health bars, HP numbers on health bars: on / off
--   * Auto-equip best team: on / off (lobby only)
-- Everything is saved with your data (PlayerData.SaveLayout / SaveSettings), so it's the
-- same next time you play.
--
-- To add another element: give its GuiObject a Name, then add it to ELEMENTS below and to
-- PlayerData.LayoutElements on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local inventoryRemote = ReplicatedStorage:WaitForChild("InventoryRemote")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Each movable element: its key (saved), the label in the panel, and where to find it.
-- UserScale = true means the element already has its own UIScale (it fits itself to the
-- screen) and reads the chosen size from its "UserScale" attribute.
local ELEMENTS = {
	{ Key = "TeamBar", Label = "Team bar", Gui = "TeamBarGui", Child = "TeamBar", UserScale = true },
	{ Key = "InventoryButton", Label = "Inventory button", Gui = "InventoryGui", Child = "InventoryButton" },
	{ Key = "Currency", Label = "Currency", Gui = "CurrencyGui", Child = "Counter" },
}
local MOVE_LIMIT = 0.5 -- keep in sync with PlayerData (fractions of the screen)
local SIZE_MIN, SIZE_MAX = 0.6, 1.6

local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(22, 22, 36)
local GLASS = Color3.fromRGB(34, 34, 52)
local SUBTLE = Color3.fromRGB(180, 180, 205)
local ACCENT = Color3.fromRGB(110, 200, 255)
local GRAY = Color3.fromRGB(62, 62, 80)

-- ===== The layout itself =====
local layout = {} -- [key] = { X, Y, S }

local function parseLayout(text)
	local out = {}
	for key, x, y, s in string.gmatch(text or "", "([^;=]+)=([%-%d%.]+):([%-%d%.]+):([%-%d%.]+)") do
		out[key] = { X = tonumber(x), Y = tonumber(y), S = tonumber(s) }
	end
	return out
end

local function entry(key)
	layout[key] = layout[key] or { X = 0, Y = 0, S = 1 }
	return layout[key]
end

local function findElement(def)
	local gui = playerGui:FindFirstChild(def.Gui)
	return gui and gui:FindFirstChild(def.Child, true)
end

-- Moves / resizes one element from its original spot
local function apply(def)
	local el = findElement(def)
	if not el then return end
	local default = el:GetAttribute("LayoutDefault")
	if typeof(default) ~= "UDim2" then
		default = el.Position
		el:SetAttribute("LayoutDefault", default)
	end
	local v = layout[def.Key] or { X = 0, Y = 0, S = 1 }
	el.Position = UDim2.new(default.X.Scale + v.X, default.X.Offset, default.Y.Scale + v.Y, default.Y.Offset)
	if def.UserScale then
		el:SetAttribute("UserScale", v.S)
	else
		local scale = el:FindFirstChild("LayoutScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "LayoutScale"
			scale.Parent = el
		end
		scale.Scale = v.S
	end
end

local function applyAll()
	for _, def in ipairs(ELEMENTS) do
		apply(def)
	end
end

-- The saved layout arrives from the server; elements may be built a moment after this
-- script starts, so apply again as they appear
layout = parseLayout(player:GetAttribute("UILayout"))
task.spawn(function()
	for _, def in ipairs(ELEMENTS) do
		local gui = playerGui:WaitForChild(def.Gui, 30)
		if gui then
			gui:WaitForChild(def.Child, 30)
			apply(def)
		end
	end
end)
local panelOpen = false
player:GetAttributeChangedSignal("UILayout"):Connect(function()
	if panelOpen then return end -- don't fight the sliders while you're dragging
	layout = parseLayout(player:GetAttribute("UILayout"))
	applyAll()
end)

-- ===== Small builders =====
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius == "round" and UDim.new(1, 0) or UDim.new(0, radius)
	c.Parent = parent
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
	l.TextXAlignment = align or Enum.TextXAlignment.Left
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
	b.Parent = parent
	corner(b, 8)
	return b
end

-- ===== Gear button + panel =====
local gui = Instance.new("ScreenGui")
gui.Name = "LayoutGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

-- Right under the Inventory button (InventoryUI: 130x40 at the left edge, centered on the
-- middle of the screen): half as wide, the same height, with a small gap
local gear = button(gui, "Settings", UDim2.new(0, 10, 0.5, 26), UDim2.fromOffset(65, 40), Color3.fromRGB(70, 110, 220), 13)
gear.Name = "SettingsButton"
-- shrink the text a little if it doesn't fit the narrow button
gear.TextScaled = true
local gearText = Instance.new("UITextSizeConstraint")
gearText.MaxTextSize = 13
gearText.Parent = gear
local gearPad = Instance.new("UIPadding")
gearPad.PaddingLeft = UDim.new(0, 4)
gearPad.PaddingRight = UDim.new(0, 4)
gearPad.Parent = gear
print("[LayoutUI] Settings button ready (under the Inventory button)")

local PW, PH = 360, 330
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.42)
panel.Size = UDim2.fromOffset(PW, PH)
panel.BackgroundColor3 = PANEL
panel.Visible = false
panel.Active = true
panel.Parent = gui
corner(panel, 14)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = WHITE
panelStroke.Transparency = 0.8
panelStroke.Parent = panel

label(panel, "Screen Layout", UDim2.fromOffset(16, 10), UDim2.fromOffset(250, 26), 20, WHITE, Enum.Font.GothamBlack)
label(panel, "Pick something, then slide it into place.", UDim2.fromOffset(16, 36), UDim2.fromOffset(PW - 32, 16), 12, SUBTLE, Enum.Font.Gotham)
local closeBtn = button(panel, "X", UDim2.new(1, -42, 0, 10), UDim2.fromOffset(30, 30), Color3.fromRGB(190, 70, 70), 14)

-- which element the sliders move
local current = ELEMENTS[1]
local tabs = {}
for i, def in ipairs(ELEMENTS) do
	local w = (PW - 32 - 2 * 8) / 3
	local tab = button(panel, def.Label, UDim2.fromOffset(16 + (i - 1) * (w + 8), 62), UDim2.fromOffset(w, 30), GRAY, 12)
	tabs[def.Key] = tab
end

-- A horizontal slider. Returns a function to set its value without firing onChange.
local function slider(y, title, minV, maxV, format, onChange)
	label(panel, title, UDim2.fromOffset(16, y), UDim2.fromOffset(200, 18), 13, WHITE)
	local valueLabel = label(panel, "", UDim2.fromOffset(PW - 116, y), UDim2.fromOffset(100, 18), 13, ACCENT, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)

	local track = Instance.new("TextButton") -- a button so clicking anywhere on it works
	track.Text = ""
	track.AutoButtonColor = false
	track.Position = UDim2.fromOffset(24, y + 26)
	track.Size = UDim2.fromOffset(PW - 48, 8)
	track.BackgroundColor3 = GLASS
	track.Parent = panel
	corner(track, "round")
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, "round")
	local knob = Instance.new("TextButton")
	knob.Text = ""
	knob.AutoButtonColor = false
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(20, 20)
	knob.BackgroundColor3 = WHITE
	knob.Parent = track
	corner(knob, "round")
	local knobStroke = Instance.new("UIStroke")
	knobStroke.Color = ACCENT
	knobStroke.Thickness = 2
	knobStroke.Parent = knob

	local function show(value)
		local rel = (value - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(rel, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		valueLabel.Text = format(value)
	end

	local dragging = false
	local function dragTo(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local value = minV + rel * (maxV - minV)
		-- snap to the middle / default so it's easy to get back
		local snap = (minV < 0 and maxV > 0) and 0 or 1
		if math.abs(value - snap) < (maxV - minV) * 0.02 then value = snap end
		show(value)
		onChange(value)
	end
	local function begin(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragTo(input.Position.X)
		end
	end
	track.InputBegan:Connect(begin)
	knob.InputBegan:Connect(begin)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	return show
end

local function percent(v) return string.format("%+d%%", math.floor(v * 100 + 0.5)) end
local function times(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

local setX = slider(108, "Left  ↔  Right", -MOVE_LIMIT, MOVE_LIMIT, percent, function(v)
	entry(current.Key).X = v
	apply(current)
end)
local setY = slider(162, "Up  ↕  Down", -MOVE_LIMIT, MOVE_LIMIT, percent, function(v)
	entry(current.Key).Y = v
	apply(current)
end)
local setS = slider(216, "Size", SIZE_MIN, SIZE_MAX, times, function(v)
	entry(current.Key).S = v
	apply(current)
end)

local resetBtn = button(panel, "Reset this", UDim2.fromOffset(16, PH - 52), UDim2.fromOffset(100, 36), GRAY, 13)
local resetAllBtn = button(panel, "Reset all", UDim2.fromOffset(124, PH - 52), UDim2.fromOffset(100, 36), GRAY, 13)
local doneBtn = button(panel, "Done", UDim2.new(1, -116, 1, -52), UDim2.fromOffset(100, 36), Color3.fromRGB(60, 160, 90), 15)

local function showCurrent()
	local v = layout[current.Key] or { X = 0, Y = 0, S = 1 }
	setX(v.X)
	setY(v.Y)
	setS(v.S)
	for key, tab in pairs(tabs) do
		tab.BackgroundColor3 = key == current.Key and ACCENT or GRAY
		tab.TextColor3 = key == current.Key and Color3.fromRGB(10, 30, 45) or WHITE
	end
end

for _, def in ipairs(ELEMENTS) do
	tabs[def.Key].Activated:Connect(function()
		current = def
		showCurrent()
	end)
end

resetBtn.Activated:Connect(function()
	layout[current.Key] = nil
	apply(current)
	showCurrent()
end)
resetAllBtn.Activated:Connect(function()
	table.clear(layout)
	applyAll()
	showCurrent()
end)

local function save()
	pcall(function()
		inventoryRemote:InvokeServer("SaveLayout", layout)
	end)
end

local function closePanel()
	if not panel.Visible then return end
	panel.Visible = false
	panelOpen = false
	save()
end

-- ===== Settings popup =====
local SW, SH = 340, 300
local settingsPanel = Instance.new("Frame")
settingsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
settingsPanel.Position = UDim2.fromScale(0.5, 0.45)
settingsPanel.Size = UDim2.fromOffset(SW, SH)
settingsPanel.BackgroundColor3 = PANEL
settingsPanel.Visible = false
settingsPanel.Active = true
settingsPanel.Parent = gui
corner(settingsPanel, 14)
local settingsStroke = Instance.new("UIStroke")
settingsStroke.Color = WHITE
settingsStroke.Transparency = 0.8
settingsStroke.Parent = settingsPanel

label(settingsPanel, "Settings", UDim2.fromOffset(16, 10), UDim2.fromOffset(200, 28), 22, WHITE, Enum.Font.GothamBlack)
local settingsClose = button(settingsPanel, "X", UDim2.new(1, -42, 0, 10), UDim2.fromOffset(30, 30), Color3.fromRGB(190, 70, 70), 14)

-- on/off settings (the server keeps them; defaults are all on)
local settings = { TraitIcons = true, HealthBars = true, HPNumbers = true }
local function parseSettings(text)
	for name, v in string.gmatch(text or "", "([^;=]+)=(%d)") do
		if settings[name] ~= nil then
			settings[name] = v == "1"
		end
	end
end
parseSettings(player:GetAttribute("Settings"))

-- Shows / hides the floating things in the world on YOUR screen only
local function applyVisual(inst)
	if inst:IsA("BillboardGui") then
		if inst.Name == "TraitBadge" then
			inst.Enabled = settings.TraitIcons
		elseif inst.Name == "HealthBar" then
			inst.Enabled = settings.HealthBars
		end
	elseif inst:IsA("TextLabel") and inst.Name == "HPText" then
		inst.Visible = settings.HPNumbers
	end
end
local function applyAllVisuals()
	for _, inst in ipairs(workspace:GetDescendants()) do
		applyVisual(inst)
	end
end
workspace.DescendantAdded:Connect(applyVisual)
applyAllVisuals()

-- One row: a title on the left, a control on the right
local ROW_Y0, ROW_H = 52, 44
local function row(i, title)
	local y = ROW_Y0 + (i - 1) * ROW_H
	local line = Instance.new("Frame")
	line.Position = UDim2.fromOffset(16, y + ROW_H - 1)
	line.Size = UDim2.fromOffset(SW - 32, 1)
	line.BackgroundColor3 = WHITE
	line.BackgroundTransparency = 0.92
	line.BorderSizePixel = 0
	line.Parent = settingsPanel
	label(settingsPanel, title, UDim2.fromOffset(16, y), UDim2.fromOffset(SW - 110, ROW_H), 14, WHITE)
	return y
end

-- A pill on/off switch. Returns a function that redraws it from the current value.
local function toggle(y, get, set)
	local switch = Instance.new("TextButton")
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.Position = UDim2.new(1, -72, 0, y + (ROW_H - 26) / 2)
	switch.Size = UDim2.fromOffset(52, 26)
	switch.Parent = settingsPanel
	corner(switch, "round")
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.BackgroundColor3 = WHITE
	knob.Parent = switch
	corner(knob, "round")
	local function draw()
		local on = get()
		switch.BackgroundColor3 = on and Color3.fromRGB(60, 170, 100) or GRAY
		knob.Position = on and UDim2.fromOffset(29, 3) or UDim2.fromOffset(3, 3)
	end
	switch.Activated:Connect(function()
		set(not get())
		draw()
	end)
	draw()
	return draw
end

local function saveSettings()
	pcall(function()
		inventoryRemote:InvokeServer("SaveSettings", settings)
	end)
end

local openLayout -- set below

local layoutY = row(1, "Screen Layout")
local editLayout = button(settingsPanel, "Edit", UDim2.new(1, -92, 0, layoutY + 7), UDim2.fromOffset(72, 30), ACCENT, 13)
editLayout.TextColor3 = Color3.fromRGB(10, 30, 45)

local drawers = {}
for i, item in ipairs({
	{ "TraitIcons", "Trait icons over units" },
	{ "HealthBars", "Enemy health bars" },
	{ "HPNumbers", "HP numbers on health bars" },
}) do
	local key = item[1]
	local y = row(i + 1, item[2])
	drawers[key] = toggle(y, function() return settings[key] end, function(v)
		settings[key] = v
		applyAllVisuals()
		saveSettings()
	end)
end

-- auto-equip lives on the server (the same switch as in the Inventory); lobby only
local autoY = row(5, "Auto-equip best team")
local autoNote = label(settingsPanel, "lobby only", UDim2.new(1, -150, 0, autoY), UDim2.fromOffset(70, ROW_H), 11, SUBTLE, Enum.Font.Gotham, Enum.TextXAlignment.Right)
local drawAuto = toggle(autoY, function() return player:GetAttribute("AutoEquip") == true end, function(v)
	if player:GetAttribute("InMatch") == true then return end
	pcall(function()
		inventoryRemote:InvokeServer("AutoEquip", v)
	end)
end)
player:GetAttributeChangedSignal("AutoEquip"):Connect(drawAuto)

-- settings changed somewhere else (e.g. another server) while not looking
player:GetAttributeChangedSignal("Settings"):Connect(function()
	parseSettings(player:GetAttribute("Settings"))
	for _, draw in pairs(drawers) do draw() end
	applyAllVisuals()
end)

local function closeSettings()
	settingsPanel.Visible = false
end

local function openSettings()
	closePanel()
	autoNote.Visible = player:GetAttribute("InMatch") == true
	settingsPanel.Visible = true
	drawAuto()
end

openLayout = function()
	closeSettings()
	panelOpen = true
	panel.Visible = true
	showCurrent()
end

gear.Activated:Connect(function()
	if settingsPanel.Visible then
		closeSettings()
	elseif panel.Visible then
		closePanel()
	else
		openSettings()
	end
end)
settingsClose.Activated:Connect(closeSettings)
editLayout.Activated:Connect(function() openLayout() end)
closeBtn.Activated:Connect(closePanel)
doneBtn.Activated:Connect(closePanel)

player:GetAttributeChangedSignal("InMatch"):Connect(function()
	autoNote.Visible = player:GetAttribute("InMatch") == true
end)
