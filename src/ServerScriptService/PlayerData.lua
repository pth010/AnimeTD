-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: PlayerData
-- (replaces the earlier version: auto-equip always puts your cash units on the team)
--
-- Single source of truth for each player's gems, gold, pity, units, locks, team and settings.
-- Saving needs a published place (File > Publish to Roblox). To test in Studio, also enable
--   Game Settings > Security > "Enable Studio Access to API Services".
-- If loading fails, the player still plays but that session will NOT save,
-- so a DataStore outage can never overwrite real progress with a blank profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))

local STORE_NAME = "AnimeTD_PlayerData_v1" -- bump the version to wipe everyone's data
local AUTOSAVE_INTERVAL = 120
local SAVE_DELAY = 5 -- seconds after a change before it is written
local STARTING_GEMS = 1000
local STARTING_GOLD = 0

-- Units every NEW player starts with. Empty = the inventory starts empty.
-- Example: { ["Blade Novice"] = 1 }
local STARTING_UNITS = {}

-- GetDataStore throws if the place isn't published yet. Fall back to "no saving"
-- so the game still runs (progress just won't persist until you publish).
local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	warn("[PlayerData] DataStore unavailable (publish the place to enable saving). Running without saving.")
	store = nil
end

local PlayerData = {}
PlayerData.Profiles = {}

-- Profile layout:
--   Units      [name] = copies you currently own
--   Obtained   [name] = total copies ever received   (only ever goes up)
--   Deleted    [name] = total copies ever deleted    (only ever goes up, includes auto-deletes)
--   Locked     [name] = true  (locked units can't be deleted or auto-deleted)
--   Equipped   = ordered list of unit names on your team (max UnitData.TeamSize)
--   AutoEquip  = true: the team is always your best units by damage per second
--   AutoDelete [rarityName] = true: newly summoned units of that rarity are deleted on arrival
-- Units = Obtained - Deleted. Keeping both running totals lets two servers merge
-- their saves safely: taking the higher of each total can never resurrect a deleted
-- unit or lose a new one.

local function cleanCounts(t)
	local out = {}
	if type(t) ~= "table" then return out end
	for name, n in pairs(t) do
		n = tonumber(n)
		if UnitData.UnitRarity[name] and n and n > 0 then
			out[name] = math.floor(n)
		end
	end
	return out
end

-- ===== Team helpers =====
-- How auto-equip ranks units: cash units first (they never attack, so damage can't
-- rank them), then everything else by damage per second
local function dps(unitName)
	if UnitData.IsFarm(unitName) then
		return math.huge
	end
	local s = UnitData.GetStats(unitName)
	return s.Damage / s.Cooldown
end

local function autoEquipBest(profile)
	local names = {}
	for name in pairs(profile.Units) do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		local da, db = dps(a), dps(b)
		if da ~= db then return da > db end
		return a < b
	end)

	profile.Equipped = {}
	for i = 1, math.min(#names, UnitData.TeamSize) do
		profile.Equipped[i] = names[i]
	end
end

local function pruneEquipped(profile)
	local kept, seen = {}, {}
	for _, name in ipairs(profile.Equipped) do
		if profile.Units[name] and not seen[name] and #kept < UnitData.TeamSize then
			table.insert(kept, name)
			seen[name] = true
		end
	end
	profile.Equipped = kept
end

local function normalizeEquipment(profile)
	if profile.AutoEquip then
		autoEquipBest(profile)
	else
		pruneEquipped(profile)
	end
end

function PlayerData.Get(player)
	return PlayerData.Profiles[player]
end

-- Mirrors profile values onto player attributes so the client UI can read them
function PlayerData.Sync(player)
	local profile = PlayerData.Profiles[player]
	if not profile then return end

	player:SetAttribute("Gems", profile.Gems)
	player:SetAttribute("Gold", profile.Gold)
	player:SetAttribute("Pity", profile.Pity)

	local counts, locks = {}, {}
	for name, count in pairs(profile.Units) do
		table.insert(counts, name .. "=" .. count)
		if profile.Locked[name] then
			table.insert(locks, name)
		end
	end
	table.sort(counts)
	table.sort(locks)

	local autoDelete = {}
	for rarityName in pairs(profile.AutoDelete) do
		table.insert(autoDelete, rarityName)
	end
	table.sort(autoDelete)

	player:SetAttribute("UnitCounts", table.concat(counts, ";"))        -- "Blade Novice=2;Ember Archer=1"
	player:SetAttribute("UnitLocks", table.concat(locks, ";"))          -- "Blade Novice;Frost Mage"
	player:SetAttribute("Equipped", table.concat(profile.Equipped, ",")) -- the match hotbar
	player:SetAttribute("AutoEquip", profile.AutoEquip)
	player:SetAttribute("AutoDelete", table.concat(autoDelete, ","))    -- "Common,Rare"
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
		warn("[PlayerData] load failed:", result)
		task.wait(1)
	end
	return false, nil
end

function PlayerData.Load(player)
	local ok, saved = loadFromStore(player.UserId)
	if not player.Parent then return end -- left while loading

	local profile = {
		Gems = STARTING_GEMS,
		Gold = STARTING_GOLD,
		Pity = 0,
		Units = cleanCounts(STARTING_UNITS),
		Obtained = cleanCounts(STARTING_UNITS),
		Deleted = {},
		Locked = {},
		Equipped = {},
		AutoEquip = true,
		AutoDelete = {},
		Busy = false,
		SavePending = false,
		CanSave = ok, -- never save over a profile we failed to load
	}

	if ok and type(saved) == "table" then
		profile.Gems = tonumber(saved.Gems) or STARTING_GEMS
		profile.Gold = tonumber(saved.Gold) or STARTING_GOLD
		profile.Pity = tonumber(saved.Pity) or 0

		if type(saved.Units) == "table" then
			profile.Units = cleanCounts(saved.Units) -- may be empty, that's valid
			-- Older saves have no running totals: treat what they owned as "obtained"
			profile.Obtained = type(saved.Obtained) == "table" and cleanCounts(saved.Obtained) or cleanCounts(saved.Units)
			profile.Deleted = cleanCounts(saved.Deleted)
		end

		if type(saved.Locked) == "table" then
			for name, v in pairs(saved.Locked) do
				if v == true and profile.Units[name] then
					profile.Locked[name] = true
				end
			end
		end

		if saved.AutoEquip ~= nil then
			profile.AutoEquip = saved.AutoEquip == true
		end
		if type(saved.AutoDelete) == "table" then
			for rarityName, v in pairs(saved.AutoDelete) do
				if v == true and UnitData.RarityColor[rarityName] then
					profile.AutoDelete[rarityName] = true
				end
			end
		end
		if type(saved.Equipped) == "table" then
			for _, name in ipairs(saved.Equipped) do
				if type(name) == "string" then
					table.insert(profile.Equipped, name)
				end
			end
		end
	end

	normalizeEquipment(profile)
	PlayerData.Profiles[player] = profile
	PlayerData.Sync(player)
end

function PlayerData.Save(player)
	local profile = PlayerData.Profiles[player]
	if not store or not profile or not profile.CanSave then return end

	local key = "Player_" .. player.UserId
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			local obtained = table.clone(profile.Obtained)
			local deleted = table.clone(profile.Deleted)

			-- Merge with whatever another server may have saved: higher running total wins
			if type(old) == "table" then
				local oldObtained = type(old.Obtained) == "table" and old.Obtained or old.Units
				for name, n in pairs(cleanCounts(oldObtained)) do
					if (obtained[name] or 0) < n then obtained[name] = n end
				end
				for name, n in pairs(cleanCounts(old.Deleted)) do
					if (deleted[name] or 0) < n then deleted[name] = n end
				end
			end

			local units, locked = {}, {}
			for name, got in pairs(obtained) do
				local left = got - (deleted[name] or 0)
				if left > 0 then
					units[name] = left
					if profile.Locked[name] then
						locked[name] = true
					end
				end
			end

			local equipped = {}
			for _, name in ipairs(profile.Equipped) do
				if units[name] then
					table.insert(equipped, name)
				end
			end

			return {
				Gems = profile.Gems,
				Gold = profile.Gold,
				Pity = profile.Pity,
				Units = units,
				Obtained = obtained,
				Deleted = deleted,
				Locked = locked,
				Equipped = equipped,
				AutoEquip = profile.AutoEquip,
				AutoDelete = table.clone(profile.AutoDelete),
			}
		end)
	end)
	if not ok then
		warn("[PlayerData] save failed:", err)
	end
