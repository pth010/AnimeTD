-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: LevelData
-- (replaces the earlier version: the Damage Challenge is fought in a cavern (Cave theme,
--  GolemDen layout) against a huge Ancient Golem that stands still)
-- What you can play from a team pad. A MAP is a place to fight (its name, story and color);
-- a DIFFICULTY sets how many waves there are, how tough the enemies are and what a win pays.
-- Every map is played on one of its difficulties: the first one is open (unless the map has
-- UnlockedBy), and each harder difficulty unlocks once you've beaten the one before it.
--
-- ===== ADDING A MAP =====
-- Copy one of the blocks in LevelData.Maps below and change it:
--   Id           a new whole number, never used before. Saves remember beaten difficulties by
--                it, so never change or reuse a map's Id once players have played it.
--   Name, Description, Color   what the level select shows
--   Theme        how the arena looks on this map: a theme from ArenaThemes ("Forest",
--                "Haunted", "Volcano", "Abyss", "Winter", "BloodMoon", "Shadow" or your own)
--   Layout       the route and the land: a layout from ArenaLayouts ("Classic", "Crossroads",
--                "Switchback", "Islands", "Ridge", "Temple", "Fortress" or your own)
--   HealthMult   enemy health on this map, on top of the difficulty's (1.25 = 25% tougher)
--   SpeedMult    enemy speed on this map, on top of the difficulty's
--   RewardMult   win rewards on this map, on top of the difficulty's (1.2 = 20% more)
--   Difficulties (optional) which difficulties this map has, in order, e.g.
--                Difficulties = { "Hard", "Nightmare" }. Leave it out for all of them.
--   Overrides    (optional) change one difficulty's numbers on this map only, e.g.
--                Overrides = { Nightmare = { Waves = 30, WinShards = 12 } }
--   UnlockedBy   (optional) the level Id to beat before this map opens, e.g. 303 (Demon
--                Mountain on Hard, see the Ids at the bottom of this list). Leave it out to
--                have the map open from the start.
-- The new map shows up in the level select on its own.
--
-- ===== DIFFICULTIES =====
-- Shared by every map (add one here and every map without a Difficulties list gets it):
--   Waves       how many waves you have to survive
--   HealthMult  enemy health multiplier
--   SpeedMult   enemy speed multiplier
--   BossEvery   a boss ends every Nth wave
--   StartCash   in-match cash at the start
--   WinGold, WinGems, WinShards   rewards for every player on a win (times the map's RewardMult;
--               Trait Shards are spent in the Traits Cave)
--
-- Each map + difficulty is one level with its own Id: the map's Id * 100 + the difficulty's
-- place in that map's list (Forest Outskirts on Hard = 103). PlaceConfig.StudioTestLevel takes
-- one of these; the old level ids 1-4 still work too.

local LevelData = {}

local rgb = Color3.fromRGB

LevelData.Difficulties = {
	{ Name = "Easy",      Color = rgb(90, 200, 110), Waves = 10, HealthMult = 1,   SpeedMult = 1,   BossEvery = 5, StartCash = 1000,
		WinGold = 375, WinGems = 75, WinShards = 2 },
	{ Name = "Normal",    Color = rgb(80, 160, 255), Waves = 15, HealthMult = 1.6, SpeedMult = 1.1, BossEvery = 5, StartCash = 1000,
		WinGold = 600, WinGems = 120, WinShards = 3 },
	{ Name = "Hard",      Color = rgb(255, 160, 50), Waves = 20, HealthMult = 2.5, SpeedMult = 1.2, BossEvery = 5, StartCash = 1000,
		WinGold = 900, WinGems = 180, WinShards = 5 },
	{ Name = "Nightmare", Color = rgb(235, 60, 80),  Waves = 25, HealthMult = 4,   SpeedMult = 1.3, BossEvery = 5, StartCash = 1000,
		WinGold = 1500, WinGems = 300, WinShards = 8 },
}

