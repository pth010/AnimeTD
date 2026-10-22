-- PLACE IN: StarterPlayer > StarterPlayerScripts
-- TYPE: LocalScript
-- NAME: ShopUI
-- (replaces the earlier version: gems and Trait Shards have their own sections, each laid out
--  so every row is full)
-- A gold SHOP button under the Settings and TP buttons (it moves with them in Screen Layout).
-- It opens the Shop window:
--   * GAME PASSES (2x Speed, the slot passes): bought once, kept forever. Ones you own say OWNED.
--   * GEMS and TRAIT SHARDS: packs you can buy again and again.
-- Prices come straight from Roblox (whatever you set in the Creator Dashboard). What's for
-- sale is in ShopData; ShopService gives the gems / shards, and GameService / PlayerData
-- unlock the passes. Admins (PlaceConfig.Admins) own every pass already.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
-- Only one copy may run (a second one would draw a second SHOP button)
if player:GetAttribute("ShopUIRunning") then
	warn("[ShopUI] another ShopUI script is already running; this copy does nothing. Delete the extra copy.")
	return
end
player:SetAttribute("ShopUIRunning", true)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ShopData = require(ReplicatedStorage:WaitForChild("ShopData"))
local PlaceConfig = require(ReplicatedStorage:WaitForChild("PlaceConfig"))
local CurrencyIcons = require(ReplicatedStorage:WaitForChild("CurrencyIcons"))
local StatIcons = require(ReplicatedStorage:WaitForChild("StatIcons"))
local playerGui = player:WaitForChild("PlayerGui")

local WIDTH, HEIGHT = 520, 440
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(22, 22, 36)
local CARD = Color3.fromRGB(34, 34, 54)
local SUBTLE = Color3.fromRGB(180, 180, 205)
local DIM = Color3.fromRGB(120, 120, 145)
local GOLD = Color3.fromRGB(255, 190, 50)
local BUY = Color3.fromRGB(60, 170, 90)
local OWNED = Color3.fromRGB(90, 95, 120)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
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

local gui = Instance.new("ScreenGui")
gui.Name = "ShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

-- ===== The SHOP button (under Settings and TP; LayoutUI moves it with them) =====
local open = button(gui, "SHOP", UDim2.new(0, 10, 0.5, 72), UDim2.fromOffset(136, 40), GOLD, 18)
open.Name = "ShopButton"
open.Font = Enum.Font.GothamBlack
open.TextXAlignment = Enum.TextXAlignment.Left
local openPad = Instance.new("UIPadding")
openPad.PaddingLeft = UDim.new(0, 46)
openPad.Parent = open
local openEdge = Instance.new("UIStroke")
openEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual -- outlines the letters
openEdge.Color = Color3.fromRGB(120, 70, 0)
openEdge.Thickness = 1.5
openEdge.Parent = open
do
	local icon = CurrencyIcons.Make("Gems", 28)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, -38, 0.5, 0) -- (inside the padding on the left)
	icon.Parent = open
end

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
local windowStroke = Instance.new("UIStroke")
windowStroke.Color = GOLD
windowStroke.Thickness = 2
windowStroke.Transparency = 0.3
windowStroke.Parent = window
local fit = Instance.new("UIScale")
fit.Parent = window
local function fitToScreen()
	local vp = workspace.CurrentCamera.ViewportSize
	fit.Scale = math.min(1, (vp.X - 20) / WIDTH, (vp.Y - 40) / HEIGHT)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

label(window, "SHOP", UDim2.fromOffset(18, 10), UDim2.fromOffset(200, 32), 26, GOLD, Enum.Font.GothamBlack)
local message = label(window, "", UDim2.fromOffset(110, 16), UDim2.fromOffset(330, 20), 13, SUBTLE, Enum.Font.Gotham, Enum.TextXAlignment.Right)
local close = button(window, "X", UDim2.new(1, -44, 0, 10), UDim2.fromOffset(32, 32), Color3.fromRGB(190, 70, 70), 15)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(14, 52)
list.Size = UDim2.new(1, -28, 1, -64)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = window
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function sectionTitle(text)
	local l = label(list, text, UDim2.new(), UDim2.new(1, -8, 0, 22), 14, SUBTLE, Enum.Font.GothamBlack)
	l.LayoutOrder = nextOrder()
end

-- A grid of cards for one section
local function cardGrid(columns, cardHeight)
	local grid = Instance.new("Frame")
	grid.LayoutOrder = nextOrder()
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.Parent = list
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.CellSize = UDim2.new(1 / columns, -8 * (columns - 1) / columns, 0, cardHeight)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	return grid
end

-- One card: an icon, a name, a line under it and a buy button. Returns the buy button.
local function card(grid, iconFrame, name, line, lineColor)
	local c = Instance.new("Frame")
	c.BackgroundColor3 = CARD
	c.Parent = grid
	corner(c, 10)
	iconFrame.Position = UDim2.fromOffset(10, 10)
	iconFrame.Parent = c
	label(c, name, UDim2.fromOffset(58, 8), UDim2.new(1, -66, 0, 20), 15, WHITE, Enum.Font.GothamBlack)
	label(c, line, UDim2.fromOffset(58, 28), UDim2.new(1, -66, 0, 30), 12, lineColor or SUBTLE, Enum.Font.Gotham)
	local buy = button(c, "...", UDim2.new(0, 10, 1, -40), UDim2.new(1, -20, 0, 30), BUY, 14)
	return buy
