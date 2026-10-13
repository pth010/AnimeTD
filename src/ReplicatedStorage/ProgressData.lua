-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: ProgressData
-- (replaces the earlier version: levels go to 100 at +2% base damage each, every level
--  needs a little more XP than the last, and each evolution star adds +20% damage)
-- Unit levels (from fusing) and evolution stars. Both are done in the Inventory.
--
-- FUSE: feed other units into a unit to give it XP. Each unit fed gives FodderXP for its
--   rarity. Every level above 1 adds +2% of the unit's base damage (Lv 100 = +198%).
--   Cash units get +2% income per level instead.
-- EVOLVE: spend spare copies of the SAME unit (plus some Gold) to give it a star.
--   Each star adds +20% damage on top of the leveled damage (base damage with the level
--   bonus already in it). Stars add up: 3 stars = +60% of the leveled damage.
--   Example: base 100 damage at Lv 51 (+100%) = 200, with 2 stars (+40%) = 280.

local ProgressData = {}

ProgressData.MaxLevel = 100
ProgressData.PerLevel = 0.02 -- +2% base damage (or income) per level above 1

-- XP needed for each level-up grows a little every level:
--   Lv 1 -> 2 takes LevelXPBase, and each level after that takes LevelXPGrowth more.
--   With 100 and 10: Lv 1->2 = 100 XP, Lv 50->51 = 590 XP, Lv 99->100 = 1,080 XP,
--   and Lv 1 to Lv 100 is 58,410 XP in total.
ProgressData.LevelXPBase = 100
ProgressData.LevelXPGrowth = 10

-- XP one copy gives when it is fused into another unit
ProgressData.FodderXP = {
	Common = 100,
	Rare = 250,
	Epic = 600,
	Legendary = 1500,
	Mythic = 4000,
}

-- Evolutions[n] = what it takes to reach n stars, and the bonus each star adds
ProgressData.Evolutions = {
	{ Copies = 2, Gold = 250,  Damage = 0.20, Range = 0.05, Income = 0.10 }, -- 1 star
	{ Copies = 3, Gold = 500,  Damage = 0.20, Range = 0.05, Income = 0.15 }, -- 2 stars
	{ Copies = 4, Gold = 1000, Damage = 0.20, Range = 0.10, Income = 0.25 }, -- 3 stars
}
ProgressData.MaxStars = #ProgressData.Evolutions
ProgressData.StarColor = Color3.fromRGB(255, 215, 80)

-- XP needed to go from `level` to `level + 1` (0 at max level)
function ProgressData.XPToNext(level)
	if level >= ProgressData.MaxLevel then return 0 end
	return ProgressData.LevelXPBase + ProgressData.LevelXPGrowth * (level - 1)
end

-- Total XP needed to reach max level
function ProgressData.MaxXP()
	local total = 0
	for level = 1, ProgressData.MaxLevel - 1 do
		total += ProgressData.XPToNext(level)
	end
	return total
end

-- Returns level, XP into that level, XP needed for the next level (0 at max)
function ProgressData.LevelFromXP(xp)
	local level = 1
	xp = xp or 0
	while level < ProgressData.MaxLevel and xp >= ProgressData.XPToNext(level) do
		xp -= ProgressData.XPToNext(level)
		level += 1
	end
	if level >= ProgressData.MaxLevel then
		return level, 0, 0
	end
	return level, xp, ProgressData.XPToNext(level)
end

-- Adds up every star's bonus up to `stars`
local function starBonus(stars, key)
	local total = 0
	for i = 1, math.min(stars or 0, ProgressData.MaxStars) do
		total += ProgressData.Evolutions[i][key] or 0
	end
	return total
end

-- Applies level + stars to a stats table (from UnitData.GetStats / TraitData.StatsFor)
function ProgressData.Apply(stats, xp, stars)
	if not stats then return nil end
	local level = ProgressData.LevelFromXP(xp)
	stats.Damage *= (1 + ProgressData.PerLevel * (level - 1)) * (1 + starBonus(stars, "Damage"))
	stats.Range *= 1 + starBonus(stars, "Range")
	return stats
end

-- How much more a cash unit pays from its level + stars (1.5 = +50%)
function ProgressData.IncomeMult(xp, stars)
	local level = ProgressData.LevelFromXP(xp)
	return (1 + ProgressData.PerLevel * (level - 1)) * (1 + starBonus(stars, "Income"))
end

-- "★★☆"
function ProgressData.StarText(stars)
	stars = stars or 0
	return string.rep("★", stars) .. string.rep("☆", ProgressData.MaxStars - stars)
end

-- Reads the "UnitProgress" player attribute ("Frost Mage=1200:2;Blade Novice=300:0")
-- into { [unitName] = { XP = 1200, Stars = 2 } }
function ProgressData.Parse(text)
	local out = {}
	for name, xp, stars in string.gmatch(text or "", "([^;=]+)=(%d+):(%d+)") do
		out[name] = { XP = tonumber(xp), Stars = tonumber(stars) }
	end
	return out
end

return ProgressData
