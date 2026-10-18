-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: StarConfig
-- Every number that shapes Starfall Scramble lives here, shared by the server and the HUD.
-- Tweak freely: star values, upgrade prices, the Supernova (rebirth) curve, events, meteors.

local StarConfig = {}

-- ===== Stars =====
-- Value   how many stars it adds to your bag when you grab it
-- Weight  how often it spawns compared to the others
StarConfig.Stars = {
	{ Name = "Spark",  Value = 1,   Weight = 70, Size = 1.3, Color = Color3.fromRGB(255, 244, 190) },
	{ Name = "Azure",  Value = 5,   Weight = 22, Size = 1.6, Color = Color3.fromRGB(110, 200, 255) },
	{ Name = "Golden", Value = 25,  Weight = 7,  Size = 2.0, Color = Color3.fromRGB(255, 200, 60) },
	{ Name = "Prism",  Value = 150, Weight = 1,  Size = 2.5, Color = Color3.fromRGB(255, 120, 230), Rainbow = true },
}
StarConfig.ByName = {}
for _, def in ipairs(StarConfig.Stars) do
	StarConfig.ByName[def.Name] = def
end

StarConfig.MaxStars = 90          -- most stars lying on the island at once
StarConfig.StarLifetime = 60      -- seconds a landed star waits before fading away
StarConfig.FallTime = 1.4         -- seconds a star takes to fall from the sky

-- ===== Meteors =====
StarConfig.MeteorWarning = 2.2    -- seconds the red circle shows before impact
StarConfig.MeteorRadius = 11      -- blast radius in studs
StarConfig.MeteorDropShare = 0.5  -- share of carried stars knocked out of your bag
StarConfig.MeteorAimAtPlayers = 0.6 -- chance a meteor aims at a player instead of a random spot

-- ===== Normal play and timed events =====
-- SpawnInterval  seconds between stars (divided by sqrt(players), so busy servers rain more)
-- MeteorDelay    { min, max } seconds between meteors
-- Weights        multiplies a star type's spawn weight during the event
StarConfig.Normal = { SpawnInterval = 0.9, MeteorDelay = { 5, 9 } }
StarConfig.Events = {
	["Meteor Shower"] = {
		Description = "Stars pour down, and so do the meteors!",
		Color = Color3.fromRGB(255, 120, 70),
		SpawnInterval = 0.3, MeteorDelay = { 1.2, 2.4 },
		Weights = { Azure = 1.5, Golden = 4, Prism = 2 },
	},
	["Prism Rain"] = {
		Description = "Rainbow Prism stars everywhere. Grab them fast!",
		Color = Color3.fromRGB(255, 120, 230),
		SpawnInterval = 0.6, MeteorDelay = { 6, 10 },
		Weights = { Golden = 1.5, Prism = 15 },
	},
}
StarConfig.EventOrder = { "Meteor Shower", "Prism Rain" }
StarConfig.EventEvery = 210 -- seconds from the end of one event to the start of the next
StarConfig.EventLength = 45

-- ===== Upgrades (bought with Stardust) =====
-- cost of the next level = Base * Growth ^ currentLevel
StarConfig.Upgrades = {
	{ Id = "Bag",    Name = "Star Bag",     Description = "Carry more stars per trip.",          Base = 40,  Growth = 1.6,  Max = 30 },
	{ Id = "Speed",  Name = "Moon Boots",   Description = "Run faster.",                         Base = 60,  Growth = 1.75, Max = 12 },
	{ Id = "Magnet", Name = "Star Magnet",  Description = "Grab stars from further away.",       Base = 75,  Growth = 1.7,  Max = 15 },
	{ Id = "Luck",   Name = "Lucky Clover", Description = "Chance for a grabbed star to count double.", Base = 150, Growth = 1.8, Max = 20 },
}
StarConfig.UpgradeById = {}
for _, def in ipairs(StarConfig.Upgrades) do
	StarConfig.UpgradeById[def.Id] = def
end

function StarConfig.Capacity(level)
	return math.floor(20 * 1.4 ^ level)
end

function StarConfig.Speed(level)
	return 16 + 1.5 * level
end

function StarConfig.Magnet(level)
	return 7 + 1.5 * level
end

function StarConfig.LuckChance(level)
	return 0.04 * level
end

function StarConfig.UpgradeCost(def, level)
	return math.floor(def.Base * def.Growth ^ level)
end

-- What an upgrade does at a level, as short text for the shop ("54 stars")
function StarConfig.Describe(id, level)
	if id == "Bag" then
		return string.format("%d stars", StarConfig.Capacity(level))
	elseif id == "Speed" then
		return string.format("%g speed", StarConfig.Speed(level))
	elseif id == "Magnet" then
		return string.format("%g studs", StarConfig.Magnet(level))
	elseif id == "Luck" then
		return string.format("%d%%", math.floor(StarConfig.LuckChance(level) * 100 + 0.5))
	end
	return tostring(level)
end

-- ===== Supernova (rebirth) =====
-- Resets your Stardust and upgrades. Every Supernova adds +50% to all Stardust you bank.
function StarConfig.Multiplier(supernovas)
	return 1 + 0.5 * supernovas
end

function StarConfig.SupernovaCost(supernovas)
	return math.floor(5000 * 3.5 ^ supernovas)
end

-- 1234567 -> "1,234,567"
function StarConfig.Commas(n)
	local s = tostring(math.floor(n))
	local sign, digits = string.match(s, "^(-?)(%d+)$")
	if not digits then
		return s
	end
	return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

return StarConfig
