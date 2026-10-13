-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: UnitData
-- (replaces the earlier version: adds inventory slots and slot game passes, and
--  UnitData.ParseUnits for the per-unit inventory)

local UnitData = {}

-- Weights are relative (they don't have to add up to 100)
UnitData.Rarities = {
	{ Name = "Common",    Weight = 60,  Color = Color3.fromRGB(180, 180, 180), High = false },
	{ Name = "Rare",      Weight = 25,  Color = Color3.fromRGB(80, 160, 255),  High = false },
	{ Name = "Epic",      Weight = 10,  Color = Color3.fromRGB(170, 90, 255),  High = false },
	{ Name = "Legendary", Weight = 4.5, Color = Color3.fromRGB(255, 190, 40),  High = true  },
	{ Name = "Mythic",    Weight = 0.5, Color = Color3.fromRGB(255, 60, 90),   High = true  },
}

-- Original placeholder units
UnitData.Units = {
	Common    = { "Blade Novice", "Ember Archer", "Mist Scout" },
	Rare      = { "Storm Lancer", "Frost Mage", "Iron Guard" },
	Epic      = { "Shadow Dancer", "Flame Ronin", "Moon Priestess", "Coin Merchant" },
	Legendary = { "Dragon Knight", "Celestial Sage", "Fortune Maiden" },
	Mythic    = { "Eclipse Emperor", "Starfall Kitsune" }, -- Starfall Kitsune: event only (see UnitData.Event)
}

-- Combat stats per rarity (override per unit in UnitData.StatOverrides if you want)
-- Cost = in-match cash to place. Range in studs. Cooldown in seconds.
UnitData.RarityStats = {
	Common    = { Damage = 20,  Range = 14, Cooldown = 1.0, Cost = 100 },
	Rare      = { Damage = 35,  Range = 16, Cooldown = 0.9, Cost = 200 },
	Epic      = { Damage = 65,  Range = 18, Cooldown = 0.8, Cost = 400 },
	Legendary = { Damage = 140, Range = 20, Cooldown = 0.7, Cost = 800 },
	Mythic    = { Damage = 300, Range = 24, Cooldown = 0.6, Cost = 1500 },
}

-- Example: UnitData.StatOverrides["Ember Archer"] = { Range = 22 }
UnitData.StatOverrides = {
	-- The event unit is a cut above the regular Mythic
	["Starfall Kitsune"] = { Damage = 380, Range = 26, Cooldown = 0.55, Cost = 1800 },
	-- Cash units don't attack (Range is only the size of the placement preview)
	["Coin Merchant"]    = { Damage = 0, Range = 4, Cooldown = 1, Cost = 400 },
	["Fortune Maiden"]   = { Damage = 0, Range = 4, Cooldown = 1, Cost = 800 },
}

-- ===== CASH UNITS ("farms") =====
-- They don't attack. Every time your team clears a wave, each one pays its owner
-- Income[level] cash. UpgradeCosts[n] is the price to go from level n to level n + 1,
-- so a farm's max level is the number of Income entries.
UnitData.Farms = {
	["Coin Merchant"] = {               -- Epic: place for $400
		Income       = { 250, 450, 800 },
		UpgradeCosts = { 600, 900 },
	},
	["Fortune Maiden"] = {              -- Legendary: place for $800, 5 upgrades
		Income       = { 350, 600, 950, 1400, 2000, 2800 },
		UpgradeCosts = { 1000, 1400, 2000, 2800, 3800 },
	},
}

function UnitData.IsFarm(unitName)
	return UnitData.Farms[unitName] ~= nil
end

-- ===== LIMITED EVENT BANNER =====
-- While the event is active, every Mythic you pull has a RateUp chance of being the
-- featured unit. When it ends, the featured unit can't be summoned any more
-- (players who got one keep it).
UnitData.Event = {
	Enabled = true,
	Name = "Starfall Festival",
	Featured = "Starfall Kitsune",
	Tagline = "A nine-tailed fox spirit born from a falling star.",
	RateUp = 0.75,        -- 75% of Mythic pulls are the featured unit
	EndsAt = 1792972800,  -- Unix time (UTC) the event ends: 26 Oct 2026 00:00. nil = no end date
}

function UnitData.IsEventActive()
	local e = UnitData.Event
	return e ~= nil and e.Enabled and (e.EndsAt == nil or os.time() < e.EndsAt)
end

-- How many different units a player can bring into a match
UnitData.TeamSize = 6

-- How many of the SAME unit one player can have placed at once, by rarity
-- (e.g. up to 5 Blade Novices, but only 2 Eclipse Emperors)
UnitData.PlacementLimits = {
	Common    = 5,
	Rare      = 5,
	Epic      = 4,
	Legendary = 3,
	Mythic    = 2,
}

-- Units placed on the mountain's high ground get this much extra range
UnitData.HighGroundRangeMult = 1.3

-- ===== INVENTORY SLOTS =====
-- Every unit you own takes one slot. Summoning stops when you're full (a x10 needs 10 free).
UnitData.BaseSlots = 100

-- Game passes that add slots. Make each pass in the Creator Dashboard (your experience >
-- Monetization > Passes) and paste its ID here. Passes left at 0 are ignored, and the
-- Inventory's "+ Slots" button offers the first pass the player doesn't own yet.
UnitData.SlotPasses = {
	{ Id = 0, Slots = 50,  Name = "+50 Unit Slots" },
	{ Id = 0, Slots = 100, Name = "+100 Unit Slots" },
}

-- Lookups built automatically
UnitData.UnitRarity = {}
UnitData.RarityColor = {}

for _, r in ipairs(UnitData.Rarities) do
	UnitData.RarityColor[r.Name] = r.Color
end
for rarityName, list in pairs(UnitData.Units) do
	for _, unitName in ipairs(list) do
		UnitData.UnitRarity[unitName] = rarityName
	end
end

-- Reads the "Units" player attribute: one entry per unit you own,
-- "id|name|trait|xp|stars|locked" joined by ";" (trait is empty when the unit has none).
-- Returns a list of { Id, Name, Trait, XP, Stars, Locked } and a lookup by Id.
function UnitData.ParseUnits(text)
	local list, byId = {}, {}
	for entry in string.gmatch(text or "", "[^;]+") do
		local id, name, trait, xp, stars, locked = string.match(entry, "^(%d+)|([^|]*)|([^|]*)|(%d+)|(%d+)|(%d)$")
		if id and UnitData.UnitRarity[name] then
			local u = {
				Id = tonumber(id),
				Name = name,
				Trait = trait ~= "" and trait or nil,
				XP = tonumber(xp),
				Stars = tonumber(stars),
				Locked = locked == "1",
			}
			table.insert(list, u)
			byId[u.Id] = u
		end
	end
	return list, byId
end

function UnitData.GetPlacementLimit(unitName)
	local rarity = UnitData.UnitRarity[unitName]
	return rarity and UnitData.PlacementLimits[rarity] or math.huge
end

function UnitData.GetStats(unitName)
	local rarity = UnitData.UnitRarity[unitName]
	if not rarity then return nil end
	local stats = table.clone(UnitData.RarityStats[rarity])
	local override = UnitData.StatOverrides[unitName]
	if override then
		for k, v in pairs(override) do
			stats[k] = v
		end
	end
	return stats
end

return UnitData