LevelData.Maps = {
	{
		Id = 1, Name = "Forest Outskirts", Color = rgb(70, 170, 90), Theme = "Forest", Layout = "Classic",
		Description = "Oni scouts creep out of the woods. A good place to start.",
		HealthMult = 1, SpeedMult = 1, RewardMult = 1,
	},
	{
		Id = 2, Name = "Haunted Village", Color = rgb(150, 120, 220), Theme = "Haunted", Layout = "Crossroads",
		Description = "The village has fallen. Tougher demons, more of them.",
		HealthMult = 1.25, SpeedMult = 1, RewardMult = 1.2,
	},
	{
		Id = 3, Name = "Demon Mountain", Color = rgb(255, 140, 60), Theme = "Volcano", Layout = "Switchback",
		Description = "Climb into the demons' stronghold. Bosses hit hard here.",
		HealthMult = 1.5, SpeedMult = 1.05, RewardMult = 1.4,
	},
	{
		Id = 4, Name = "Abyss Gate", Color = rgb(200, 40, 90), Theme = "Abyss", Layout = "Islands",
		Description = "The Demon King's own gate. Only the strongest teams survive.",
		HealthMult = 1.8, SpeedMult = 1.1, RewardMult = 1.7,
	},

	-- ===== Late-game maps: Hard and Nightmare only =====
	{
		Id = 5, Name = "Frozen Peak", Color = rgb(120, 200, 255), Theme = "Winter", Layout = "Ridge",
		Description = "A blizzard rages on the summit. The cold makes the demons relentless.",
		HealthMult = 2, SpeedMult = 1.1, RewardMult = 2,
		Difficulties = { "Hard", "Nightmare" },
		UnlockedBy = 303, -- Demon Mountain on Hard
	},
	{
		Id = 6, Name = "Blood Moon Shrine", Color = rgb(230, 70, 40), Theme = "BloodMoon", Layout = "Temple",
		Description = "Under the red moon the shrine's guardians have turned. Bosses come in force.",
		HealthMult = 2.3, SpeedMult = 1.15, RewardMult = 2.4,
		Difficulties = { "Hard", "Nightmare" },
		Overrides = { Hard = { BossEvery = 4 }, Nightmare = { BossEvery = 4 } },
		UnlockedBy = 403, -- Abyss Gate on Hard
	},
	{
		Id = 7, Name = "Shadow Citadel", Color = rgb(110, 90, 190), Theme = "Shadow", Layout = "Fortress",
		Description = "The Demon King's fortress. The longest, toughest fight in the game.",
		HealthMult = 2.7, SpeedMult = 1.2, RewardMult = 2.9,
		Difficulties = { "Hard", "Nightmare" },
		Overrides = { Nightmare = { Waves = 30 } },
		UnlockedBy = 502, -- Frozen Peak on Nightmare
	},
}
-- Level Ids (map Id * 100 + difficulty number): Forest Outskirts 101-104, Haunted Village
-- 201-204, Demon Mountain 301-304, Abyss Gate 401-404, Frozen Peak 501 (Hard) and 502
-- (Nightmare), Blood Moon Shrine 601-602, Shadow Citadel 701-702.

-- Before maps existed there were four levels, ids 1-4. Each one is now this map + difficulty,
-- so anything a player beat back then still counts.
local LEGACY_IDS = { [1] = 101, [2] = 202, [3] = 303, [4] = 404 }
local legacyOf = {}
for old, new in pairs(LEGACY_IDS) do
	legacyOf[new] = old
end

local function round(n, step)
	return math.floor(n / step + 0.5) * step
end

