-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: TraitData
-- (replaces the earlier version: new Mythic trait Catalyst: the unit's slow, freeze or bleed
--  is 50% stronger, see TraitData.EffectsFor. Its 0.3% chance comes from Steady)
-- Unit traits. In the lobby's Traits Cave, pick one of your units and summon a trait onto
-- it for Trait Shards (won from levels, see LevelData.WinShards). The trait boosts that unit
-- everywhere it is placed, and it stays until you summon on that unit again (the new trait
-- replaces the old one).
--
-- Each trait's Chance is the % chance to land it on one summon (all chances add up to 100).
-- The bonuses are multipliers on the unit's stats:
--   Damage   = 0.10   +10% damage
--   Speed    = 0.10   attacks 10% faster (the cooldown is divided by 1.10)
--   Range    = 0.10   +10% range
--   Cost     = 0.10   placing and upgrading costs 10% less
--   Income   = 0.10   cash units pay 10% more each payout
--   Effect   = 0.50   the unit's effect on enemies (UnitData.Effects) is 50% stronger: slows
--                    slow more, freezes last longer, bleeds hurt more
-- Icon is the symbol drawn on the trait's gem in menus (any emoji works).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))

local TraitData = {}

TraitData.SummonCost = 1 -- Trait Shards for one trait summon in the Traits Cave
TraitData.ShardColor = Color3.fromRGB(80, 230, 220) -- how Trait Shards show up in every UI

TraitData.Tiers = {
	{ Name = "Common",    Color = Color3.fromRGB(190, 190, 190) },
	{ Name = "Rare",      Color = Color3.fromRGB(80, 160, 255) },
	{ Name = "Epic",      Color = Color3.fromRGB(180, 90, 255) },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythic",    Color = Color3.fromRGB(255, 70, 110) },
}

