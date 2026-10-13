-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: TeleportUI
-- (replaces the earlier version: new script. A full-screen "Teleporting" card while the
--  server moves you between the lobby and a match server, kept on screen during the load.)
-- The server writes what's happening into your "TeleportStatus" attribute (see MatchTeleport)
-- and anything that went wrong into "TeleportError", which shows as a red message for a moment.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "TeleportGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100 -- above every other window
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(14, 12, 30)
back.BorderSizePixel = 0
back.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(60, 40, 120), Color3.fromRGB(14, 12, 30))
gradient.Rotation = 90
gradient.Parent = back

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.45)
title.Size = UDim2.new(0.9, 0, 0, 50)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.TextSize = 40
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Teleporting..."
title.Parent = back

local spinner = Instance.new("Frame")
spinner.AnchorPoint = Vector2.new(0.5, 0.5)
spinner.Position = UDim2.fromScale(0.5, 0.58)
spinner.Size = UDim2.fromOffset(46, 46)
spinner.BackgroundTransparency = 1
spinner.Parent = back
local ring = Instance.new("UIStroke")
ring.Thickness = 5
ring.Color = Color3.fromRGB(255, 205, 70)
ring.Parent = spinner
Instance.new("UICorner", spinner).CornerRadius = UDim.new(0.5, 0)
local ringGradient = Instance.new("UIGradient") -- makes the ring fade around, so it looks like it spins
ringGradient.Transparency = NumberSequence.new(0, 1)
ringGradient.Parent = ring
TweenService:Create(ringGradient, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
	{ Rotation = 360 }):Play()

-- Keep this screen up while Roblox loads the other server
TeleportService:SetTeleportGui(gui)

local function updateStatus()
	local status = player:GetAttribute("TeleportStatus")
	gui.Enabled = type(status) == "string" and status ~= ""
	if gui.Enabled then
		title.Text = status
	end
end
player:GetAttributeChangedSignal("TeleportStatus"):Connect(updateStatus)
updateStatus()

-- ===== ERROR MESSAGE =====
local errorGui = Instance.new("ScreenGui")
errorGui.Name = "TeleportErrorGui"
errorGui.ResetOnSpawn = false
errorGui.DisplayOrder = 101
errorGui.Parent = player.PlayerGui

local errorLabel = Instance.new("TextLabel")
errorLabel.AnchorPoint = Vector2.new(0.5, 0)
errorLabel.Position = UDim2.new(0.5, 0, 0, 60)
errorLabel.Size = UDim2.fromOffset(420, 44)
errorLabel.BackgroundColor3 = Color3.fromRGB(190, 45, 60)
errorLabel.TextColor3 = Color3.new(1, 1, 1)
errorLabel.Font = Enum.Font.GothamBold
errorLabel.TextSize = 16
errorLabel.TextWrapped = true
errorLabel.Visible = false
errorLabel.Parent = errorGui
Instance.new("UICorner", errorLabel).CornerRadius = UDim.new(0, 10)

local function updateError()
	local message = player:GetAttribute("TeleportError")
	errorLabel.Visible = type(message) == "string" and message ~= ""
	if errorLabel.Visible then
		errorLabel.Text = message
	end
end
player:GetAttributeChangedSignal("TeleportError"):Connect(updateError)
updateError()