-- ===== Every map + difficulty as one level =====
-- Each level has: Id, MapId, Name (the map's), Description, MapColor, Theme, Layout, Difficulty (its name),
-- DifficultyIndex, Color (the difficulty's), FullName ("Abyss Gate (Hard)"), Waves, HealthMult,
-- SpeedMult, BossEvery, StartCash, WinGold, WinGems, WinShards, and Requires (the Id of the
-- difficulty before it on the same map, or the map's UnlockedBy for its first difficulty).
LevelData.Levels = {}   -- every level, map by map
LevelData.ById = {}
LevelData.MapById = {}  -- each map also gets map.Levels: its levels, easiest first

local difficultyByName = {}
for _, d in ipairs(LevelData.Difficulties) do
	difficultyByName[d.Name] = d
end

for _, map in ipairs(LevelData.Maps) do
	assert(type(map.Id) == "number" and map.Id >= 1 and map.Id == math.floor(map.Id),
		"LevelData: map " .. tostring(map.Name) .. " needs a whole-number Id of 1 or more")
	assert(not LevelData.MapById[map.Id], "LevelData: two maps use Id " .. map.Id)
	LevelData.MapById[map.Id] = map
	map.Levels = {}

	local names = map.Difficulties
	if not names then
		names = {}
		for _, d in ipairs(LevelData.Difficulties) do
			table.insert(names, d.Name)
		end
	end

	local reward = map.RewardMult or 1
	local previous = nil
	for index, name in ipairs(names) do
		local d = difficultyByName[name]
		assert(d, "LevelData: map " .. tostring(map.Name) .. " lists an unknown difficulty: " .. tostring(name))
		local level = {
			Id = map.Id * 100 + index,
			MapId = map.Id,
			Name = map.Name,
			Description = map.Description,
			MapColor = map.Color,
			Theme = map.Theme or "Forest",
			Layout = map.Layout or "Classic",
			Difficulty = d.Name,
			DifficultyIndex = index,
			Color = d.Color,
			FullName = map.Name .. " (" .. d.Name .. ")",
			Waves = d.Waves,
			HealthMult = d.HealthMult * (map.HealthMult or 1),
			SpeedMult = d.SpeedMult * (map.SpeedMult or 1),
			BossEvery = d.BossEvery,
			StartCash = d.StartCash,
			WinGold = round(d.WinGold * reward, 5),
			WinGems = round(d.WinGems * reward, 5),
			WinShards = round(d.WinShards * reward, 1),
			Requires = previous and previous.Id or map.UnlockedBy,
		}
		local override = map.Overrides and map.Overrides[d.Name]
		if override then
			for key, value in pairs(override) do
				level[key] = value
			end
		end
		table.insert(map.Levels, level)
		table.insert(LevelData.Levels, level)
		LevelData.ById[level.Id] = level
		previous = level
	end
end

-- ===== DAMAGE CHALLENGE =====
-- A solo mode, started from the Challenge pad in the lobby (not from the level select). You
-- get SetupTime seconds and unlimited cash to place your units, then a huge golem wakes up in
-- the middle of its cavern and you have FightTime seconds to hit it. It can't die and doesn't
-- move: your score is all the damage you deal it. The best
-- scores go on the leaderboard in the lobby (see ChallengeScores). No rewards: it's for glory.
-- Change the numbers here freely; Theme / Layout work like a map's.
LevelData.Challenge = {
	Id = 9001, Challenge = true,
	Name = "Damage Challenge", Difficulty = "Solo", FullName = "Damage Challenge",
	Description = "One boss, one minute. How much damage can you do?",
	MapColor = rgb(235, 60, 80), Color = rgb(235, 60, 80),
	Theme = "Cave", Layout = "GolemDen", -- a cavern, with the golem in the middle
	BossType = "Golem", -- the Ancient Golem (an enemy type in GameService)
	Stationary = true,  -- it stands still (false: it walks the path slowly)
	SetupTime = 30,   -- seconds to place units before the boss comes
	FightTime = 60,   -- seconds to deal damage
	StartCash = 999999999, -- "unlimited" (it's topped up during the challenge too)
	Waves = 1, BossEvery = 1, HealthMult = 1, SpeedMult = 1,
	WinGold = 0, WinGems = 0, WinShards = 0,
}
LevelData.ById[LevelData.Challenge.Id] = LevelData.Challenge

-- A level by its Id (the old ids 1-4 work too)
function LevelData.Get(id)
	return LevelData.ById[id] or LevelData.ById[LEGACY_IDS[id]]
end

function LevelData.GetMap(id)
	return LevelData.MapById[id]
end

-- cleared: a set of beaten level ids, e.g. { [101] = true, [102] = true }
function LevelData.IsCleared(cleared, id)
	return cleared[id] == true or (legacyOf[id] ~= nil and cleared[legacyOf[id]] == true)
end

-- A map's first difficulty is open (or needs its UnlockedBy beaten); a harder one needs the
-- one before it beaten. Anything already beaten stays open.
function LevelData.IsUnlocked(level, cleared)
	return level.Requires == nil or LevelData.IsCleared(cleared, level.Requires)
		or LevelData.IsCleared(cleared, level.Id)
end

-- Can the map be played at all? (its first difficulty is open)
function LevelData.IsMapUnlocked(map, cleared)
	return map.Levels[1] ~= nil and LevelData.IsUnlocked(map.Levels[1], cleared)
end

-- Reads the "ClearedLevels" player attribute ("101,102") into a set
function LevelData.ParseCleared(text)
	local cleared = {}
	for id in string.gmatch(text or "", "%d+") do
		cleared[tonumber(id)] = true
	end
	return cleared
end

return LevelData
