-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: UnitData
-- (replaces the earlier version: Eclipse Emperor attacks every 2 seconds, and every hit makes
--  the enemy bleed for 10% of his damage each second until it dies; bleeds stack)

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
	Mythic    = { "Eclipse Emperor", "Starfall Kitsune", "Raijin Stormlord", "Void Shinobi", "Phoenix Archer", "Blizzard Shogun" },
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
	-- Mythics, each with its own strengths (the plain Mythic does 300 damage every 0.6s)
	["Starfall Kitsune"] = { Damage = 380, Range = 26, Cooldown = 0.55, Cost = 1800 }, -- the strongest
	["Raijin Stormlord"] = { Damage = 340 },                                -- lance: hits harder
	["Void Shinobi"]     = { Damage = 180, Cooldown = 0.3, Cost = 1400 },   -- daggers: very fast
	["Phoenix Archer"]   = { Damage = 260, Range = 30 },                    -- bow: reaches the furthest
	["Blizzard Shogun"]  = { Damage = 450, Cooldown = 0.8, Cost = 1600 },   -- katana: slow, huge hits
	["Eclipse Emperor"]  = { Cooldown = 2 },                                -- slow swings that leave a bleed
	-- Cash units don't attack (Range is only the size of the placement preview)
	["Coin Merchant"]    = { Damage = 0, Range = 4, Cooldown = 1, Cost = 400 },
	["Fortune Maiden"]   = { Damage = 0, Range = 4, Cooldown = 1, Cost = 800 },
}

-- ===== MELEE UNITS =====
-- Sword, katana, dagger and lance fighters reach half as far as ranged units (archers and
-- mages). This halves their Range above and the range they gain from upgrades. Add or remove
-- names to change who counts as melee; change MeleeRangeMult to change how far they reach.
UnitData.Melee = {
	["Blade Novice"] = true, ["Mist Scout"] = true, ["Storm Lancer"] = true, ["Iron Guard"] = true,
	["Shadow Dancer"] = true, ["Flame Ronin"] = true, ["Dragon Knight"] = true, ["Eclipse Emperor"] = true,
	["Raijin Stormlord"] = true, ["Void Shinobi"] = true, ["Blizzard Shogun"] = true,
}
UnitData.MeleeRangeMult = 0.5

function UnitData.IsMelee(unitName)
	return UnitData.Melee[unitName] == true
end

-- ===== CASH UNITS ("farms") =====
-- They don't attack. Every Interval seconds of match time (faster at 1.5x / 2x speed, and only
-- while a wave is on) each one pays its owner Income[level] cash. UpgradeCosts[n] is the price
-- to go from level n to level n + 1, so a farm's max level is the number of Income entries.
-- (A wave takes about 40 seconds, so 10-second payouts add up to roughly 4 x Income a wave.)
UnitData.Farms = {
	["Coin Merchant"] = {               -- Epic: place for $400
		Interval     = 10,
		Income       = { 60, 110, 200 },
		UpgradeCosts = { 600, 900 },
	},
	["Fortune Maiden"] = {              -- Legendary: place for $800, 5 upgrades
		Interval     = 10,
		Income       = { 90, 150, 240, 350, 500, 700 },
		UpgradeCosts = { 1000, 1400, 2000, 2800, 3800 },
	},
}

function UnitData.IsFarm(unitName)
	return UnitData.Farms[unitName] ~= nil
end

-- ===== LIMITED EVENT BANNER =====
-- While the event is active, every pull of the featured unit's rarity has a RateUp chance of
-- being the featured unit. When it ends, the featured unit can't be summoned any more
-- (players who got one keep it). No event is running: to run one, add a new unit to
-- UnitData.Units, put its name in Featured, and set Enabled = true (and EndsAt).
-- (Starfall Kitsune was the Starfall Festival's unit; it's a normal Mythic now.)
UnitData.Event = {
	Enabled = false,
	Name = "Starfall Festival",
	Featured = nil,       -- the event's unit (it can only be summoned while the event is on)
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

-- ===== EFFECTS ON ENEMIES =====
-- What a unit's attacks do to the enemy besides damage. Each one shows as an icon in the
-- unit's details (inventory and in-match panel, see StatIcons).
--   Slow    Amount = how much slower (0.4 = 40% slower), Duration = seconds
--   Freeze  Duration = seconds the enemy can't move
--   Every   (optional) seconds of match time before it can go off again: the unit's next
--           attack after that does it. Every attack if left out.
--   Bleed   Percent = how much of the unit's damage (at its level when it hits) the enemy
--           takes every Tick seconds (default 1), until it dies. Every hit adds another bleed.
--   Chance  (optional, 0 to 1) the chance an attack does it when it's ready; always if left out
-- They stack: every one that lands has its own timer, two 40% slows make an enemy 64% slower,
-- and an enemy can be slowed and frozen at once. Bosses take half as long (EffectResist in
-- GameService).
-- Example: ["Frost Mage"] = { { Kind = "Slow", Amount = 0.3, Duration = 2 } },
UnitData.Effects = {
	["Void Shinobi"]    = { { Kind = "Slow", Amount = 0.4, Duration = 2, Every = 3 } },
	["Blizzard Shogun"] = { { Kind = "Freeze", Duration = 3, Every = 4 } },
	["Eclipse Emperor"] = { { Kind = "Bleed", Percent = 0.1, Tick = 1 } },
}

-- An effect as short text for its icon: "40% 2s" (slow), "1s" (freeze), "1s 20%" (with a
-- chance), "10%/s" (bleed)
function UnitData.EffectText(effect)
	if effect.Kind == "Bleed" then
		local tick = effect.Tick or 1
		return string.format("%d%%/%s", math.floor((effect.Percent or 0) * 100 + 0.5), tick == 1 and "s" or string.format("%gs", tick))
	end
	local text = string.format("%gs", effect.Duration or 0)
	if effect.Amount then
		text = string.format("%d%% ", math.floor(effect.Amount * 100 + 0.5)) .. text
	end
	if effect.Chance and effect.Chance < 1 then
		text ..= string.format(" %d%%", math.floor(effect.Chance * 100 + 0.5))
	end
	return text
end

-- The chips for a unit's effects, for StatIcons.Fill: { { "Slow", "30% 2s" }, ... }
function UnitData.EffectChips(unitName)
	local chips = {}
	for _, effect in ipairs(UnitData.Effects[unitName] or {}) do
		table.insert(chips, { effect.Kind, UnitData.EffectText(effect) })
	end
	return chips
end

-- ===== INVENTORY SLOTS =====
-- Every unit you own takes one slot. Summoning stops when you're full (a x10 needs 10 free).
UnitData.BaseSlots = 250

-- Game passes that add slots. Make each pass in the Creator Dashboard (your experience >
-- Monetization > Passes) and paste its ID here. Passes left at 0 are ignored, and the
-- Inventory's "+ Slots" button offers the first pass the player doesn't own yet. (To sell
-- more than one, add more lines.)
UnitData.SlotPasses = {
	{ Id = 2044904916, Slots = 250, Name = "+250 Unit Slots" },
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
	if UnitData.IsMelee(unitName) then
		stats.Melee = true
		stats.Range *= UnitData.MeleeRangeMult
	end
	return stats
end

return UnitData