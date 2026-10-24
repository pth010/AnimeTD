-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: TitleService
-- (new script: player titles)
-- Puts a name tag over every player's head: their equipped title (TitleData) above their
-- display name, instead of Roblox's own name. It updates as soon as they equip another title.
-- Also answers the TITLES window (TitleUI): TitleRemote:InvokeServer("Equip", titleName).
-- Which titles a player owns and the one they have on are kept by PlayerData (and saved).
-- Runs in both places, so the tag shows in the lobby and in matches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TitleData = require(ReplicatedStorage:WaitForChild("TitleData"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local TAG_HEIGHT = 2.6     -- studs above the head
local TAG_DISTANCE = 90    -- studs: further away than this the tag hides
local EQUIP_COOLDOWN = 0.5 -- seconds between equips per player

-- ===== Equipping (from the TITLES window) =====
local remote = Instance.new("RemoteFunction")
remote.Name = "TitleRemote"
remote.Parent = ReplicatedStorage

local lastEquip = {}
remote.OnServerInvoke = function(player, action, name)
	if action ~= "Equip" or typeof(name) ~= "string" or #name > 50 then
		return { Success = false, Error = "Bad request." }
	end
	local now = os.clock()
	if lastEquip[player] and now - lastEquip[player] < EQUIP_COOLDOWN then
		return { Success = false, Error = "Slow down a little." }
	end
	lastEquip[player] = now
	local ok, err = PlayerData.SetTitle(player, name)
	return { Success = ok, Error = err }
end
Players.PlayerRemoving:Connect(function(player)
	lastEquip[player] = nil
end)

-- ===== The name tag =====
local function makeTag(player, head)
	local tag = Instance.new("BillboardGui")
	tag.Name = "TitleTag"
	tag.Size = UDim2.fromOffset(220, 46)
	tag.StudsOffset = Vector3.new(0, TAG_HEIGHT, 0)
	tag.MaxDistance = TAG_DISTANCE
	tag.LightInfluence = 0
	tag.Adornee = head

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = tag
	local titleEdge = Instance.new("UIStroke")
	titleEdge.Color = Color3.fromRGB(15, 12, 25)
	titleEdge.Thickness = 2
	titleEdge.Parent = title
	local shimmer = Instance.new("UIGradient") -- only switched on for titles with a Glow color
	shimmer.Name = "Shimmer"
	shimmer.Enabled = false
	shimmer.Parent = title

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(0, 20)
	name.Size = UDim2.new(1, 0, 0, 22)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = player.DisplayName
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = tag
	local nameEdge = Instance.new("UIStroke")
	nameEdge.Color = Color3.fromRGB(15, 12, 25)
	nameEdge.Thickness = 1.5
	nameEdge.Parent = name

	tag.Parent = head
	return tag
end

local function showTitle(player, tag)
	local title = TitleData.Get(player:GetAttribute("Title"))
	local label = tag:FindFirstChild("Title")
	if not label then return end
	label.Visible = title ~= nil -- (nothing until their data has loaded)
	if not title then return end
	label.Text = title.Name
	local shimmer = label:FindFirstChild("Shimmer")
	if title.Glow then
		label.TextColor3 = Color3.new(1, 1, 1)
		shimmer.Color = ColorSequence.new(title.Color, title.Glow)
		shimmer.Rotation = 90
		shimmer.Enabled = true
	else
		label.TextColor3 = title.Color
		shimmer.Enabled = false
	end
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not humanoid or not head then return end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- our tag replaces it
	local tag = makeTag(player, head)
	showTitle(player, tag)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player:GetAttributeChangedSignal("Title"):Connect(function()
		local head = player.Character and player.Character:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("TitleTag")
		if tag then showTitle(player, tag) end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end