end

-- Saves a few seconds from now (many changes in a row become one write)
function PlayerData.RequestSave(player)
	local profile = PlayerData.Profiles[player]
	if not profile or profile.SavePending then return end
	profile.SavePending = true
	task.delay(SAVE_DELAY, function()
		profile.SavePending = false
		PlayerData.Save(player)
	end)
end

-- Call after the inventory changed: re-picks the team (if auto-equip is on),
-- updates the client, and schedules a save.
function PlayerData.Refresh(player)
	local profile = PlayerData.Profiles[player]
	if not profile then return end
	normalizeEquipment(profile)
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
end

function PlayerData.AddGems(player, amount)
	local profile = PlayerData.Profiles[player]
	if not profile then return end
	profile.Gems += amount
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
end

function PlayerData.AddGold(player, amount)
	local profile = PlayerData.Profiles[player]
	if not profile then return end
	profile.Gold += amount
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
end

-- Gives one copy of a unit. If you've turned on auto-delete for its rarity (and the unit
-- isn't locked) the copy is deleted straight away. Returns true if it was auto-deleted.
-- The caller runs PlayerData.Refresh afterwards (e.g. once after a 10-pull).
function PlayerData.AddUnit(profile, unitName)
	profile.Obtained[unitName] = (profile.Obtained[unitName] or 0) + 1

	local rarityName = UnitData.UnitRarity[unitName]
	if profile.AutoDelete[rarityName] and not profile.Locked[unitName] then
		profile.Deleted[unitName] = (profile.Deleted[unitName] or 0) + 1
		return true
	end

	profile.Units[unitName] = (profile.Units[unitName] or 0) + 1
	return false
