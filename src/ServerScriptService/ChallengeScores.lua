-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: ChallengeScores
-- (new script: the Damage Challenge leaderboard)
-- Keeps every player's best Damage Challenge score (the most damage they've done in one
-- challenge, see LevelData.Challenge) in an ordered data store, so the best players can be
-- listed. GameService saves the score at the end of each challenge (on the match server) and
-- keeps the leaderboard board in the lobby up to date.
--   ChallengeScores.Submit(userId, damage) -> best, isNewBest   (saves it if it's their best)
--   ChallengeScores.Top(count)             -> { { Rank, UserId, Name, Damage }, ... }
--   ChallengeScores.RunBoard(board, every) keeps a board part up to date (never returns)
-- The data store only works in a published place (and in Studio with "Enable Studio Access
-- to API Services" on); without it scores just aren't saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "ChallengeDamage_v1" -- change the name to start a fresh leaderboard

local ChallengeScores = {}

local store = nil
pcall(function()
	store = DataStoreService:GetOrderedDataStore(STORE_NAME)
end)

-- 1234567 -> "1,234,567"
function ChallengeScores.Commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Saves the score if it beats the player's best. Returns their best and whether this is it.
function ChallengeScores.Submit(userId, damage)
	damage = math.max(0, math.floor(damage))
	if not store then
		return damage, false
	end
	local best, isNew = damage, false
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(userId), function(old)
			old = tonumber(old) or 0
			if damage > old then
				best, isNew = damage, true
				return damage
			end
			best, isNew = old, false
			return nil -- keep the old best
		end)
	end)
	if not ok then
		warn("[ChallengeScores] couldn't save a score:", err)
	end
	return best, isNew
end

-- Names by UserId, looked up once each
local names = {}
local function nameOf(userId)
	if names[userId] then return names[userId] end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

-- The best `count` scores, best first
function ChallengeScores.Top(count)
	if not store then return {} end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, count):GetCurrentPage()
	end)
	if not ok then
		warn("[ChallengeScores] couldn't read the leaderboard:", page)
		return {}
	end
	local rows = {}
	for i, entry in ipairs(page) do
		local userId = tonumber(entry.key) or 0
		table.insert(rows, { Rank = i, UserId = userId, Name = nameOf(userId), Damage = entry.value })
	end
	return rows
end

-- Fills a leaderboard board (built by LobbyBuilder: a SurfaceGui named BoardGui with frames
-- Row1, Row2, ... each holding a PlayerName and a Score label, and a Note label) and refreshes it
-- every `every` seconds. Never returns, so run it in its own thread.
function ChallengeScores.RunBoard(board, every)
	local gui = board:WaitForChild("BoardGui")
	local rowCount = 0
	while gui:FindFirstChild("Row" .. (rowCount + 1), true) do
		rowCount += 1
	end
	local note = gui:FindFirstChild("Note", true)
	while true do
		local rows = ChallengeScores.Top(rowCount)
		for i = 1, rowCount do
			local row = gui:FindFirstChild("Row" .. i, true)
			local entry = rows[i]
			row:FindFirstChild("PlayerName").Text = entry and string.format("%d. %s", i, entry.Name) or string.format("%d. -", i)
			row:FindFirstChild("Score").Text = entry and ChallengeScores.Commas(entry.Damage) or ""
		end
		if note then
			note.Text = store and "Best damage in one challenge. Updates every minute."
				or "Scores save in the published game."
		end
		task.wait(every or 60)
	end
end

return ChallengeScores
