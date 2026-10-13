-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: MatchTeleport
-- (replaces the earlier version: new script. Moves teams between the lobby and their own
--  private match server, used by GameService.)
--
-- Lobby -> match:
--   1. everyone's data is saved and let go of (PlayerData.Release), so the match server
--      loads the newest copy
--   2. a brand-new private server of the match place is reserved for the team
--   3. which level to play and who is on the team are written to MemoryStore under that
--      server's id. Only servers can read MemoryStore, so a cheater can't change the level
--   4. the whole team is teleported there together
-- Match -> lobby: save and let go of the data again, then teleport to a lobby server.
-- If a teleport fails it's retried; if it keeps failing the player stays where they are
-- (in the lobby) or is kicked with a message (from a match that's already over).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local PlaceConfig = require(ReplicatedStorage:WaitForChild("PlaceConfig"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local MATCH_INFO_TIME = 2 * 60 * 60 -- how long the match info is kept (seconds)
local TELEPORT_RETRIES = 2          -- extra tries when a teleport fails on the way
local ERROR_SHOW_TIME = 5           -- seconds an error message stays on screen

local matchInfo = MemoryStoreService:GetHashMap("AnimeTD_Matches")

local MatchTeleport = {}

-- [player] = { Tries, OnGiveUp } for teleports that are on their way
local pending = {}

-- Runs fn up to `tries` times until it doesn't error
local function retry(tries, what, fn, ...)
	for i = 1, tries do
		local ok, a, b = pcall(fn, ...)
		if ok then
			return true, a, b
		end
		warn("[MatchTeleport] " .. what .. " failed:", a)
		if i < tries then
			task.wait(i)
		end
	end
	return false
end

-- What the player sees (TeleportUI shows these). nil hides the "Teleporting" screen.
local function setStatus(player, text)
	if player.Parent then
		player:SetAttribute("TeleportStatus", text)
	end
end

local function showError(player, text)
	if not player.Parent then return end
	player:SetAttribute("TeleportStatus", nil)
	player:SetAttribute("TeleportError", text)
	task.delay(ERROR_SHOW_TIME, function()
		if player.Parent and player:GetAttribute("TeleportError") == text then
			player:SetAttribute("TeleportError", nil)
		end
	end)
end

-- Only the players still in this server
local function present(list)
	local out = {}
	for _, p in ipairs(list) do
		if p.Parent == Players then
			table.insert(out, p)
		end
	end
	return out
end

-- Saves each player and lets go of their data (all at once, waits for all of them)
local function releaseAll(list)
	local left = #list
	for _, p in ipairs(list) do
		task.spawn(function()
			PlayerData.Release(p)
			left -= 1
		end)
	end
	local startTime = os.clock()
	while left > 0 and os.clock() - startTime < 30 do
		task.wait()
	end
end

-- Teleport didn't happen: the players stay in the lobby and keep their data here
local function cancel(list, message)
	for _, p in ipairs(list) do
		pending[p] = nil
		PlayerData.Reclaim(p)
		if p.Parent then
			p:SetAttribute("Teleporting", nil)
		end
		showError(p, message)
	end
end

-- ===== LOBBY -> MATCH =====
-- Sends a team to a new match server to play levelId. Yields until the teleport has started.
-- Returns true, or false and an error message (everyone then stays in the lobby).
function MatchTeleport.SendToMatch(players, levelId)
	local team = present(players)
	if #team == 0 then
		return false, "Nobody left to teleport."
	end
	for _, p in ipairs(team) do
		p:SetAttribute("Teleporting", true) -- no summoning or inventory changes from here on
		setStatus(p, "Saving your data...")
	end
	releaseAll(team)

	team = present(team)
	if #team == 0 then
		return false, "Nobody left to teleport."
	end
	for _, p in ipairs(team) do
		setStatus(p, "Finding a match server...")
	end

	local ok, accessCode, serverId = retry(3, "ReserveServer", TeleportService.ReserveServer, TeleportService,
		PlaceConfig.MatchPlaceId)
	if not ok then
		cancel(team, "Couldn't reach a match server. Try again!")
		return false, "ReserveServer failed"
	end

	local userIds = {}
	for _, p in ipairs(team) do
		table.insert(userIds, p.UserId)
	end
	ok = retry(3, "Saving match info", function()
		matchInfo:SetAsync(serverId, { LevelId = levelId, Players = userIds, Lobby = game.PlaceId }, MATCH_INFO_TIME)
	end)
	if not ok then
		cancel(team, "Couldn't start the match. Try again!")
		return false, "MemoryStore failed"
	end

	team = present(team)
	if #team == 0 then
		return false, "Nobody left to teleport."
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	for _, p in ipairs(team) do
		setStatus(p, "Teleporting to the match...")
		pending[p] = {
			Tries = 0,
			OnGiveUp = function()
				cancel({ p }, "The teleport failed. Try again!")
			end,
		}
	end

	ok = retry(2, "TeleportAsync", TeleportService.TeleportAsync, TeleportService, PlaceConfig.MatchPlaceId, team, options)
	if not ok then
		cancel(team, "The teleport failed. Try again!")
		return false, "TeleportAsync failed"
	end
	return true
end

-- ===== MATCH SERVER =====
-- What the lobby sent along: { LevelId, Players = { userIds }, Lobby = placeId },
-- or nil if this isn't a reserved match server (or MemoryStore can't be reached).
function MatchTeleport.ReadMatchInfo()
	if game.PrivateServerId == "" then
		return nil
	end
	local ok, info = retry(5, "Reading match info", function()
		return matchInfo:GetAsync(game.PrivateServerId)
	end)
	if ok and type(info) == "table" then
		return info
	end
	return nil
