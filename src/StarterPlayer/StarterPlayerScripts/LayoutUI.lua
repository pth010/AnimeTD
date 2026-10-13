-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: LayoutUI
-- The Screen Layout panel: move and resize the team bar, the Inventory button and the
-- Gems / Gold / Shards counter with sliders. Open it with the gear button (lobby only).
-- Changes show straight away and are saved with your data (see PlayerData.SaveLayout),
-- so the layout is the same next time you play.
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

local gear = button(gui, "⚙", UDim2.new(0, 10, 0.5, 28), UDim2.fromOffset(40, 40), GLASS, 22)
gear.Name = "LayoutButton"

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

gear.Activated:Connect(function()
	if panel.Visible then
		closePanel()
	else
		panelOpen = true
		panel.Visible = true
		showCurrent()
	end
end)
closeBtn.Activated:Connect(closePanel)
doneBtn.Activated:Connect(closePanel)

-- Lobby only (the layout carries into matches, the panel doesn't open there)
local function updateVisibility()
	local inMatch = player:GetAttribute("InMatch") == true
	gear.Visible = not inMatch
	if inMatch then
		closePanel()
	end
end
updateVisibility()
player:GetAttributeChangedSignal("InMatch"):Connect(updateVisibility)
