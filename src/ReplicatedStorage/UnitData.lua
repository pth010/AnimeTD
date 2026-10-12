-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: UnitData
-- (replaces the earlier version: adds combat stats and helper lookups)

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
	Epic      = { "Shadow Dancer", "Flame Ronin", "Moon Priestess" },
	Legendary = { "Dragon Knight", "Celestial Sage" },
	Mythic    = { "Eclipse Emperor" },
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
UnitData.StatOverrides = {}

-- How many different units a player can bring into a match
UnitData.TeamSize = 6

-- Units placed on the mountain's high ground get this much extra range
UnitData.HighGroundRangeMult = 1.3

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