end

-- ===== MATCH -> LOBBY =====
-- Saves and sends these players to a lobby server. Yields until the teleport has started.
-- In Studio (no teleports) they are kicked with a message instead, which ends the test.
function MatchTeleport.ToLobby(players, lobbyPlaceId)
	local list = {}
	for _, p in ipairs(present(players)) do
		if not pending[p] and not p:GetAttribute("Teleporting") then -- not already on their way
			table.insert(list, p)
		end
	end
	if #list == 0 then return end

	lobbyPlaceId = tonumber(lobbyPlaceId) or PlaceConfig.LobbyPlaceId
	for _, p in ipairs(list) do
		p:SetAttribute("Teleporting", true)
		setStatus(p, "Returning to the lobby...")
	end
	releaseAll(list)

	list = present(list)
	if RunService:IsStudio() or lobbyPlaceId == 0 then
		for _, p in ipairs(list) do
			p:Kick(RunService:IsStudio()
				and "Match over! In the live game you'd go back to the lobby now (teleports don't work in Studio)."
				or "Match over! Rejoin the game to go back to the lobby (PlaceConfig.LobbyPlaceId isn't set).")
		end
		return
	end

	for _, p in ipairs(list) do
		pending[p] = {
			Tries = 0,
			OnGiveUp = function()
				if p.Parent then
					p:Kick("Match over! Rejoin the game to go back to the lobby.")
				end
			end,
		}
	end
	local ok = retry(2, "TeleportAsync", TeleportService.TeleportAsync, TeleportService, lobbyPlaceId, list)
	if not ok then
		for _, p in ipairs(list) do
			local entry = pending[p]
			pending[p] = nil
			if entry then entry.OnGiveUp() end
		end
	end
end

-- A teleport that started can still fail on the way (full server, Roblox hiccup): retry it
-- a couple of times, then give up
TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
	local entry = pending[player]
	if not entry then return end
	warn("[MatchTeleport] teleport failed for " .. player.Name .. ":", result, message)
	if entry.Tries < TELEPORT_RETRIES then
		entry.Tries += 1
		task.wait(2)
		local ok = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player }, options)
		if ok then return end
	end
	pending[player] = nil
	entry.OnGiveUp()
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
end)

return MatchTeleport
