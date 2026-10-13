-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: ProgressData
-- (replaces the earlier version: units cap at level 5, each level adds +10% base damage,
--  and every level needs more XP than the last, see LevelXP)
-- Unit levels (from fusing) and evolution stars. Both are done in the Inventory.
--
-- FUSE: feed other units into a unit to give it XP. Each unit fed gives FodderXP for its
--   rarity. Every level above 1 adds +10% of the unit's base damage (Lv 5 = +40%).
--   Cash units get +10% income per level instead.
-- EVOLVE: spend extra copies of the SAME unit (plus some Gold) to give it a star.
--   Stars stack on top of levels. You always keep one copy of the unit.

local ProgressData = {}

ProgressData.MaxLevel = 5
ProgressData.PerLevel = 0.10 -- +10% base damage (or income) per level above 1

-- XP needed for each level-up: LevelXP[1] takes a unit from Lv 1 to Lv 2, and so on.
-- Each step costs more than the last. Lv 1 to Lv 5 is 2,400 XP in total.
ProgressData.LevelXP = { 200, 400, 700, 1100 }

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
	{ Copies = 2, Gold = 250,  Damage = 0.15, Range = 0.05, Income = 0.10 }, -- 1 star
	{ Copies = 3, Gold = 500,  Damage = 0.20, Range = 0.05, Income = 0.15 }, -- 2 stars
	{ Copies = 4, Gold = 1000, Damage = 0.30, Range = 0.10, Income = 0.25 }, -- 3 stars
}
ProgressData.MaxStars = #ProgressData.Evolutions
ProgressData.StarColor = Color3.fromRGB(255, 215, 80)

-- XP needed to go from `level` to `level + 1` (0 at max level)
function ProgressData.XPToNext(level)
	return ProgressData.LevelXP[level] or 0
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
