-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: TowerScores
-- (new script: the Sky Tower leaderboard)
-- Keeps every player's furthest wave cleared in the Sky Tower this season (see TowerData) in an
-- ordered data store. Each season has its own store, so the board starts empty when a new
-- season begins. GameService saves a player's wave every time they clear one, and keeps the
-- board at the foot of the tower in the lobby up to date.
--   TowerScores.Submit(userId, wave)   saves it if it's their best this season
--   TowerScores.Top(count)             -> { { Rank, UserId, Name, Wave }, ... } this season
--   TowerScores.RunBoard(board, every) keeps a board part up to date (never returns)
-- The data store only works in a published place (and in Studio with "Enable Studio Access
-- to API Services" on); without it waves just aren't saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerData = require(ReplicatedStorage:WaitForChild("TowerData"))

local STORE_PREFIX = "TowerWaves_v1_S" -- change it to start every season's board fresh

local TowerScores = {}

local stores = {} -- [season] = the season's ordered data store (or false if unavailable)
local function storeFor(season)
	if stores[season] == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(STORE_PREFIX .. season)
		end)
		stores[season] = ok and store or false
	end
	return stores[season] or nil
end

-- Saves the wave if it beats the player's best this season
function TowerScores.Submit(userId, wave)
	local store = storeFor(TowerData.Season())
	if not store then return end
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(userId), function(old)
			if wave > (tonumber(old) or 0) then
				return wave
			end
			return nil -- keep the old best
		end)
	end)
	if not ok then
		warn("[TowerScores] couldn't save a wave:", err)
	end
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

-- This season's best `count` players, furthest wave first
function TowerScores.Top(count)
	local store = storeFor(TowerData.Season())
	if not store then return {} end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, count):GetCurrentPage()
	end)
	if not ok then
		warn("[TowerScores] couldn't read the leaderboard:", page)
		return {}
	end
	local rows = {}
	for i, entry in ipairs(page) do
		local userId = tonumber(entry.key) or 0
		table.insert(rows, { Rank = i, UserId = userId, Name = nameOf(userId), Wave = entry.value })
	end
	return rows
end

-- Fills a leaderboard board (built by LobbyBuilder: a SurfaceGui named BoardGui with frames
-- Row1, Row2, ... each holding a PlayerName and a Score label, and a Note label) and refreshes
-- it every `every` seconds. The note counts down to the end of the season. Never returns, so
-- run it in its own thread.
function TowerScores.RunBoard(board, every)
	local gui = board:WaitForChild("BoardGui")
	local rowCount = 0
	while gui:FindFirstChild("Row" .. (rowCount + 1), true) do
		rowCount += 1
	end
	local note = gui:FindFirstChild("Note", true)
	local lastRead, rows = -math.huge, {}
	while true do
		if os.clock() - lastRead >= (every or 60) then
			lastRead = os.clock()
			rows = TowerScores.Top(rowCount)
			for i = 1, rowCount do
				local row = gui:FindFirstChild("Row" .. i, true)
				local entry = rows[i]
				row:FindFirstChild("PlayerName").Text = entry and string.format("%d. %s", i, entry.Name) or string.format("%d. -", i)
				row:FindFirstChild("Score").Text = entry and ("Wave " .. entry.Wave) or ""
			end
		end
		if note then
			note.Text = storeFor(TowerData.Season()) and ("Resets in " .. TowerData.TimeText(TowerData.SecondsLeft()) .. ". Updates every minute.")
				or "Waves save in the published game."
		end
		task.wait(10)
	end
end

return TowerScores
