-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: AchievementUI
-- (replaces the earlier version: the popup and the AWARDS window show what each achievement
--  pays: Gems, Gold and Trait Shards)
-- When you earn an achievement (AchievementData) a popup slides down at the top of the screen:
-- a gold trophy, its name, what it was for, what it paid, and the title it unlocked if any. Several
-- in a row wait their turn. When you join with achievements earned elsewhere, one popup says
-- how many.
-- A teal AWARDS button under the TITLES button (it moves with the menu buttons in Screen
-- Layout) opens the list of every achievement by category, with your progress on each.
-- PlayerData awards them and sends the AchStats / Achievements player attributes.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
-- Only one copy may run (a second one would draw a second AWARDS button)
if player:GetAttribute("AchievementUIRunning") then
	warn("[AchievementUI] another AchievementUI script is already running; this copy does nothing. Delete the extra copy.")
	return
end
player:SetAttribute("AchievementUIRunning", true)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local AchievementData = require(ReplicatedStorage:WaitForChild("AchievementData"))
local TitleData = require(ReplicatedStorage:WaitForChild("TitleData"))
local achievementEvent = ReplicatedStorage:WaitForChild("AchievementEvent")
local playerGui = player:WaitForChild("PlayerGui")

local WIDTH, HEIGHT = 560, 480
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(22, 22, 36)
local CARD = Color3.fromRGB(34, 34, 54)
local SUBTLE = Color3.fromRGB(180, 180, 205)
local GOLD = Color3.fromRGB(255, 205, 70)
local TEAL = Color3.fromRGB(40, 165, 150)
local BAR_BACK = Color3.fromRGB(20, 20, 32)

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

-- A trophy `size` pixels square: a cup with two handles on a stem and a base. Gold when earned.
local function trophy(parent, size, earned)
	local color = earned and GOLD or Color3.fromRGB(80, 80, 100)
	local holder = frame(parent, UDim2.new(), UDim2.fromOffset(size, size), WHITE, 1)
	local cup = frame(holder, UDim2.fromScale(0.25, 0.08), UDim2.fromScale(0.5, 0.48), color)
	corner(cup, math.floor(size * 0.18))
	if earned then
		local shine = Instance.new("UIGradient")
		shine.Color = ColorSequence.new(Color3.fromRGB(255, 245, 190), Color3.fromRGB(215, 140, 20))
		shine.Rotation = 45
		shine.Parent = cup
	end
	for _, x in ipairs({ 0.1, 0.72 }) do -- handles: rings either side
		local handle = frame(holder, UDim2.fromScale(x, 0.16), UDim2.fromScale(0.18, 0.24), WHITE, 1)
		corner(handle, "round")
		stroke(handle, color, math.max(1.5, size / 16))
	end
	frame(holder, UDim2.fromScale(0.44, 0.55), UDim2.fromScale(0.12, 0.18), color) -- stem
	local base = frame(holder, UDim2.fromScale(0.28, 0.72), UDim2.fromScale(0.44, 0.14), color)
	corner(base, 3)
	return holder
end

local gui = Instance.new("ScreenGui")
gui.Name = "AchievementGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 8 -- (the popup shows over other windows)
gui.Parent = playerGui

-- ===== The popup =====
local POP_W, POP_H = 400, 112
local popup = frame(gui, UDim2.new(0.5, 0, 0, -POP_H - 20), UDim2.fromOffset(POP_W, POP_H), PANEL)
popup.AnchorPoint = Vector2.new(0.5, 0)
popup.Visible = false
corner(popup, 14)
stroke(popup, GOLD, 2, 0.1)
do
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(Color3.fromRGB(70, 58, 30), Color3.fromRGB(22, 22, 36))
	sheen.Rotation = 90
	sheen.Parent = popup