TraitData.Traits = {
	-- Common: 5 traits, 11.9% each but Steady 11.6% (59.2% total)
	{ Name = "Sharp",        Tier = "Common", Chance = 11.9, Damage = 0.05, Icon = "🔪" },
	{ Name = "Swift",        Tier = "Common", Chance = 11.9, Speed = 0.05, Icon = "💨" },
	{ Name = "Keen",         Tier = "Common", Chance = 11.9, Range = 0.06, Icon = "👀" },
	{ Name = "Thrifty",      Tier = "Common", Chance = 11.9, Cost = 0.06, Icon = "💵" },
	{ Name = "Steady",       Tier = "Common", Chance = 11.6, Damage = 0.03, Range = 0.03, Icon = "⚓" },

	-- Rare: 4 traits, 6% each (24% total)
	{ Name = "Strong",       Tier = "Rare", Chance = 6, Damage = 0.12, Icon = "💪" },
	{ Name = "Rapid",        Tier = "Rare", Chance = 6, Speed = 0.10, Icon = "⚡" },
	{ Name = "Farsight",     Tier = "Rare", Chance = 6, Range = 0.12, Icon = "🔭" },
	{ Name = "Haggler",      Tier = "Rare", Chance = 6, Cost = 0.12, Icon = "💰" },

	-- Epic: 3 traits, 3.5% each (10.5% total)
	{ Name = "Berserker",    Tier = "Epic", Chance = 3.5, Damage = 0.22, Icon = "🔥" },
	{ Name = "Tempo",        Tier = "Epic", Chance = 3.5, Speed = 0.18, Icon = "⏳" },
	{ Name = "Sniper",       Tier = "Epic", Chance = 3.5, Range = 0.25, Damage = 0.05, Icon = "🎯" },

	-- Legendary: 3 traits, 1.5% each (4.5% total)
	{ Name = "Executioner",  Tier = "Legendary", Chance = 1.5, Damage = 0.35, Range = 0.05, Icon = "💀" },
	{ Name = "Overdrive",    Tier = "Legendary", Chance = 1.5, Speed = 0.25, Damage = 0.10, Icon = "🚀" },
	{ Name = "Golden Touch", Tier = "Legendary", Chance = 1.5, Income = 0.25, Cost = 0.15, Icon = "✨" },

	-- Mythic: 6 traits, really rare (1.8% total). Lord is the best for damage, Catalyst makes a
	-- unit's slow, freeze or bleed 50% stronger (it does nothing on units without one).
	{ Name = "Lord",         Tier = "Mythic", Chance = 0.1, Damage = 1.00, Range = 0.15, Speed = 0.10, Icon = "👑" },
	{ Name = "Celestial",    Tier = "Mythic", Chance = 0.2, Speed = 0.35, Damage = 0.30, Icon = "🌙" },
	{ Name = "Midas",        Tier = "Mythic", Chance = 0.3, Income = 0.60, Cost = 0.25, Icon = "🏆" },
	{ Name = "All-Seeing",   Tier = "Mythic", Chance = 0.4, Range = 0.50, Damage = 0.25, Icon = "🔮" },
	{ Name = "Phantom",      Tier = "Mythic", Chance = 0.5, Damage = 0.45, Speed = 0.15, Icon = "👻" },
	{ Name = "Catalyst",     Tier = "Mythic", Chance = 0.3, Effect = 0.50, Icon = "🧪" },
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

-- A trait's icon: a gem in the tier's color with the trait's symbol on it. Legendary and
-- Mythic icons get a ring around them. Returns a Frame `size` pixels square (not parented),
-- or nil for no trait.
function TraitData.MakeIcon(traitName, size)
	local t = TraitData.ByName[traitName]
	if not t then return nil end

	local holder = Instance.new("Frame")
	holder.Name = "TraitIcon"
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundTransparency = 1

	if t.Tier == "Legendary" or t.Tier == "Mythic" then
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(1, 1)
		ring.BackgroundTransparency = 1
		ring.Parent = holder
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(1, 0)
		ringCorner.Parent = ring
		local ringStroke = Instance.new("UIStroke")
		ringStroke.Color = t.Color
		ringStroke.Thickness = math.max(1, size / 14)
		ringStroke.Transparency = 0.15
		ringStroke.Parent = ring
	end

	local gem = Instance.new("Frame")
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromScale(0.68, 0.68)
	gem.Rotation = 45
	gem.BackgroundColor3 = t.Color
	gem.BorderSizePixel = 0
	gem.Parent = holder
	local gemCorner = Instance.new("UICorner")
	gemCorner.CornerRadius = UDim.new(0.18, 0)
	gemCorner.Parent = gem
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120))
	shade.Rotation = 45
	shade.Parent = gem
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 1
	edge.Transparency = 0.45
	edge.Parent = gem

	local glyph = Instance.new("TextLabel")
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(0.62, 0.62)
	glyph.BackgroundTransparency = 1
	glyph.Text = t.Icon or "?"
	glyph.TextScaled = true
	glyph.Font = Enum.Font.GothamBold
	glyph.TextColor3 = Color3.new(1, 1, 1)
	glyph.Parent = holder

	return holder
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

-- How much more a cash unit pays each payout (1.25 = +25%)
function TraitData.IncomeMult(name)
	local t = TraitData.Get(name)
	return 1 + (t and t.Income or 0)
end

-- How much stronger a unit's effects on enemies are (1.5 = +50%)
function TraitData.EffectMult(name)
	local t = TraitData.Get(name)
	return 1 + (t and t.Effect or 0)
end

-- A unit's effects on enemies (UnitData.Effects) with its trait applied: a slow slows more
-- (never past 95%), a freeze lasts longer, a bleed hurts more. Returns a new list.
function TraitData.EffectsFor(unitName, traitName)
	local mult = TraitData.EffectMult(traitName)
	local out = {}
	for _, effect in ipairs(UnitData.Effects[unitName] or {}) do
		local e = table.clone(effect)
		if e.Kind == "Slow" and e.Amount then
			e.Amount = math.min(e.Amount * mult, 0.95)
		elseif e.Kind == "Freeze" and e.Duration then
			e.Duration *= mult
		elseif e.Kind == "Bleed" and e.Percent then
			e.Percent *= mult
		end
		table.insert(out, e)
	end
	return out
end

-- The chips for a unit's effects with its trait applied, for StatIcons.Fill:
-- { { "Slow", "60% 2s" }, ... }
function TraitData.EffectChips(unitName, traitName)
	local chips = {}
	for _, effect in ipairs(TraitData.EffectsFor(unitName, traitName)) do
		table.insert(chips, { effect.Kind, UnitData.EffectText(effect) })
	end
	return chips
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
	add(t.Effect, "Effects", "+")
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
