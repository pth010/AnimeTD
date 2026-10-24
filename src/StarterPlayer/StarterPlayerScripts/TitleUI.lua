-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: TitleUI
-- (new script: the TITLES button and window)
-- A purple TITLES button under the SHOP button (it moves with the menu buttons in Screen
-- Layout). It opens a window listing the titles (TitleData): each one as it looks over your
-- head, how you get it, and an Equip button. The one you have on says EQUIPPED; ones you
-- don't own yet are greyed out with a padlock. Hidden titles only show once you own them.
-- Equipping goes through TitleService, and PlayerData saves it.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
-- Only one copy may run (a second one would draw a second TITLES button)
if player:GetAttribute("TitleUIRunning") then
	warn("[TitleUI] another TitleUI script is already running; this copy does nothing. Delete the extra copy.")
	return
end
player:SetAttribute("TitleUIRunning", true)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleData = require(ReplicatedStorage:WaitForChild("TitleData"))
local titleRemote = ReplicatedStorage:WaitForChild("TitleRemote")
local playerGui = player:WaitForChild("PlayerGui")

local WIDTH, HEIGHT = 420, 420
local ROW_H = 64
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(22, 22, 36)
local CARD = Color3.fromRGB(34, 34, 54)
local SUBTLE = Color3.fromRGB(180, 180, 205)
local PURPLE = Color3.fromRGB(150, 90, 230)
local EQUIP = Color3.fromRGB(60, 170, 90)
local GRAY = Color3.fromRGB(62, 62, 80)
local LOCK_GOLD = Color3.fromRGB(255, 215, 80)
local ERROR_COLOR = Color3.fromRGB(255, 130, 130)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius == "round" and UDim.new(1, 0) or UDim.new(0, radius)
	c.Parent = parent
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

-- A title's text the way it looks over your head: its color, or its shimmer (Color -> Glow)
local function styleTitleText(l, title)
	local shimmer = l:FindFirstChild("Shimmer")
	if title.Glow then
		if not shimmer then
			shimmer = Instance.new("UIGradient")
			shimmer.Name = "Shimmer"
			shimmer.Rotation = 90
			shimmer.Parent = l
		end
		shimmer.Color = ColorSequence.new(title.Color, title.Glow)
		l.TextColor3 = WHITE
	else
		if shimmer then shimmer:Destroy() end
		l.TextColor3 = title.Color
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "TitleGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

-- ===== The TITLES button (under the SHOP button; LayoutUI moves it with the menu buttons) =====
local open = button(gui, "TITLES", UDim2.new(0, 10, 0.5, 118), UDim2.fromOffset(136, 40), PURPLE, 18)
open.Name = "TitlesButton"
open.Font = Enum.Font.GothamBlack
local openEdge = Instance.new("UIStroke")
openEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual -- outlines the letters
openEdge.Color = Color3.fromRGB(60, 25, 100)
openEdge.Thickness = 1.5
openEdge.Parent = open

