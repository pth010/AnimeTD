-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: GachaUI
-- (replaces the earlier version: the summon window pops up when you walk onto the
--  lobby's Summon Altar and closes when you step off, plus a close button)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local summonRemote = ReplicatedStorage:WaitForChild("SummonRemote")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "GachaGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(360, 420)
frame.Position = UDim2.new(0.5, -180, 0.5, -210)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
frame.Visible = false
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function makeLabel(text, pos, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = text
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 18
	l.RichText = true
	l.Parent = frame
	return l
end

local function makeButton(text, pos)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = UDim2.new(0.5, -15, 0, 44)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = Color3.fromRGB(90, 70, 220)
	b.Parent = frame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

makeLabel("Summon Banner", UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 30))
local info = makeLabel("", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 0, 24))
info.TextSize = 15

local results = makeLabel("", UDim2.fromOffset(10, 76), UDim2.new(1, -20, 0, 250))
results.TextSize = 16
results.TextYAlignment = Enum.TextYAlignment.Top

local single = makeButton("Summon x1 (100)", UDim2.new(0, 10, 1, -54))
local ten = makeButton("Summon x10 (900)", UDim2.new(0.5, 5, 1, -54))

-- Close button
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
close.Activated:Connect(function()
	frame.Visible = false
end)

-- Pop up when you walk onto the Summon Altar, close when you walk off
local altar = workspace:WaitForChild("Lobby"):WaitForChild("SummonAltar")
task.spawn(function()
	local wasOn = false
	while true do
		task.wait(0.2)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local on = false
		if hrp and not player:GetAttribute("InMatch") then
			local rel = altar.CFrame:PointToObjectSpace(hrp.Position)
			on = math.abs(rel.X) <= altar.Size.X / 2
				and math.abs(rel.Z) <= altar.Size.Z / 2
				and rel.Y > -2 and rel.Y < 8
		end
		if on and not wasOn then
			frame.Visible = true
		elseif not on and wasOn then
			frame.Visible = false
		end
		wasOn = on
	end
end)

-- Never leave the window open during a match
player:GetAttributeChangedSignal("InMatch"):Connect(function()
	if player:GetAttribute("InMatch") then
		frame.Visible = false
	end
end)

local function refreshInfo()
	info.Text = string.format("Gems: %d   |   Pity: %d/50", player:GetAttribute("Gems") or 0, player:GetAttribute("Pity") or 0)
end
refreshInfo()
player:GetAttributeChangedSignal("Gems"):Connect(refreshInfo)
player:GetAttributeChangedSignal("Pity"):Connect(refreshInfo)

local busy = false
local function doSummon(count)
	if busy then return end
	busy = true
	local res = summonRemote:InvokeServer(count)
	if res.Success then
		local lines = {}
		for _, unit in ipairs(res.Results) do
			local c = UnitData.RarityColor[unit.Rarity]:ToHex()
			local line = string.format('<font color="#%s">[%s] %s</font>', c, unit.Rarity, unit.Name)
			if unit.AutoDeleted then
				line ..= ' <font color="#888888">(auto-deleted)</font>'
			end
			table.insert(lines, line)
		end
		results.Text = table.concat(lines, "\n")
	else
		results.Text = res.Error
	end
	busy = false
end

single.Activated:Connect(function() doSummon(1) end)
ten.Activated:Connect(function() doSummon(10) end)