end

-- "R$ 99" from Roblox, or nil (cached per ID)
local prices = {}
local function fetchPrice(id, infoType, onPrice)
	if prices[id] then
		onPrice(prices[id])
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info and info.PriceInRobux then
			prices[id] = "R$ " .. info.PriceInRobux
			onPrice(prices[id])
		end
	end)
end

-- ===== Game passes =====
sectionTitle("GAME PASSES  -  yours forever")
local passGrid = cardGrid(2, 120)
local passCards = {} -- { Pass, Button }

local function ownsPass(pass)
	if PlaceConfig.IsAdmin(player) then return true end
	if pass.Kind == "Speed" and player:GetAttribute("Owns2xSpeed") == true and pass.Id ~= 0 then return true end
	if pass.Id == 0 then return false end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
	end)
	return ok and owns == true
end

local function refreshPass(entry)
	task.spawn(function()
		local b = entry.Button
		if ownsPass(entry.Pass) then
			b.Text = "OWNED"
			b.BackgroundColor3 = OWNED
			b.AutoButtonColor = false
		elseif entry.Pass.Id == 0 then
			b.Text = "Coming soon"
			b.BackgroundColor3 = OWNED
			b.AutoButtonColor = false
		else
			b.Text = "Buy"
			b.BackgroundColor3 = BUY
			b.AutoButtonColor = true
			fetchPrice(entry.Pass.Id, Enum.InfoType.GamePass, function(price)
				if b.Text ~= "OWNED" then b.Text = "Buy  " .. price end
			end)
		end
	end)
end

for _, pass in ipairs(ShopData.Passes()) do
	local icon = StatIcons.Make(pass.Kind == "Speed" and "Speed" or "Backpack", 40)
	local b = card(passGrid, icon, pass.Name, pass.Description)
	local entry = { Pass = pass, Button = b }
	table.insert(passCards, entry)
	b.Activated:Connect(function()
		if b.Text == "OWNED" or pass.Id == 0 then return end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end)
end

-- ===== Gems, then Trait Shards =====
-- Each kind gets its own section, as many cards across as fill every row (3 gem packs = one
-- row of 3, 4 shard packs = two rows of 2), so there are no empty gaps.
local function columnsFor(count)
	if count % 3 == 0 then return 3 end
	if count % 2 == 0 then return 2 end
	return 3
end
local productCards = {}
for _, section in ipairs({ { Kind = "Gems", Title = "GEMS" }, { Kind = "Shards", Title = "TRAIT SHARDS" } }) do
	local products = {}
	for _, product in ipairs(ShopData.Products) do
		if (product.Gems and "Gems" or "Shards") == section.Kind then
			table.insert(products, product)
		end
	end
	if #products > 0 then
		sectionTitle(section.Title)
		local grid = cardGrid(columnsFor(#products), 120)
		for _, product in ipairs(products) do
			local kind = section.Kind
			local amount = product.Gems or product.Shards or 0
			local line = string.format("+%d %s", amount, kind == "Gems" and "Gems" or "Trait Shards")
			local b = card(grid, CurrencyIcons.Make(kind, 40), product.Name, line, CurrencyIcons.Colors[kind])
			table.insert(productCards, { Product = product, Button = b })
			b.Activated:Connect(function()
				if product.Id == 0 then return end
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
		end
	end
end

local function refreshProducts()
	for _, entry in ipairs(productCards) do
		local b = entry.Button
		if entry.Product.Id == 0 then
			b.Text = "Coming soon"
			b.BackgroundColor3 = OWNED
			b.AutoButtonColor = false
		else
			b.Text = "Buy"
			fetchPrice(entry.Product.Id, Enum.InfoType.Product, function(price)
				b.Text = "Buy  " .. price
			end)
		end
	end
end

local function refreshAll()
	for _, entry in ipairs(passCards) do
		refreshPass(entry)
	end
	refreshProducts()
end

-- ===== Opening, closing, after a purchase =====
open.Activated:Connect(function()
	window.Visible = not window.Visible
	if window.Visible then
		message.Text = ""
		refreshAll()
	end
end)
close.Activated:Connect(function()
	window.Visible = false
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, _, purchased)
	if who ~= player then return end
	if purchased then
		message.Text = "Thank you! Your pass is unlocked."
		message.TextColor3 = GOLD
	end
	task.wait(1) -- give the server a moment to unlock it
	for _, entry in ipairs(passCards) do
		refreshPass(entry)
	end
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, purchased)
	if userId ~= player.UserId or not purchased then return end
	message.Text = "Thank you! It's on its way to you."
	message.TextColor3 = GOLD
end)
player:GetAttributeChangedSignal("Owns2xSpeed"):Connect(function()
	if window.Visible then
		for _, entry in ipairs(passCards) do
			refreshPass(entry)
		end
	end
end)
