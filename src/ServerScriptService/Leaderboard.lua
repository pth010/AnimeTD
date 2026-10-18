-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: Leaderboard
-- The Infinite Mode leaderboard: every player's best wave, ranked across every server.
--   * GameService calls Leaderboard.Submit(player, wave) when an Infinite run ends
--   * a big board in the lobby (front-right, across from the fountain) shows the top 10
--     and refreshes every minute
-- Like saving, this needs a published place (and Studio API access to test in Studio).
-- Without it the board still shows up, it just says the leaderboard is offline.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME = "AnimeTD_InfiniteBest_v1" -- bump the version to wipe the leaderboard
local TOP_COUNT = 10
local REFRESH_INTERVAL = 60
local BOARD_POSITION = Vector3.new(85, 0, 60) -- mirrors the Wishing Fountain
local ACCENT = Color3.fromRGB(190, 90, 255)
local RANK_COLORS = {
	Color3.fromRGB(255, 205, 70),  -- 1st: gold
	Color3.fromRGB(215, 220, 235), -- 2nd: silver
	Color3.fromRGB(225, 145, 85),  -- 3rd: bronze
}

local storeOk, store = pcall(function()
	return DataStoreService:GetOrderedDataStore(STORE_NAME)
end)
if not storeOk then
	warn("[Leaderboard] OrderedDataStore unavailable (publish the place to enable it).")
	store = nil
end

local Leaderboard = {}

-- ===== The board =====
local rows = {}
local footer

local function buildBoard()
	local lobby = workspace:WaitForChild("Lobby")
	local spawn = lobby:WaitForChild("LobbySpawn")

	local folder = Instance.new("Folder")
	folder.Name = "Leaderboard"

	-- face the spawn, like the summon sign does
	local toSpawn = Vector3.new(spawn.Position.X - BOARD_POSITION.X, 0, spawn.Position.Z - BOARD_POSITION.Z).Unit
	local base = CFrame.lookAt(BOARD_POSITION, BOARD_POSITION - toSpawn)

	local boardY, boardSize = 15, Vector3.new(30, 24, 1)
	local postHeight = boardY - boardSize.Y / 2
	for _, dx in ipairs({ -12, 12 }) do
		local post = Instance.new("Part")
		post.Name = "BoardPost"
		post.Anchored = true
		post.Size = Vector3.new(1.4, postHeight, 1.4)
		post.Color = Color3.fromRGB(60, 60, 80)
		post.CFrame = base * CFrame.new(dx, postHeight / 2, 0)
		post.Parent = folder
	end

	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.Size = boardSize
	board.Color = Color3.fromRGB(28, 28, 44)
	board.CFrame = base * CFrame.new(0, boardY, 0)
	board.Parent = folder

	local glow = Instance.new("PointLight")
	glow.Color = ACCENT
	glow.Range = 24
	glow.Brightness = 1
	glow.Parent = board

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(600, 480) -- same shape as the 30 x 24 board
	gui.LightInfluence = 0
	gui.Parent = board

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 70)
	header.BackgroundColor3 = ACCENT
	header.BorderSizePixel = 0
	header.Text = "ENDLESS ABYSS - TOP " .. TOP_COUNT
	header.TextColor3 = Color3.new(1, 1, 1)
	header.TextStrokeTransparency = 0.4
	header.Font = Enum.Font.GothamBlack
	header.TextSize = 38
	header.Parent = gui

	for i = 1, TOP_COUNT do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(16, 80 + (i - 1) * 36)
		row.Size = UDim2.new(1, -32, 0, 32)
		row.BackgroundColor3 = i % 2 == 1 and Color3.fromRGB(38, 36, 60) or Color3.fromRGB(32, 30, 50)
		row.BorderSizePixel = 0
		row.Parent = gui

		local function cell(x, width, align, color)
			local l = Instance.new("TextLabel")
			l.Position = UDim2.fromOffset(x, 0)
			l.Size = UDim2.new(0, width, 1, 0)
			l.BackgroundTransparency = 1
			l.TextColor3 = color
			l.Font = Enum.Font.GothamBlack
			l.TextSize = 24
			l.TextXAlignment = align
			l.TextTruncate = Enum.TextTruncate.AtEnd
			l.Text = ""
			l.Parent = row
			return l
		end
		local color = RANK_COLORS[i] or Color3.new(1, 1, 1)
		cell(8, 50, Enum.TextXAlignment.Left, color).Text = "#" .. i
		rows[i] = {
			Name = cell(64, 340, Enum.TextXAlignment.Left, color),
			Wave = cell(404, 160, Enum.TextXAlignment.Right, color),
		}
	end

	footer = Instance.new("TextLabel")
	footer.Position = UDim2.new(0, 0, 1, -36)
	footer.Size = UDim2.new(1, 0, 0, 30)
	footer.BackgroundTransparency = 1
	footer.TextColor3 = Color3.fromRGB(185, 180, 215)
	footer.Font = Enum.Font.GothamBold
	footer.TextSize = 18
	footer.Text = "Loading..."
	footer.Parent = gui

	folder.Parent = lobby
end

-- ===== Names =====
local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then return nameCache[userId] end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	return "Player " .. userId
end

-- ===== Reading and writing =====
function Leaderboard.Refresh()
	if not footer then return end
	if not store then
		footer.Text = "Leaderboard offline (publish the place to turn it on)"
		return
	end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok then
		warn("[Leaderboard] couldn't read the top " .. TOP_COUNT .. ":", pages)
		footer.Text = "Couldn't load the leaderboard. Retrying soon..."
		return
	end

	local entries = pages:GetCurrentPage()
	for i = 1, TOP_COUNT do
		local entry = entries[i]
		if entry then
			rows[i].Name.Text = nameOf(tonumber(entry.key))
			rows[i].Wave.Text = "Wave " .. entry.value
		else
			rows[i].Name.Text = "---"
			rows[i].Wave.Text = ""
		end
	end
	footer.Text = #entries == 0 and "No runs yet. Be the first!" or "Play the Endless Abyss to get on the board"
end

-- Saves a run's wave if it beats the player's ranked best
function Leaderboard.Submit(player, wave)
	if not store or wave <= 0 then return end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(player.UserId), function(old)
				if tonumber(old) and old >= wave then
					return nil -- keep the old best
				end
				return wave
			end)
		end)
		if ok then
			Leaderboard.Refresh()
		else
			warn("[Leaderboard] couldn't save " .. player.Name .. "'s wave:", err)
		end
	end)
end

task.spawn(function()
	buildBoard()
	while true do
		Leaderboard.Refresh()
		task.wait(REFRESH_INTERVAL)
	end
end)

return Leaderboard