end
local popTrophy = trophy(popup, 60, true)
popTrophy.Position = UDim2.fromOffset(14, 18)
local popHeader = label(popup, "ACHIEVEMENT UNLOCKED", UDim2.fromOffset(86, 10), UDim2.new(1, -100, 0, 16), 12, GOLD, Enum.Font.GothamBlack)
local popName = label(popup, "", UDim2.fromOffset(86, 26), UDim2.new(1, -100, 0, 26), 21, WHITE, Enum.Font.GothamBlack)
popName.TextWrapped = false
popName.TextTruncate = Enum.TextTruncate.AtEnd
local popDesc = label(popup, "", UDim2.fromOffset(86, 52), UDim2.new(1, -100, 0, 18), 13, SUBTLE, Enum.Font.Gotham)
popDesc.TextTruncate = Enum.TextTruncate.AtEnd
local REWARD_GREEN = Color3.fromRGB(130, 235, 140)
local popReward = label(popup, "", UDim2.fromOffset(86, 71), UDim2.new(1, -100, 0, 16), 13, REWARD_GREEN, Enum.Font.GothamBlack)
local popTitle = label(popup, "", UDim2.fromOffset(86, 89), UDim2.new(1, -100, 0, 16), 12, GOLD, Enum.Font.GothamBold)

local queue = {}
local showing = false
local SHOW_TIME = 4

local function showNext()
	if showing or #queue == 0 then return end
	showing = true
	local item = table.remove(queue, 1)
	if item.Summary then
		popHeader.Text = "WELCOME BACK"
		popName.Text = string.format("%d achievement%s earned!", item.Summary, item.Summary == 1 and "" or "s")
		popDesc.Text = "See them in the AWARDS window."
		popReward.Text = AchievementData.RewardText(item.Reward)
		popTitle.Text = ""
	else
		local a = AchievementData.Get(item.Id)
		if not a then
			showing = false
			showNext()
			return
		end
		popHeader.Text = "ACHIEVEMENT UNLOCKED"
		popName.Text = a.Name
		popDesc.Text = a.Description
		popReward.Text = AchievementData.RewardText(a.Reward)
		local title = a.Title and TitleData.Get(a.Title)
		popTitle.Text = title and ("Title unlocked: " .. title.Name .. "  (equip it in TITLES)") or ""
		popTitle.TextColor3 = title and title.Color or GOLD
	end
	popup.Position = UDim2.new(0.5, 0, 0, -POP_H - 20)
	popup.Visible = true
	TweenService:Create(popup, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 16) }):Play()
	task.delay(SHOW_TIME, function()
		local away = TweenService:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -POP_H - 20) })
		away:Play()
		away.Completed:Wait()
		popup.Visible = false
		showing = false
		showNext()
	end)
end

achievementEvent.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	table.insert(queue, data)
	showNext()
end)

-- ===== The AWARDS button (under TITLES; LayoutUI moves it with the menu buttons) =====
local open = button(gui, "AWARDS", UDim2.new(0, 10, 0.5, 164), UDim2.fromOffset(136, 40), TEAL, 18)
open.Name = "AwardsButton"
open.Font = Enum.Font.GothamBlack
open.TextXAlignment = Enum.TextXAlignment.Left
do
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 40)
	pad.Parent = open
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual -- outlines the letters
	edge.Color = Color3.fromRGB(10, 60, 55)
	edge.Thickness = 1.5
	edge.Parent = open
	local icon = trophy(open, 28, true)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, -34, 0.5, 0) -- (inside the padding on the left)
end

