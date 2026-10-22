-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: ShopService
-- (new script: gives players what they bought in the Shop)
-- When a player buys a gem or Trait Shard pack (a developer product, see ShopData.Products),
-- Roblox calls ProcessReceipt here. It gives the gems / shards and remembers the purchase in
-- the "PurchaseHistory" data store, so the same purchase is never given twice, even if Roblox
-- asks again (it does when a server shuts down mid-purchase).
-- Game passes (2x Speed, slot passes) don't come through here: GameService and PlayerData
-- unlock those.
-- Only ONE script in the game may set ProcessReceipt: this one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ShopData = require(ReplicatedStorage:WaitForChild("ShopData"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

-- (GetDataStore throws if the place isn't published yet: purchases then wait until it is)
local history = nil
pcall(function()
	history = DataStoreService:GetDataStore("PurchaseHistory")
end)

local function grant(player, product)
	if product.Gems then
		PlayerData.AddGems(player, product.Gems)
	end
	if product.Shards then
		PlayerData.AddShards(player, product.Shards)
	end
	print(string.format("[ShopService] %s bought %s", player.Name, product.Name))
end

MarketplaceService.ProcessReceipt = function(info)
	if not history then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = info.PlayerId .. "_" .. info.PurchaseId

	-- already given? (Roblox can ask more than once)
	local ok, done = pcall(function()
		return history:GetAsync(key)
	end)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- try again later
	end
	if done then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- the player has to be here, with their data loaded, to receive it
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player or not PlayerData.Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- given next time they join
	end
	local product = ShopData.ProductById(info.ProductId)
	if not product then
		warn("[ShopService] unknown product " .. tostring(info.ProductId) .. ": add its ID to ShopData.Products")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	grant(player, product)
	local saved = pcall(function()
		history:SetAsync(key, true)
	end)
	if not saved then
		warn("[ShopService] couldn't record purchase " .. key .. " (it was given anyway)")
	end
	-- save the player straight away, so what they bought isn't lost if the server stops
	task.spawn(function()
		pcall(PlayerData.Save, player)
	end)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
