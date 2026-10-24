-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: CurrencyUI
-- (replaces the earlier version: the counter can be moved and resized in the Screen Layout
--  panel, see LayoutUI)
-- The counter uses the gem, coin and crystal icons from CurrencyIcons.
-- Shows your Gems, Gold and Trait Shards on the left side of the screen while in the lobby, and a reward
-- popup when you earn something (e.g. "VICTORY! +375 Gold +75 Gems" after winning a match).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local CurrencyIcons = require(ReplicatedStorage:WaitForChild("CurrencyIcons"))
local rewardEvent = ReplicatedStorage:WaitForChild("RewardEvent")
local player = Players.LocalPlayer

local GEM_COLOR = Color3.fromRGB(130, 220, 255)
local GOLD_COLOR = Color3.fromRGB(255, 205, 70)
local SHARD_COLOR = TraitData.ShardColor
local PANEL = Color3.fromRGB(25, 25, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "CurrencyGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")

-- ===== Counter (sits just above the Inventory button) =====
local counter = Instance.new("Frame")
counter.Name = "Counter" -- LayoutUI finds it by this name
counter.Position = UDim2.new(0, 10, 0.5, -146)
counter.Size = UDim2.fromOffset(130, 118)
counter.BackgroundColor3 = PANEL
counter.BackgroundTransparency = 0.1
counter.Parent = gui
Instance.new("UICorner", counter).CornerRadius = UDim.new(0, 10)

local function counterRow(y, kind, color)
	local icon = CurrencyIcons.Make(kind, 30)
	icon.Position = UDim2.fromOffset(8, y)
	icon.Parent = counter

	local amount = Instance.new("TextLabel")
	amount.Position = UDim2.fromOffset(44, y)
	amount.Size = UDim2.new(1, -52, 0, 30)
	amount.BackgroundTransparency = 1
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.TextColor3 = color
	amount.Font = Enum.Font.GothamBlack
	amount.TextSize = 18
	amount.TextScaled = false
	amount.Parent = counter
	return amount
end

local gemsLabel = counterRow(10, "Gems", GEM_COLOR)
local goldLabel = counterRow(44, "Gold", GOLD_COLOR)
local shardsLabel = counterRow(78, "Shards", SHARD_COLOR) -- Trait Shards (spent in the Traits Cave)

-- 1234567 -> "1,234,567"
local function commas(n)
	local s = tostring(math.floor(n))
	local sign, digits = string.match(s, "^(-?)(%d+)$")
	if not digits then return s end
	return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function refreshCounter()
	gemsLabel.Text = commas(player:GetAttribute("Gems") or 0)
	goldLabel.Text = commas(player:GetAttribute("Gold") or 0)
	shardsLabel.Text = commas(player:GetAttribute("Shards") or 0)
end
refreshCounter()
player:GetAttributeChangedSignal("Gems"):Connect(refreshCounter)
player:GetAttributeChangedSignal("Gold"):Connect(refreshCounter)
player:GetAttributeChangedSignal("Shards"):Connect(refreshCounter)

local function updateVisibility()
	counter.Visible = player:GetAttribute("InMatch") ~= true
end
updateVisibility()
player:GetAttributeChangedSignal("InMatch"):Connect(updateVisibility)

-- ===== Reward popup =====
local popup = Instance.new("Frame")
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.fromScale(0.5, 0.38)
popup.Size = UDim2.fromOffset(320, 150)
popup.BackgroundColor3 = PANEL
popup.Visible = false
popup.Parent = gui
Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 14)
local popupStroke = Instance.new("UIStroke")
popupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
popupStroke.Color = GOLD_COLOR
popupStroke.Thickness = 3
popupStroke.Parent = popup
local popupScale = Instance.new("UIScale")
popupScale.Parent = popup

local function popupLabel(y, height, size, color)
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromOffset(0, y)
	l.Size = UDim2.new(1, 0, 0, height)
	l.BackgroundTransparency = 1
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.Font = Enum.Font.GothamBlack
	l.TextSize = size
	l.Parent = popup
	return l
end

local popupTitle = popupLabel(12, 40, 32, Color3.new(1, 1, 1))
local popupGold = popupLabel(62, 32, 24, GOLD_COLOR)
local popupGems = popupLabel(98, 32, 24, GEM_COLOR)

local popupToken = 0
rewardEvent.OnClientEvent:Connect(function(reward)
	if type(reward) ~= "table" then return end
	popupToken += 1
	local mine = popupToken

	popupTitle.Text = reward.Title or "REWARD!"
	popupGold.Text = (reward.Gold and reward.Gold > 0) and ("+" .. commas(reward.Gold) .. " Gold") or ""
	popupGems.Text = (reward.Gems and reward.Gems > 0) and ("+" .. commas(reward.Gems) .. " Gems") or ""

	popupScale.Scale = 0.4
	popup.Visible = true
	TweenService:Create(popupScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(5, function()
		if popupToken == mine then
			popup.Visible = false
		end
	end)
end)