-- ===== The window =====
local window = frame(gui, UDim2.fromScale(0.5, 0.45), UDim2.fromOffset(WIDTH, HEIGHT), PANEL)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Visible = false
window.Active = true
corner(window, 14)
stroke(window, TEAL, 2, 0.3)
local fit = Instance.new("UIScale")
fit.Parent = window
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	fit.Scale = math.min(1, (vp.X - 20) / WIDTH, (vp.Y - 40) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

label(window, "ACHIEVEMENTS", UDim2.fromOffset(18, 10), UDim2.fromOffset(260, 32), 26, TEAL, Enum.Font.GothamBlack)
local countText = label(window, "", UDim2.new(1, -230, 0, 16), UDim2.fromOffset(170, 20), 14, SUBTLE, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
local close = button(window, "X", UDim2.new(1, -44, 0, 10), UDim2.fromOffset(32, 32), Color3.fromRGB(190, 70, 70), 15)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(14, 52)
list.Size = UDim2.new(1, -28, 1, -64)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = window
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- One row per achievement (built once), grouped under category headings
local rows = {} -- [id] = { Frame, Icon, Bar, BarFill, Progress, Name, Stroke }
local order = 0
for _, category in ipairs(AchievementData.Categories) do
	order += 1
	local heading = label(list, string.upper(category), UDim2.new(), UDim2.new(1, -6, 0, 24), 13, SUBTLE, Enum.Font.GothamBlack)
	heading.LayoutOrder = order
	for _, a in ipairs(AchievementData.List) do
		if a.Category == category then
			order += 1
			local row = frame(list, UDim2.new(), UDim2.new(1, -6, 0, a.Title and 84 or 68), CARD)
			row.LayoutOrder = order
			corner(row, 10)
			local rowStroke = stroke(row, GOLD, 1, 1)
			local nameLabel = label(row, a.Name, UDim2.fromOffset(56, 6), UDim2.new(1, -230, 0, 20), 15, WHITE, Enum.Font.GothamBlack)
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			local desc = label(row, a.Description, UDim2.fromOffset(56, 27), UDim2.new(1, -230, 0, 18), 12, SUBTLE, Enum.Font.Gotham)
			desc.TextTruncate = Enum.TextTruncate.AtEnd
			label(row, AchievementData.RewardText(a.Reward), UDim2.fromOffset(56, 46), UDim2.new(1, -230, 0, 16), 12,
				REWARD_GREEN, Enum.Font.GothamBlack)
			if a.Title then
				local title = TitleData.Get(a.Title)
				label(row, "Title: " .. a.Title, UDim2.fromOffset(56, 63), UDim2.new(1, -230, 0, 16), 12,
					title and title.Color or GOLD, Enum.Font.GothamBold)
			end
			local bar = frame(row, UDim2.new(1, -164, 0.5, -3), UDim2.fromOffset(150, 8), BAR_BACK)
			corner(bar, "round")
			local fill = frame(bar, UDim2.new(), UDim2.fromScale(0, 1), TEAL)
			corner(fill, "round")
			local progress = label(row, "", UDim2.new(1, -164, 0.5, -24), UDim2.fromOffset(150, 18), 12, SUBTLE, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
			rows[a.Id] = { Frame = row, Icon = nil, Bar = bar, Fill = fill, Progress = progress, Name = nameLabel, Stroke = rowStroke }
		end
	end
end

local function refresh()
	local stats = AchievementData.ParseStats(player:GetAttribute("AchStats"))
	local earned = AchievementData.ParseEarned(player:GetAttribute("Achievements"))
	local count = 0
	for _, a in ipairs(AchievementData.List) do
		local r = rows[a.Id]
		local done = earned[a.Id] == true
		if done then count += 1 end
		local value = math.min(stats[a.Stat] or 0, a.Goal)
		if r.Icon then r.Icon:Destroy() end
		r.Icon = trophy(r.Frame, 40, done)
		r.Icon.Position = UDim2.new(0, 8, 0.5, -20)
		r.Fill.Size = UDim2.fromScale(done and 1 or value / a.Goal, 1)
		r.Fill.BackgroundColor3 = done and GOLD or TEAL
		r.Progress.Text = done and "EARNED" or string.format("%s / %s", AchievementData.Commas(value), AchievementData.Commas(a.Goal))
		r.Progress.TextColor3 = done and GOLD or SUBTLE
		r.Name.TextColor3 = done and GOLD or WHITE
		r.Stroke.Transparency = done and 0.4 or 1
	end
	countText.Text = string.format("%d / %d earned", count, #AchievementData.List)
end

open.Activated:Connect(function()
	window.Visible = not window.Visible
	if window.Visible then refresh() end
end)
close.Activated:Connect(function()
	window.Visible = false
end)
for _, attribute in ipairs({ "AchStats", "Achievements" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if window.Visible then refresh() end
	end)
end
