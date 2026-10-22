-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: ShopData
-- (new script: everything the Shop sells for Robux, in one place)
-- What the Shop window (ShopUI) shows, and what ShopService gives when a purchase goes through.
--
-- GAME PASSES are bought once and kept forever:
--   * 2x Speed (the 2x match speed button, see GameService and SpeedUI): its ID is below
--   * the slot passes: their IDs are in UnitData.SlotPasses
-- PRODUCTS (developer products) can be bought again and again: gem and Trait Shard packs.
--
-- Setup: make each pass in the Creator Dashboard (your experience > Monetization > Passes)
-- and each pack under Monetization > Developer Products, set its price there, and paste its
-- ID here. The Shop shows the price you set. Anything left at 0 shows as "Coming soon".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))

local ShopData = {}

ShopData.SpeedPassId = 2044694898 -- the 2x Speed game pass

-- Gem and Trait Shard packs. Gems / Shards = how many the pack gives. (The prices in the
-- comments are only reminders: the real price is the one set in the Creator Dashboard.)
ShopData.Products = {
	{ Id = 2045810929, Name = "Pouch of Gems",   Gems = 1000 },
	{ Id = 2045060940, Name = "Chest of Gems",   Gems = 5500 },
	{ Id = 2045960874, Name = "Vault of Gems",   Gems = 12000 },
	{ Id = 2047472311, Name = "Handful of Trait Shards", Shards = 5 },
	{ Id = 2045570873, Name = "Sack of Trait Shards",    Shards = 30 },
	{ Id = 2044526935, Name = "Crate of Trait Shards",   Shards = 100 }, -- 700 Robux
	{ Id = 2046062886, Name = "Hoard of Trait Shards",   Shards = 500 }, -- 1700 Robux
}

-- Every game pass in the Shop, in order: { Id, Name, Description, Kind = "Speed" / "Slots" }
function ShopData.Passes()
	local passes = {
		{ Id = ShopData.SpeedPassId, Name = "2x Speed", Kind = "Speed",
			Description = "Play matches at double speed." },
	}
	for _, pass in ipairs(UnitData.SlotPasses) do
		table.insert(passes, { Id = pass.Id, Name = pass.Name, Kind = "Slots",
			Description = string.format("Room for %d more units in your inventory.", pass.Slots) })
	end
	return passes
end

-- The product with this ID, or nil
function ShopData.ProductById(id)
	for _, product in ipairs(ShopData.Products) do
		if product.Id ~= 0 and product.Id == id then
			return product
		end
	end
	return nil
end

return ShopData
