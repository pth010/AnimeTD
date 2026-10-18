-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: StarData
-- Each player's saved progress: Stardust, upgrades, Supernovas and lifetime Stardust.
-- Stars in your bag (Carried) are NOT saved: bank them at the Star Well or lose them.
--
-- Saving needs a published place (File > Publish to Roblox). To test saving in Studio, also
-- turn on Game Settings > Security > "Enable Studio Access to API Services".
-- If loading fails the player can still play, but that session will NOT save, so an outage
-- can never overwrite real progress with a blank profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local StarConfig = require(ReplicatedStorage:WaitForChild("StarConfig"))

local STORE_NAME = "StarfallScramble_v1"            -- bump the version to wipe everyone's data
local BOARD_NAME = "StarfallScramble_Lifetime_v1"   -- the all-time leaderboard
local AUTOSAVE_INTERVAL = 120
local SAVE_DELAY = 6 -- seconds after a change before it's written

-- These throw if the place isn't published. Fall back to "no saving" so the game still runs.
local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	warn("[StarData] DataStore unavailable (publish the place to enable saving). Running without saving.")
	store = nil
end
local boardOk, board = pcall(function()
	return DataStoreService:GetOrderedDataStore(BOARD_NAME)
end)
if not boardOk then
	board = nil
end

local StarData = {}
StarData.Profiles = {}
StarData.Board = board -- read by StarBoard (nil when saving is off)

-- Fires (player) once a profile is ready
StarData.Loaded = Instance.new("BindableEvent")

local function blankUpgrades()
	local t = {}
	for _, def in ipairs(StarConfig.Upgrades) do
		t[def.Id] = 0
	end
	return t
end

function StarData.Get(player)
	return StarData.Profiles[player]
end

function StarData.Capacity(profile)
	return StarConfig.Capacity(profile.Upgrades.Bag)
end

-- Mirrors the profile onto player attributes (read by the HUD) and the player list
function StarData.Sync(player)
	local profile = StarData.Profiles[player]
	if not profile then return end

	player:SetAttribute("Stardust", profile.Stardust)
	player:SetAttribute("Carried", profile.Carried)
	player:SetAttribute("Capacity", StarData.Capacity(profile))
	player:SetAttribute("Supernovas", profile.Supernovas)
	player:SetAttribute("Lifetime", profile.Total)
	for id, level in pairs(profile.Upgrades) do
		player:SetAttribute("Up_" .. id, level)
	end

	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local dust = Instance.new("IntValue")
		dust.Name = "Stardust"
		dust.Parent = stats
		local novas = Instance.new("IntValue")
		novas.Name = "Supernovas"
		novas.Parent = stats
		stats.Parent = player
	end
	stats.Stardust.Value = profile.Stardust
	stats.Supernovas.Value = profile.Supernovas

	-- Moon Boots
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = StarConfig.Speed(profile.Upgrades.Speed)
	end
end

local function loadFromStore(userId)
	if not store then
		return false, nil
	end
	for _ = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync("Player_" .. userId)
		end)
		if ok then
			return true, result
		end
		warn("[StarData] load failed:", result)
		task.wait(1)
	end
	return false, nil
end

function StarData.Load(player)
	local ok, saved = loadFromStore(player.UserId)
	if not player.Parent then return end -- left while loading

	local profile = {
		Stardust = 0,
		Total = 0,
		Supernovas = 0,
		Upgrades = blankUpgrades(),
		Carried = 0,
		PostedTotal = 0,
		SavePending = false,
		CanSave = ok, -- never save over a profile we failed to load
	}

	if ok and type(saved) == "table" then
		profile.Stardust = math.max(0, math.floor(tonumber(saved.Stardust) or 0))
		profile.Total = math.max(0, math.floor(tonumber(saved.Total) or 0))
		profile.Supernovas = math.max(0, math.floor(tonumber(saved.Supernovas) or 0))
		profile.PostedTotal = profile.Total
		if type(saved.Upgrades) == "table" then
			for _, def in ipairs(StarConfig.Upgrades) do
				local level = tonumber(saved.Upgrades[def.Id])
				if level then
					profile.Upgrades[def.Id] = math.clamp(math.floor(level), 0, def.Max)
				end
			end
		end
	end

	StarData.Profiles[player] = profile
	StarData.Sync(player)
	StarData.Loaded:Fire(player)
end

function StarData.Save(player)
	local profile = StarData.Profiles[player]
	if not store or not profile or not profile.CanSave then return end

	local ok, err = pcall(function()
		store:UpdateAsync("Player_" .. player.UserId, function()
			return {
				Stardust = profile.Stardust,
				Total = profile.Total,
				Supernovas = profile.Supernovas,
				Upgrades = table.clone(profile.Upgrades),
			}
		end)
	end)
	if not ok then
		warn("[StarData] save failed:", err)
	end

	-- the all-time leaderboard only ever goes up
	if board and profile.Total > profile.PostedTotal then
		local total = profile.Total
		local boardSaved = pcall(function()
			board:SetAsync(tostring(player.UserId), total)
		end)
		if boardSaved then
			profile.PostedTotal = total
		end
	end
end

-- Saves a few seconds from now (many changes in a row become one write)
function StarData.RequestSave(player)
	local profile = StarData.Profiles[player]
	if not profile or profile.SavePending then return end
	profile.SavePending = true
	task.delay(SAVE_DELAY, function()
		profile.SavePending = false
		if StarData.Profiles[player] == profile then
			StarData.Save(player)
		end
	end)
end

function StarData.Changed(player)
	StarData.Sync(player)
	StarData.RequestSave(player)
end

Players.PlayerAdded:Connect(StarData.Load)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(StarData.Load, p)
end

Players.PlayerRemoving:Connect(function(player)
	StarData.Save(player)
	StarData.Profiles[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in pairs(StarData.Profiles) do
			task.spawn(StarData.Save, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in pairs(StarData.Profiles) do
		pending += 1
		task.spawn(function()
			StarData.Save(player)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait()
	end
end)

return StarData