end

-- amount: a number of copies, or "All". Returns ok, errorMessage
function PlayerData.DeleteUnit(player, unitName, amount)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end

	local have = profile.Units[unitName]
	if not have then return false, "You don't have that unit." end
	if profile.Locked[unitName] then return false, "Unlock it first." end

	local n = have
	if amount ~= "All" then
		n = math.clamp(math.floor(tonumber(amount) or 1), 1, have)
	end

	profile.Deleted[unitName] = (profile.Deleted[unitName] or 0) + n
	profile.Units[unitName] = (have - n > 0) and (have - n) or nil

	PlayerData.Refresh(player)
	return true
end

function PlayerData.SetLocked(player, unitName, locked)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	if not profile.Units[unitName] then return false, "You don't have that unit." end

	profile.Locked[unitName] = locked and true or nil
	PlayerData.Refresh(player)
	return true
end

-- Manual team editing (only while auto-equip is off)
function PlayerData.SetEquipped(player, unitName, on)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	if profile.AutoEquip then return false, "Turn off auto-equip to pick your team." end
	if not profile.Units[unitName] then return false, "You don't have that unit." end

	local index = table.find(profile.Equipped, unitName)
	if on then
		if index then return true end
		if #profile.Equipped >= UnitData.TeamSize then
			return false, string.format("Your team is full (%d).", UnitData.TeamSize)
		end
		table.insert(profile.Equipped, unitName)
	elseif index then
		table.remove(profile.Equipped, index)
	end

	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
	return true
end

function PlayerData.SetAutoEquip(player, on)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	profile.AutoEquip = on and true or false
	PlayerData.Refresh(player)
	return true
end

function PlayerData.SetAutoDelete(player, rarityName, on)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	if not UnitData.RarityColor[rarityName] then return false, "Unknown rarity." end

	profile.AutoDelete[rarityName] = on and true or nil
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
	return true
end

Players.PlayerAdded:Connect(PlayerData.Load)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerData.Load, p)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Save(player)
	PlayerData.Profiles[player] = nil
end)

-- Autosave
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in pairs(PlayerData.Profiles) do
			task.spawn(PlayerData.Save, player)
		end
	end
end)

-- Save everyone when the server shuts down
game:BindToClose(function()
	local pending = 0
	for player in pairs(PlayerData.Profiles) do
		pending += 1
		task.spawn(function()
			PlayerData.Save(player)
			pending -= 1
		end)
	end
	local startTime = os.clock()
	while pending > 0 and os.clock() - startTime < 25 do
		task.wait()
	end
end)

return PlayerData