-- ===== The window =====
local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.45)
window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
window.BackgroundColor3 = PANEL
window.Visible = false
window.Active = true
window.Parent = gui
corner(window, 14)
stroke(window, PURPLE, 2, 0.3)
local fit = Instance.new("UIScale")
fit.Parent = window
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	fit.Scale = math.min(1, (vp.X - 20) / WIDTH, (vp.Y - 40) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

label(window, "TITLES", UDim2.fromOffset(18, 10), UDim2.fromOffset(200, 32), 26, PURPLE, Enum.Font.GothamBlack)
local close = button(window, "X", UDim2.new(1, -44, 0, 10), UDim2.fromOffset(32, 32), Color3.fromRGB(190, 70, 70), 15)

-- your name tag as it looks right now
local preview = Instance.new("Frame")
preview.Position = UDim2.fromOffset(14, 50)
preview.Size = UDim2.new(1, -28, 0, 56)
preview.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
preview.Parent = window
corner(preview, 10)
stroke(preview, WHITE, 1, 0.85)
local previewTitle = label(preview, "", UDim2.fromOffset(0, 7), UDim2.new(1, 0, 0, 20), 17, WHITE, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
local previewName = label(preview, player.DisplayName, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 20), 15, WHITE, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
for _, l in ipairs({ previewTitle, previewName }) do
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(15, 12, 25)
	edge.Thickness = 1.5
	edge.Parent = l
end

local message = label(window, "", UDim2.new(0, 16, 1, -28), UDim2.new(1, -32, 0, 20), 13, ERROR_COLOR, Enum.Font.GothamBold)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(14, 116)
list.Size = UDim2.new(1, -28, 1, -150)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = window
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- One row per title: its name (styled), how to get it, and an Equip button or its state
local rows = {} -- [titleName] = { Frame, Stroke, Name, Desc, Button, Lock }
for _, title in ipairs(TitleData.Titles) do
	local row = Instance.new("Frame")
	row.LayoutOrder = title.Order
	row.Size = UDim2.new(1, -4, 0, ROW_H)
	row.BackgroundColor3 = CARD
	row.Parent = list
	corner(row, 10)
	local rowStroke = stroke(row, title.Color, 1, 0.6)
	local nameLabel = label(row, title.Name, UDim2.fromOffset(14, 10), UDim2.new(1, -140, 0, 22), 18, WHITE, Enum.Font.GothamBlack)
	styleTitleText(nameLabel, title)
	local desc = label(row, title.Description or "", UDim2.fromOffset(14, 34), UDim2.new(1, -140, 0, 20), 12, SUBTLE, Enum.Font.Gotham)
	desc.TextTruncate = Enum.TextTruncate.AtEnd
	local b = button(row, "", UDim2.new(1, -116, 0.5, -16), UDim2.fromOffset(104, 32), EQUIP, 13)
	local lock = label(row, "LOCKED", UDim2.new(1, -116, 0.5, -16), UDim2.fromOffset(104, 32), 12, LOCK_GOLD, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	rows[title.Name] = { Frame = row, Stroke = rowStroke, Name = nameLabel, Desc = desc, Button = b, Lock = lock }

	b.Activated:Connect(function()
		if player:GetAttribute("Title") == title.Name then return end
		local ok, res = pcall(function()
			return titleRemote:InvokeServer("Equip", title.Name)
		end)
		if not ok or type(res) ~= "table" then
			message.Text = "Couldn't reach the server. Try again."
			message.TextColor3 = ERROR_COLOR
		elseif not res.Success then
			message.Text = res.Error or "That didn't work."
			message.TextColor3 = ERROR_COLOR
		else
			message.Text = "Equipped " .. title.Name .. "!"
			message.TextColor3 = title.Color
		end
	end)
end

local function refresh()
	local owned = TitleData.ParseOwned(player:GetAttribute("OwnedTitles"))
	local equipped = player:GetAttribute("Title") or TitleData.Default
	for _, title in ipairs(TitleData.Titles) do
		local r = rows[title.Name]
		local has = owned[title.Name] == true
		local on = equipped == title.Name
		r.Frame.Visible = has or not title.Hidden
		r.Frame.BackgroundTransparency = has and 0 or 0.45
		r.Name.TextTransparency = has and 0 or 0.5
		r.Desc.TextTransparency = has and 0 or 0.3
		r.Stroke.Transparency = on and 0 or 0.6
		r.Stroke.Thickness = on and 2 or 1
		r.Button.Visible = has
		r.Lock.Visible = not has
		r.Button.Text = on and "EQUIPPED" or "Equip"
		r.Button.BackgroundColor3 = on and GRAY or EQUIP
		r.Button.AutoButtonColor = not on
	end
	local title = TitleData.Get(equipped) or TitleData.Get(TitleData.Default)
	previewTitle.Text = title.Name
	styleTitleText(previewTitle, title)
end
refresh()
player:GetAttributeChangedSignal("OwnedTitles"):Connect(refresh)
player:GetAttributeChangedSignal("Title"):Connect(refresh)

open.Activated:Connect(function()
	window.Visible = not window.Visible
	if window.Visible then
		message.Text = ""
		refresh()
	end
end)
close.Activated:Connect(function()
	window.Visible = false
end)
