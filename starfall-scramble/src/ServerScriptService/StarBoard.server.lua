-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: StarBoard
-- Fills in the "Brightest Star Catchers" board on the island: the top 10 players by lifetime
-- Stardust across every server. Players in this server are mixed in live, so the board also
-- works in Studio before the place is published (it then shows just this server).

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarConfig = require(ReplicatedStorage:WaitForChild("StarConfig"))
local StarData = require(ServerScriptService:WaitForChild("StarData"))

local REFRESH_EVERY = 60 -- seconds; OrderedDataStore reads are rate limited

local island = workspace:WaitForChild("StarfallIsland")
local board = island:WaitForChild("LeaderBoard", 30)
if not board then
	warn("[StarBoard] no LeaderBoard part on the island, so there's no board to fill in.")
	return
end
local rows = board:WaitForChild("BoardGui"):WaitForChild("Rows")

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	return "Player " .. userId
end

local saved = {} -- [userId] = lifetime Stardust, from the last read of the global board

local function readGlobal()
	local store = StarData.Board
	if not store then return end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		warn("[StarBoard] couldn't read the leaderboard:", page)
		return
	end
	table.clear(saved)
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		if userId then
			saved[userId] = entry.value
		end
	end
end

local function render()
	local best = table.clone(saved)
	for player, profile in pairs(StarData.Profiles) do
		if (best[player.UserId] or 0) < profile.Total then
			best[player.UserId] = profile.Total
		end
	end

	local list = {}
	for userId, total in pairs(best) do
		if total > 0 then
			table.insert(list, { UserId = userId, Total = total })
		end
	end
	table.sort(list, function(a, b) return a.Total > b.Total end)

	for i = 1, 10 do
		local row = rows:FindFirstChild("Row" .. i)
		if row then
			local entry = list[i]
			row.Who.Text = entry and string.format("%d. %s", i, nameOf(entry.UserId)) or (i == 1 and "Be the first!" or "")
			row.Amount.Text = entry and StarConfig.Commas(entry.Total) or ""
		end
	end
end

task.spawn(function()
	local lastRead = -math.huge
	while true do
		if os.clock() - lastRead >= REFRESH_EVERY then
			lastRead = os.clock()
			readGlobal()
		end
		render() -- local players update every few seconds
		task.wait(5)
	end
end)
