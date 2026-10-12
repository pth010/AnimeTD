-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: TraitData
-- Unit traits. Every unit you own can carry one trait, which boosts that unit everywhere
-- it is placed. Roll (and re-roll) a trait in the Inventory for Gold.
--
-- Each trait's Chance is the % chance to land it on one roll (all chances add up to 100).
-- The bonuses are multipliers on the unit's stats:
--   Damage   = 0.10   +10% damage
--   Speed    = 0.10   attacks 10% faster (the cooldown is divided by 1.10)
--   Range    = 0.10   +10% range
--   Cost     = 0.10   placing and upgrading costs 10% less
--   Income   = 0.10   cash units pay 10% more each wave

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))

local TraitData = {}

TraitData.RollCost = 300 -- Gold for one roll

TraitData.Tiers = {
	{ Name = "Common",    Color = Color3.fromRGB(190, 190, 190) },
	{ Name = "Rare",      Color = Color3.fromRGB(80, 160, 255) },
	{ Name = "Epic",      Color = Color3.fromRGB(180, 90, 255) },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythic",    Color = Color3.fromRGB(255, 70, 110) },
}

TraitData.Traits = {
	-- Common: 5 traits, 11.9% each (59.5% total)
	{ Name = "Sharp",        Tier = "Common", Chance = 11.9, Damage = 0.05 },
	{ Name = "Swift",        Tier = "Common", Chance = 11.9, Speed = 0.05 },
	{ Name = "Keen",         Tier = "Common", Chance = 11.9, Range = 0.06 },
	{ Name = "Thrifty",      Tier = "Common", Chance = 11.9, Cost = 0.06 },
	{ Name = "Steady",       Tier = "Common", Chance = 11.9, Damage = 0.03, Range = 0.03 },

	-- Rare: 4 traits, 6% each (24% total)
	{ Name = "Strong",       Tier = "Rare", Chance = 6, Damage = 0.12 },
	{ Name = "Rapid",        Tier = "Rare", Chance = 6, Speed = 0.10 },
	{ Name = "Farsight",     Tier = "Rare", Chance = 6, Range = 0.12 },
	{ Name = "Haggler",      Tier = "Rare", Chance = 6, Cost = 0.12 },

	-- Epic: 3 traits, 3.5% each (10.5% total)
	{ Name = "Berserker",    Tier = "Epic", Chance = 3.5, Damage = 0.22 },
	{ Name = "Tempo",        Tier = "Epic", Chance = 3.5, Speed = 0.18 },
	{ Name = "Sniper",       Tier = "Epic", Chance = 3.5, Range = 0.25, Damage = 0.05 },

	-- Legendary: 3 traits, 1.5% each (4.5% total)
	{ Name = "Executioner",  Tier = "Legendary", Chance = 1.5, Damage = 0.35, Range = 0.05 },
	{ Name = "Overdrive",    Tier = "Legendary", Chance = 1.5, Speed = 0.25, Damage = 0.10 },
	{ Name = "Golden Touch", Tier = "Legendary", Chance = 1.5, Income = 0.25, Cost = 0.15 },

	-- Mythic: 5 traits, really rare (1.5% total). Lord is the best for damage.
	{ Name = "Lord",         Tier = "Mythic", Chance = 0.1, Damage = 1.00, Range = 0.15, Speed = 0.10 },
	{ Name = "Celestial",    Tier = "Mythic", Chance = 0.2, Speed = 0.35, Damage = 0.30 },
	{ Name = "Midas",        Tier = "Mythic", Chance = 0.3, Income = 0.60, Cost = 0.25 },
	{ Name = "All-Seeing",   Tier = "Mythic", Chance = 0.4, Range = 0.50, Damage = 0.25 },
	{ Name = "Phantom",      Tier = "Mythic", Chance = 0.5, Damage = 0.45, Speed = 0.15 },
}

TraitData.ByName = {}
TraitData.TierColor = {}
for _, tier in ipairs(TraitData.Tiers) do
	TraitData.TierColor[tier.Name] = tier.Color
end
for _, trait in ipairs(TraitData.Traits) do
	trait.Color = TraitData.TierColor[trait.Tier]
	TraitData.ByName[trait.Name] = trait
end

function TraitData.Get(name)
	return name and TraitData.ByName[name] or nil
end

local rng = Random.new()

-- Picks a random trait using the chances above. Returns the trait name.
function TraitData.Roll()
	local total = 0
	for _, trait in ipairs(TraitData.Traits) do
		total += trait.Chance
	end
	local pick = rng:NextNumber() * total
	for _, trait in ipairs(TraitData.Traits) do
		pick -= trait.Chance
		if pick < 0 then
			return trait.Name
		end
	end
	return TraitData.Traits[1].Name
end

-- How much cheaper placing/upgrading is (0.85 = 15% off)
function TraitData.CostMult(name)
	local t = TraitData.Get(name)
	return 1 - (t and t.Cost or 0)
end

-- How much more a cash unit pays each wave (1.25 = +25%)
function TraitData.IncomeMult(name)
	local t = TraitData.Get(name)
	return 1 + (t and t.Income or 0)
end

-- A unit's base stats with its trait applied (same layout as UnitData.GetStats)
function TraitData.StatsFor(unitName, traitName)
	local stats = UnitData.GetStats(unitName)
	if not stats then return nil end
	local t = TraitData.Get(traitName)
	if t then
		stats.Damage *= 1 + (t.Damage or 0)
		stats.Range *= 1 + (t.Range or 0)
		stats.Cooldown /= 1 + (t.Speed or 0)
		stats.Cost = math.floor(stats.Cost * TraitData.CostMult(traitName))
	end
	return stats
end

-- "+100% DMG, +15% RNG, +10% SPD"
function TraitData.Describe(name)
	local t = TraitData.Get(name)
	if not t then return "" end
	local parts = {}
	local function add(value, label, sign)
		if value then
			table.insert(parts, string.format("%s%d%% %s", sign, math.floor(value * 100 + 0.5), label))
		end
	end
	add(t.Damage, "DMG", "+")
	add(t.Speed, "SPD", "+")
	add(t.Range, "RNG", "+")
	add(t.Income, "Income", "+")
	add(t.Cost, "Cost", "-")
	return table.concat(parts, ", ")
end

-- "0.1%" / "11.9%"
function TraitData.ChanceText(name)
	local t = TraitData.Get(name)
	if not t then return "" end
	return (string.format("%.1f", t.Chance):gsub("%.0$", "")) .. "%"
end

-- Reads the "UnitTraits" player attribute ("Blade Novice=Lord;Frost Mage=Swift")
function TraitData.Parse(text)
	local traits = {}
	for unitName, traitName in string.gmatch(text or "", "([^;=]+)=([^;]+)") do
		traits[unitName] = traitName
	end
	return traits
end

return TraitData
