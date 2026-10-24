-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: LobbyTeleportUI
-- A "TP" (teleport) button beside the Settings button (lobby only). It moves and resizes with
-- the Inventory and Settings buttons in Screen Layout (see LayoutUI). It opens a small list of the
-- lobby's places (spawn, Wishing Fountain, team gates, Traits Cave, koi pond); pick one and
-- you're put in front of it, facing it, with the camera turned to look at it.
-- The places come from Lobby.TeleportSpots (see LobbyBuilder): invisible markers standing in
-- front of each place, facing it, with a "Label" and an "Order" attribute. Add a marker there
-- and it shows up in the list.
-- Hidden during a match.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
-- Only one copy may run (a second one would draw a second TP button)
if player:GetAttribute("LobbyTeleportUIRunning") then
	warn("[LobbyTeleportUI] another LobbyTeleportUI script is already running; this copy does nothing. Delete the extra copy.")
	return
end
player:SetAttribute("LobbyTeleportUIRunning", true)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- the lobby only: the match place has none of this
if require(ReplicatedStorage:WaitForChild("PlaceConfig")).IsMatchPlace() then return end

local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local COOLDOWN = 1 -- seconds between teleports

local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(22, 22, 36)
local GLASS = Color3.fromRGB(34, 34, 52)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
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

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyTeleportGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

-- Beside the Settings button (LayoutUI: 65x40 at 10 from the left, 26 below the middle)
local open = button(gui, "TP", UDim2.new(0, 81, 0.5, 26), UDim2.fromOffset(65, 40), Color3.fromRGB(150, 80, 220), 20)
open.Name = "TeleportButton"
open.Font = Enum.Font.GothamBlack
local openEdge = Instance.new("UIStroke")
openEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual -- outlines the letters, not the button
openEdge.Color = Color3.fromRGB(60, 25, 100)
openEdge.Thickness = 1.5
openEdge.Parent = open

-- The list, opening to the right of the button (inside it, so it moves and resizes with it
-- when the menu buttons are moved in Screen Layout)
local LIST_W, ROW_H = 190, 36
local list = Instance.new("Frame")
list.Position = UDim2.new(1, 8, 0, 0)
list.Size = UDim2.fromOffset(LIST_W, 0)
list.AutomaticSize = Enum.AutomaticSize.Y
list.BackgroundColor3 = PANEL
list.Visible = false
list.Active = true
list.Parent = open
corner(list, 12)
local listStroke = Instance.new("UIStroke")
listStroke.Color = WHITE
listStroke.Transparency = 0.8
listStroke.Parent = list
local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 8)
listPad.PaddingBottom = UDim.new(0, 8)
listPad.PaddingLeft = UDim.new(0, 8)
listPad.PaddingRight = UDim.new(0, 8)
listPad.Parent = list
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local title = Instance.new("TextLabel")
title.LayoutOrder = 0
title.Size = UDim2.new(1, 0, 0, 22)
title.BackgroundTransparency = 1
title.Text = "Teleport to..."
title.TextColor3 = WHITE
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = list

-- ===== Teleporting =====
local lastTeleport = -math.huge

local function teleportTo(spot)
	if os.clock() - lastTeleport < COOLDOWN then return end
	if player:GetAttribute("InMatch") or player:GetAttribute("Teleporting") then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then return end
	lastTeleport = os.clock()

	-- stand on the spot, facing the place (the root sits this high above the ground)
	local rootHeight = humanoid.RigType == Enum.HumanoidRigType.R15 and humanoid.HipHeight + hrp.Size.Y / 2 or 3
	local facing = spot.CFrame.Rotation
	char:PivotTo(CFrame.new(spot.Position + Vector3.new(0, rootHeight + 0.2, 0)) * facing)
	hrp.AssemblyLinearVelocity = Vector3.zero

	-- turn the camera to look past you at the place
	local look = spot.CFrame.LookVector
	local eye = hrp.Position - look * 14 + Vector3.new(0, 6, 0)
	camera.CFrame = CFrame.lookAt(eye, hrp.Position + look * 10 + Vector3.new(0, 2, 0))

	list.Visible = false
end

-- One row per spot in Lobby.TeleportSpots, in their Order
local rows = {}
local function addSpot(spot)
	if not spot:IsA("BasePart") or rows[spot] then return end
	local row = button(list, "", UDim2.new(), UDim2.new(1, 0, 0, ROW_H), GLASS, 14)
	row.LayoutOrder = spot:GetAttribute("Order") or 99
	row.AutoButtonColor = true
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 6, 1, -12)
	bar.Position = UDim2.fromOffset(8, 6)
	bar.BackgroundColor3 = spot.Color
	bar.BorderSizePixel = 0
	bar.Parent = row
	corner(bar, 3)
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(22, 0)
	text.Size = UDim2.new(1, -28, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = spot:GetAttribute("Label") or spot.Name
	text.TextColor3 = WHITE
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Parent = row
	row.Activated:Connect(function()
		if spot.Parent then
			teleportTo(spot)
		end
	end)
	rows[spot] = row
end

open.Activated:Connect(function()
	list.Visible = not list.Visible
end)

-- Hidden during a match (and while being sent to one)
local available = true -- false if the lobby has no teleport spots
local function updateShown()
	local busy = player:GetAttribute("InMatch") == true or player:GetAttribute("Teleporting") == true
	open.Visible = available and not busy
	if busy then
		list.Visible = false
	end
end
player:GetAttributeChangedSignal("InMatch"):Connect(updateShown)
player:GetAttributeChangedSignal("Teleporting"):Connect(updateShown)
updateShown()

local spots = workspace:WaitForChild("Lobby"):WaitForChild("TeleportSpots", 30)
if not spots then
	warn("[LobbyTeleportUI] Lobby.TeleportSpots not found, the Teleport button is hidden.")
	available = false
	updateShown()
	return
end
for _, spot in ipairs(spots:GetChildren()) do
	addSpot(spot)
end
spots.ChildAdded:Connect(addSpot)
