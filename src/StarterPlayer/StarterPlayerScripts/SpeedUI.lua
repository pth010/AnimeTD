-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: SpeedUI
-- Match speed buttons in the top-right corner during a match: 1x, 1.5x and 2x.
-- 1x and 1.5x are free. 2x needs the 2x Speed game pass; clicking it without the pass
-- opens the purchase prompt. The speed applies to your whole team's match.
-- (The pass ID is set in GameService: SPEED_2X_GAMEPASS_ID.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local speedRemote = ReplicatedStorage:WaitForChild("SetSpeedRemote")
local player = Players.LocalPlayer

local SPEEDS = { 1, 1.5, 2 }
local PAID_SPEED = 2

local ON = Color3.fromRGB(60, 160, 90)
local OFF = Color3.fromRGB(45, 45, 65)
local GOLD = Color3.fromRGB(255, 200, 70)

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(1, 0)
bar.Position = UDim2.new(1, -10, 0, 10)
bar.Size = UDim2.fromOffset(204, 44)
bar.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
bar.BackgroundTransparency = 0.15
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 5)
padding.PaddingRight = UDim.new(0, 5)
padding.PaddingTop = UDim.new(0, 5)
padding.PaddingBottom = UDim.new(0, 5)
padding.Parent = bar
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar

local message = Instance.new("TextLabel")
message.AnchorPoint = Vector2.new(1, 0)
message.Position = UDim2.new(1, -10, 0, 58)
message.Size = UDim2.fromOffset(260, 22)
message.BackgroundTransparency = 1
message.TextColor3 = Color3.fromRGB(255, 130, 130)
message.TextStrokeTransparency = 0.5
message.TextXAlignment = Enum.TextXAlignment.Right
message.Font = Enum.Font.GothamBold
message.TextSize = 14
message.Text = ""
message.Parent = gui

local messageToken = 0
local function showMessage(text)
	messageToken += 1
	local mine = messageToken
	message.Text = text
	task.delay(2.5, function()
		if messageToken == mine then message.Text = "" end
	end)
end

local buttons = {}
local busy = false

for i, speed in ipairs(SPEEDS) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(60, 34)
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = OFF
	b.Parent = bar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 2
	stroke.Color = GOLD
	stroke.Enabled = speed == PAID_SPEED
	stroke.Parent = b
	buttons[speed] = b

	b.Activated:Connect(function()
		if busy then return end
		busy = true
		local ok, res = pcall(function()
			return speedRemote:InvokeServer(speed)
		end)
		if not ok or type(res) ~= "table" then
			showMessage("Couldn't change speed. Try again.")
		elseif not res.Success and not res.Prompted then
			showMessage(res.Error or "Couldn't change speed.")
		end
		busy = false
	end)
end

local function refresh()
	local current = player:GetAttribute("MatchSpeed") or 1
	local ownsPaid = player:GetAttribute("Owns2xSpeed") == true
	for speed, b in pairs(buttons) do
		b.BackgroundColor3 = speed == current and ON or OFF
		local label = (speed == 1.5 and "1.5x") or (speed .. "x")
		if speed == PAID_SPEED and not ownsPaid then
			label ..= " ★" -- the gold border + star mark the paid option
		end
		b.Text = label
	end
end

local function updateVisibility()
	gui.Enabled = player:GetAttribute("InMatch") == true
end

refresh()
updateVisibility()
player:GetAttributeChangedSignal("MatchSpeed"):Connect(refresh)
player:GetAttributeChangedSignal("Owns2xSpeed"):Connect(refresh)
player:GetAttributeChangedSignal("InMatch"):Connect(updateVisibility)
