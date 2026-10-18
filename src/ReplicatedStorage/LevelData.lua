-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: LevelData
-- (replaces the earlier version: adds Infinite Mode, the Endless Abyss)
-- The playable levels you pick from on a team pad. Each one is harder than the last and
-- pays more for a win. Beating a level unlocks the next one (saved per player).
--
--   Waves       how many waves you have to survive
--   HealthMult  enemy health multiplier
--   SpeedMult   enemy speed multiplier
--   BossEvery   a boss ends every Nth wave
--   StartCash   in-match cash at the start
--   WinGold     gold for every player on a win
--   WinGems     gems for every player on a win
--   Requires    the level you must have beaten to play this one (nil = always open)
--
-- Infinite levels (Infinite = true) never end: you play until your base falls, and your
-- best wave is saved and ranked on the lobby leaderboard. Instead of win rewards they pay:
--   Growth          enemy health is multiplied by this again every wave (1.06 = +6% a wave)
--   GoldPerWave     gold for every wave cleared, paid when the run ends
--   MilestoneEvery  every Nth wave cleared pays a bonus straight away...
--   MilestoneGems   ...of this many gems times the milestone number (wave 10: x1, wave 20: x2)

local LevelData = {}

LevelData.Levels = {
	{
		Id = 1, Name = "Forest Outskirts", Difficulty = "Easy", Color = Color3.fromRGB(90, 200, 110),
		Description = "Oni scouts creep out of the woods. A good place to start.",
		Waves = 10, HealthMult = 1, SpeedMult = 1, BossEvery = 5, StartCash = 500,
		WinGold = 375, WinGems = 75,
	},
	{
		Id = 2, Name = "Haunted Village", Difficulty = "Normal", Color = Color3.fromRGB(80, 160, 255),
		Description = "The village has fallen. Tougher demons, more of them.",
		Waves = 15, HealthMult = 1.6, SpeedMult = 1.1, BossEvery = 5, StartCash = 600,
		WinGold = 600, WinGems = 120, Requires = 1,
	},
	{
		Id = 3, Name = "Demon Mountain", Difficulty = "Hard", Color = Color3.fromRGB(255, 160, 50),
		Description = "Climb into the demons' stronghold. Bosses hit hard here.",
		Waves = 20, HealthMult = 2.5, SpeedMult = 1.2, BossEvery = 5, StartCash = 700,
		WinGold = 900, WinGems = 180, Requires = 2,
	},
	{
		Id = 4, Name = "Abyss Gate", Difficulty = "Nightmare", Color = Color3.fromRGB(235, 60, 80),
		Description = "The Demon King's own gate. Only the strongest teams survive.",
		Waves = 25, HealthMult = 4, SpeedMult = 1.3, BossEvery = 5, StartCash = 800,
		WinGold = 1500, WinGems = 300, Requires = 3,
	},
	{
		Id = 5, Name = "Endless Abyss", Difficulty = "Infinite", Color = Color3.fromRGB(190, 90, 255),
		Description = "The waves never stop. How far can your team get?",
		Infinite = true, Waves = 0, HealthMult = 1.2, SpeedMult = 1.1, BossEvery = 5, StartCash = 600,
		Growth = 1.06, GoldPerWave = 40, MilestoneEvery = 10, MilestoneGems = 150, Requires = 1,
	},
}

LevelData.ById = {}
for _, level in ipairs(LevelData.Levels) do
	LevelData.ById[level.Id] = level
end

function LevelData.Get(id)
	return LevelData.ById[id]
end

-- cleared: a set of beaten level ids, e.g. { [1] = true, [2] = true }
function LevelData.IsUnlocked(level, cleared)
	return level.Requires == nil or cleared[level.Requires] == true
end

-- Reads the "ClearedLevels" player attribute ("1,2") into a set
function LevelData.ParseCleared(text)
	local cleared = {}
	for id in string.gmatch(text or "", "%d+") do
		cleared[tonumber(id)] = true
	end
	return cleared
end

return LevelData
