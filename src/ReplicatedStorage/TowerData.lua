-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: TowerData
-- (replaces the earlier version: the 100 and 250 shard rewards repeat every 50th and every
--  100th wave, instead of only at waves 50 and 100)
-- The Sky Tower (the pad on the tower's main deck in the lobby) is an endless wave mode: the
-- waves never stop, they just get harder, until your base falls. How far you get pays Trait
-- Shards, and the furthest waves go on the leaderboard at the foot of the tower.
--
-- SEASONS: the leaderboard and the rewards run in seasons of SeasonLength seconds (2 days).
-- When a season ends the leaderboard starts empty again and everyone can earn every reward
-- again.
--
-- REWARDS: each milestone pays once per season, the first time you clear that wave. They add
-- up: clearing wave 27 pays waves 10 and 20 (10 + 10) and wave 25 (25) = 45 shards. Clearing
-- wave 30 later in the same season only pays what's new: wave 30 (10). Clearing wave 50 pays
-- 10 + 25 + 100, and wave 100 pays 10 + 25 + 100 + 250.
--   { Every = 10, Shards = 10 }   every 10th wave (10, 20, 30, ...)
--   { At = 75, Shards = 50 }      only that wave (for a one-off reward)
-- Change or add lines in TowerData.Milestones freely.
-- (A wave counts once you've cleared it: every enemy in it is gone and your base still stands.)

local TowerData = {}

TowerData.SeasonLength = 2 * 24 * 60 * 60 -- 2 days
TowerData.SeasonStart = 1767225600        -- seasons are counted from 1 Jan 2026, 00:00 UTC

TowerData.Milestones = {
	{ Every = 10, Shards = 10 },
	{ Every = 25, Shards = 25 },
	{ Every = 50, Shards = 100 },
	{ Every = 100, Shards = 250 },
}

-- The season number at `now` (os.time() if left out). Every server agrees on it.
function TowerData.Season(now)
	return math.floor(((now or os.time()) - TowerData.SeasonStart) / TowerData.SeasonLength)
end

-- Seconds until the current season ends
function TowerData.SecondsLeft(now)
	now = now or os.time()
	local season = TowerData.Season(now)
	return TowerData.SeasonStart + (season + 1) * TowerData.SeasonLength - now
end

-- "1d 05h" / "3h 20m" / "12m"
function TowerData.TimeText(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d = math.floor(seconds / 86400)
	local h = math.floor(seconds % 86400 / 3600)
	local m = math.floor(seconds % 3600 / 60)
	if d > 0 then return string.format("%dd %02dh", d, h) end
	if h > 0 then return string.format("%dh %02dm", h, m) end
	return string.format("%dm", math.max(1, m))
end

-- Shards for clearing exactly `wave` (all its milestones added up)
function TowerData.RewardFor(wave)
	local shards = 0
	for _, m in ipairs(TowerData.Milestones) do
		if (m.Every and wave % m.Every == 0) or (m.At and wave == m.At) then
			shards += m.Shards
		end
	end
	return shards
end

-- Shards for going from a best of `from` to a best of `to` (the waves in between, `to` included)
function TowerData.RewardsBetween(from, to)
	local shards = 0
	for wave = from + 1, to do
		shards += TowerData.RewardFor(wave)
	end
	return shards
end

-- The next wave above `best` that pays something, and what it pays
function TowerData.NextReward(best)
	for wave = best + 1, best + 1000 do
		local shards = TowerData.RewardFor(wave)
		if shards > 0 then return wave, shards end
	end
	return nil, 0
end

return TowerData
