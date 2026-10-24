-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: AchievementData
-- (replaces the earlier version: every achievement pays Gems, Gold and / or Trait Shards when
--  it's earned (Reward), more for the harder ones)
-- Achievements are goals tracked for every player and saved (PlayerData keeps the numbers).
-- Earning one pops up on screen (AchievementUI), and the hardest ones unlock a title
-- (TitleData). Each one pays a Reward of Gems, Gold and / or Trait Shards the moment it's
-- earned. The AWARDS window lists them all with your progress and what they pay.
--
-- ADDING AN ACHIEVEMENT: add a line to AchievementData.List:
--   Id           a short name that never changes (saves remember earned achievements by it)
--   Name, Description   what the popup and the window show
--   Category     which section of the window it's in (one of AchievementData.Categories)
--   Stat, Goal   earned once the player's Stat reaches Goal. The stats:
--     Kills, BossKills       enemies / bosses you finished off
--     WavesCleared, Wins     waves survived and matches won (any map)
--     NightmareWins          matches won on Nightmare
--     MapsBeaten             different maps beaten (any difficulty)
--     NightmareMaps          different maps beaten on Nightmare
--     Summons                units summoned at the Wishing Fountain
--     Legendaries, Mythics   Legendary / Mythic units summoned (or owned)
--     TraitRolls             traits summoned in the Traits Cave
--     MythicTraits           Mythic traits rolled
--     Fuses, Evolves         times you fused / evolved a unit
--     HighestLevel, MaxStars your best unit's level / most evolution stars on one unit
--     TowerBest              furthest Sky Tower wave ever (any season)
--     ChallengeDamage        best Damage Challenge score
--   Reward       what it pays the moment it's earned: { Gems = 300, Gold = 500, Shards = 5 }
--                (any of them; Shards are Trait Shards)
--   Title        (optional) a title it unlocks too: add the same name to TitleData.Titles
--                with Rule = "Earned"

local LevelData = require(script.Parent:WaitForChild("LevelData"))

local AchievementData = {}
local MAP_COUNT = #LevelData.Maps -- (the "every map" achievements grow when maps are added)

AchievementData.Categories = { "Combat", "Campaign", "Summons", "Units", "Sky Tower" }

AchievementData.List = {
	-- Combat
	{ Id = "Kills1", Name = "First Blood", Description = "Defeat your first enemy.", Category = "Combat", Stat = "Kills", Goal = 1, Reward = { Gems = 100 } },
	{ Id = "Kills1000", Name = "Demon Hunter", Description = "Defeat 1,000 enemies.", Category = "Combat", Stat = "Kills", Goal = 1000, Reward = { Gems = 300, Shards = 5 } },
	{ Id = "Kills10000", Name = "Demon Slayer", Description = "Defeat 10,000 enemies.", Category = "Combat", Stat = "Kills", Goal = 10000, Title = "Demon Slayer", Reward = { Gems = 2000, Gold = 3000, Shards = 40 } },
	{ Id = "Boss1", Name = "Giant Killer", Description = "Defeat a boss.", Category = "Combat", Stat = "BossKills", Goal = 1, Reward = { Gems = 150, Gold = 250 } },
	{ Id = "Boss100", Name = "Boss Hunter", Description = "Defeat 100 bosses.", Category = "Combat", Stat = "BossKills", Goal = 100, Title = "Boss Hunter", Reward = { Gems = 1500, Gold = 3000, Shards = 30 } },
	{ Id = "Waves100", Name = "Holding the Line", Description = "Survive 100 waves.", Category = "Combat", Stat = "WavesCleared", Goal = 100, Reward = { Gems = 300, Gold = 500 } },
	{ Id = "Waves1000", Name = "Unbreakable", Description = "Survive 1,000 waves.", Category = "Combat", Stat = "WavesCleared", Goal = 1000, Reward = { Gems = 1500, Gold = 2500, Shards = 25 } },
	{ Id = "Challenge1M", Name = "Heavy Hitter", Description = "Deal 1,000,000 damage in one Damage Challenge.", Category = "Combat", Stat = "ChallengeDamage", Goal = 1000000, Reward = { Gems = 500, Shards = 10 } },

	-- Campaign
	{ Id = "Win1", Name = "First Victory", Description = "Win a match.", Category = "Campaign", Stat = "Wins", Goal = 1, Reward = { Gems = 200, Gold = 250 } },
	{ Id = "Win50", Name = "Veteran", Description = "Win 50 matches.", Category = "Campaign", Stat = "Wins", Goal = 50, Reward = { Gems = 1000, Gold = 2000, Shards = 15 } },
	{ Id = "AllMaps", Name = "World Traveler", Description = "Beat every map.", Category = "Campaign", Stat = "MapsBeaten", Goal = MAP_COUNT, Reward = { Gems = 1500, Gold = 3000, Shards = 25 } },
	{ Id = "Nightmare1", Name = "Nightmare Survivor", Description = "Win a match on Nightmare.", Category = "Campaign", Stat = "NightmareWins", Goal = 1, Reward = { Gems = 800, Gold = 1000, Shards = 15 } },
	{ Id = "AllNightmare", Name = "Nightmare Conqueror", Description = "Beat every map on Nightmare.", Category = "Campaign", Stat = "NightmareMaps", Goal = MAP_COUNT, Title = "Nightmare Conqueror", Reward = { Gems = 5000, Gold = 10000, Shards = 100 } },

	-- Summons
	{ Id = "Summon10", Name = "Make a Wish", Description = "Summon 10 units.", Category = "Summons", Stat = "Summons", Goal = 10, Reward = { Gems = 100 } },
	{ Id = "Summon100", Name = "Fountain Regular", Description = "Summon 100 units.", Category = "Summons", Stat = "Summons", Goal = 100, Reward = { Gems = 500, Shards = 5 } },
	{ Id = "Summon1000", Name = "Lucky Star", Description = "Summon 1,000 units.", Category = "Summons", Stat = "Summons", Goal = 1000, Title = "Lucky Star", Reward = { Gems = 3000, Shards = 50 } },
	{ Id = "Legendary1", Name = "Legend Found", Description = "Get a Legendary unit.", Category = "Summons", Stat = "Legendaries", Goal = 1, Reward = { Shards = 10 } },
	{ Id = "Mythic1", Name = "Mythic!", Description = "Get a Mythic unit.", Category = "Summons", Stat = "Mythics", Goal = 1, Reward = { Gems = 500, Shards = 25 } },
	{ Id = "Trait10", Name = "Trait Tinkerer", Description = "Summon 10 traits in the Traits Cave.", Category = "Summons", Stat = "TraitRolls", Goal = 10, Reward = { Shards = 5 } },
	{ Id = "Trait100", Name = "Trait Master", Description = "Summon 100 traits.", Category = "Summons", Stat = "TraitRolls", Goal = 100, Reward = { Gold = 1000, Shards = 25 } },
	{ Id = "MythicTrait", Name = "Against the Odds", Description = "Roll a Mythic trait.", Category = "Summons", Stat = "MythicTraits", Goal = 1, Reward = { Gems = 500, Shards = 20 } },

	-- Units
	{ Id = "Fuse1", Name = "Stronger Together", Description = "Fuse a unit.", Category = "Units", Stat = "Fuses", Goal = 1, Reward = { Gold = 250 } },
	{ Id = "Level50", Name = "Seasoned", Description = "Get a unit to level 50.", Category = "Units", Stat = "HighestLevel", Goal = 50, Reward = { Gold = 1500, Shards = 10 } },
	{ Id = "Level100", Name = "Master Fuser", Description = "Get a unit to level 100.", Category = "Units", Stat = "HighestLevel", Goal = 100, Title = "Master Fuser", Reward = { Gems = 2000, Gold = 5000, Shards = 40 } },
	{ Id = "Evolve1", Name = "Evolution", Description = "Evolve a unit.", Category = "Units", Stat = "Evolves", Goal = 1, Reward = { Gems = 200, Gold = 500 } },
	{ Id = "Stars3", Name = "Fully Evolved", Description = "Give a unit all 3 stars.", Category = "Units", Stat = "MaxStars", Goal = 3, Reward = { Gold = 2000, Shards = 20 } },

	-- Sky Tower
	{ Id = "Tower10", Name = "First Steps", Description = "Clear wave 10 in the Sky Tower.", Category = "Sky Tower", Stat = "TowerBest", Goal = 10, Reward = { Gems = 200 } },
	{ Id = "Tower25", Name = "Climbing", Description = "Clear wave 25 in the Sky Tower.", Category = "Sky Tower", Stat = "TowerBest", Goal = 25, Reward = { Gems = 500, Shards = 10 } },
	{ Id = "Tower50", Name = "Tower Climber", Description = "Clear wave 50 in the Sky Tower.", Category = "Sky Tower", Stat = "TowerBest", Goal = 50, Title = "Tower Climber", Reward = { Gems = 2000, Gold = 3000, Shards = 40 } },
	{ Id = "Tower100", Name = "Sky Legend", Description = "Clear wave 100 in the Sky Tower.", Category = "Sky Tower", Stat = "TowerBest", Goal = 100, Title = "Sky Legend", Reward = { Gems = 5000, Gold = 10000, Shards = 100 } },
}

local byId = {}
for i, a in ipairs(AchievementData.List) do
	a.Order = i
	assert(not byId[a.Id], "AchievementData: two achievements use Id " .. a.Id)
	byId[a.Id] = a
end

function AchievementData.Get(id)
	return byId[id]
end

-- "Kills=120;Wins=3" (the AchStats player attribute) -> { Kills = 120, Wins = 3 }
function AchievementData.ParseStats(text)
	local stats = {}
	for name, value in string.gmatch(text or "", "([^;=]+)=([%d%.]+)") do
		stats[name] = tonumber(value)
	end
	return stats
end

-- "Kills1,Win1" (the Achievements player attribute) -> { Kills1 = true, Win1 = true }
function AchievementData.ParseEarned(text)
	local earned = {}
	for id in string.gmatch(text or "", "[^,]+") do
		earned[id] = true
	end
	return earned
end

-- "+300 Gems  +500 Gold  +5 Shards" (what an achievement pays, or a total)
function AchievementData.RewardText(reward)
	local parts = {}
	for _, kind in ipairs({ "Gems", "Gold", "Shards" }) do
		local amount = reward and reward[kind] or 0
		if amount > 0 then
			table.insert(parts, "+" .. AchievementData.Commas(amount) .. " " .. kind)
		end
	end
	return table.concat(parts, "  ")
end

-- 1234567 -> "1,234,567"
function AchievementData.Commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

return AchievementData
