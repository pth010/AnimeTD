-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: PlayerData
-- (replaces the earlier version: saves your best wave in Infinite Mode)
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
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local ProgressData = require(ReplicatedStorage:WaitForChild("ProgressData"))

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
--   Cleared    [levelId] = true: levels this player has beaten (see LevelData)
--   Traits     [name] = trait name (see TraitData), one per unit you own
--   XP         [name] = fusion XP (sets the unit's level, see ProgressData)
--   Stars      [name] = evolution stars (0 to ProgressData.MaxStars)
--   BestWave   = the highest wave reached in Infinite Mode (only ever goes up)
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
local function dps(profile, unitName)
	if UnitData.IsFarm(unitName) then
		return math.huge
	end
	local s = ProgressData.Apply(TraitData.StatsFor(unitName, profile.Traits[unitName]),
		profile.XP[unitName], profile.Stars[unitName])
	return s.Damage / s.Cooldown
end

local function autoEquipBest(profile)
	local names = {}
	for name in pairs(profile.Units) do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		local da, db = dps(profile, a), dps(profile, b)
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
	player:SetAttribute("BestWave", profile.BestWave)

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

	local cleared = {}
	for id in pairs(profile.Cleared) do
		table.insert(cleared, id)
	end
	table.sort(cleared)
	player:SetAttribute("ClearedLevels", table.concat(cleared, ","))    -- "1,2"

	local traits = {}
	for name, trait in pairs(profile.Traits) do
		if profile.Units[name] then
			table.insert(traits, name .. "=" .. trait)
		end
	end
	table.sort(traits)
	player:SetAttribute("UnitTraits", table.concat(traits, ";"))        -- "Blade Novice=Lord;Frost Mage=Swift"

	local progress = {}
	for name in pairs(profile.Units) do
		local xp, stars = profile.XP[name] or 0, profile.Stars[name] or 0
		if xp > 0 or stars > 0 then
			table.insert(progress, string.format("%s=%d:%d", name, xp, stars))
		end
	end
	table.sort(progress)
	player:SetAttribute("UnitProgress", table.concat(progress, ";"))    -- "Frost Mage=1200:2" (XP:stars)
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
		Cleared = {},
		Traits = {},
		XP = {},
		Stars = {},
		BestWave = 0,
		Busy = false,
		SavePending = false,
		CanSave = ok, -- never save over a profile we failed to load
	}

	if ok and type(saved) == "table" then
		profile.Gems = tonumber(saved.Gems) or STARTING_GEMS
		profile.Gold = tonumber(saved.Gold) or STARTING_GOLD
		profile.Pity = tonumber(saved.Pity) or 0
		profile.BestWave = math.max(0, math.floor(tonumber(saved.BestWave) or 0))

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
		if type(saved.Cleared) == "table" then
			for _, id in ipairs(saved.Cleared) do
				if tonumber(id) then
					profile.Cleared[tonumber(id)] = true
				end
			end
		end
		if type(saved.Traits) == "table" then
			for name, trait in pairs(saved.Traits) do
				if profile.Units[name] and TraitData.Get(trait) then
					profile.Traits[name] = trait
				end
			end
		end
		if type(saved.XP) == "table" then
			for name, xp in pairs(saved.XP) do
				if profile.Units[name] and tonumber(xp) then
					profile.XP[name] = math.clamp(math.floor(tonumber(xp)), 0, ProgressData.MaxXP())
				end
			end
		end
		if type(saved.Stars) == "table" then
			for name, stars in pairs(saved.Stars) do
				if profile.Units[name] and tonumber(stars) then
					profile.Stars[name] = math.clamp(math.floor(tonumber(stars)), 0, ProgressData.MaxStars)
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

			local units, locked, traits, xpOut, starsOut = {}, {}, {}, {}, {}
			local oldXP = type(old) == "table" and type(old.XP) == "table" and old.XP or {}
			local oldStars = type(old) == "table" and type(old.Stars) == "table" and old.Stars or {}
			for name, got in pairs(obtained) do
				local left = got - (deleted[name] or 0)
				if left > 0 then
					units[name] = left
					if profile.Locked[name] then
						locked[name] = true
					end
					-- keep this server's trait, or the one another server saved
					traits[name] = profile.Traits[name]
						or (type(old) == "table" and type(old.Traits) == "table" and TraitData.Get(old.Traits[name]) and old.Traits[name])
						or nil
					xpOut[name] = profile.XP[name] or tonumber(oldXP[name])
					starsOut[name] = profile.Stars[name] or tonumber(oldStars[name])
				end
			end

			local equipped = {}
			for _, name in ipairs(profile.Equipped) do
				if units[name] then
					table.insert(equipped, name)
				end
			end

			-- beaten levels: keep every level either server has seen beaten
			local cleared = {}
			for id in pairs(profile.Cleared) do
				cleared[id] = true
			end
			if type(old) == "table" and type(old.Cleared) == "table" then
				for _, id in ipairs(old.Cleared) do
					if tonumber(id) then cleared[tonumber(id)] = true end
				end
			end
			local clearedList = {}
			for id in pairs(cleared) do
				table.insert(clearedList, id)
			end
			table.sort(clearedList)

			-- best wave: whichever server saw the higher one
			local bestWave = profile.BestWave
			if type(old) == "table" and tonumber(old.BestWave) then
				bestWave = math.max(bestWave, math.floor(tonumber(old.BestWave)))
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
				Cleared = clearedList,
				Traits = traits,
				XP = xpOut,
				Stars = starsOut,
				BestWave = bestWave,
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

-- Records that the player beat a level (unlocks the next one)
function PlayerData.MarkCleared(player, levelId)
	local profile = PlayerData.Profiles[player]
	if not profile or profile.Cleared[levelId] then return end
	profile.Cleared[levelId] = true
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
end

-- Records how far the player got in an Infinite Mode run. Returns true if it's a new best.
function PlayerData.RecordWave(player, wave)
	local profile = PlayerData.Profiles[player]
	if not profile or wave <= profile.BestWave then return false end
	profile.BestWave = wave
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
	return true
end

function PlayerData.HasCleared(player, levelId)
	local profile = PlayerData.Profiles[player]
	return profile ~= nil and profile.Cleared[levelId] == true
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
	if not profile.Units[unitName] then
		-- the last copy is gone, and its trait, level and stars with it
		profile.Traits[unitName] = nil
		profile.XP[unitName] = nil
		profile.Stars[unitName] = nil
	end

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

-- Rolls a new random trait onto a unit for TraitData.RollCost Gold.
-- Returns ok, errorMessage, newTraitName
function PlayerData.RollTrait(player, unitName)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	if not profile.Units[unitName] then return false, "You don't have that unit." end
	if profile.Gold < TraitData.RollCost then
		return false, string.format("You need %d Gold to roll a trait.", TraitData.RollCost)
	end

	profile.Gold -= TraitData.RollCost
	local trait = TraitData.Roll()
	profile.Traits[unitName] = trait
	PlayerData.Refresh(player) -- the trait can change who auto-equip picks
	return true, nil, trait
end

-- Fuses other units into `target` for XP. feed = { [unitName] = copies }.
-- Locked units can't be fed, and a unit can't be fed into itself (use Evolve for that).
-- Returns ok, errorMessage, xpGained
function PlayerData.Fuse(player, target, feed)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	if not profile.Units[target] then return false, "You don't have that unit." end
	if type(feed) ~= "table" then return false, "Pick units to fuse." end

	local maxXP = ProgressData.MaxXP()
	local currentXP = profile.XP[target] or 0
	if currentXP >= maxXP then return false, target .. " is already max level." end

	-- check everything first, so a bad entry can't half-finish the fusion
	local plan, gained = {}, 0
	for name, n in pairs(feed) do
		n = tonumber(n)
		if type(name) ~= "string" or not n or n < 1 or n ~= math.floor(n) then
			return false, "Bad fusion request."
		end
		if name == target then return false, "Use Evolve to use copies of the same unit." end
		local have = profile.Units[name]
		if not have or have < n then return false, "You don't have enough " .. name .. "." end
		if profile.Locked[name] then return false, name .. " is locked." end
		plan[name] = n
		gained += n * ProgressData.FodderXP[UnitData.UnitRarity[name]]
	end
	if gained == 0 then return false, "Pick units to fuse." end

	for name, n in pairs(plan) do
		profile.Deleted[name] = (profile.Deleted[name] or 0) + n
		local left = profile.Units[name] - n
		profile.Units[name] = left > 0 and left or nil
		if left <= 0 then
			profile.Traits[name] = nil
			profile.XP[name] = nil
			profile.Stars[name] = nil
		end
	end
	profile.XP[target] = math.min(currentXP + gained, maxXP)

	PlayerData.Refresh(player)
	return true, nil, profile.XP[target] - currentXP
end

-- Uses extra copies of a unit (and Gold) to give it one more star. Returns ok, errorMessage
function PlayerData.Evolve(player, unitName)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	local have = profile.Units[unitName]
	if not have then return false, "You don't have that unit." end

	local stars = profile.Stars[unitName] or 0
	local step = ProgressData.Evolutions[stars + 1]
	if not step then return false, unitName .. " is fully evolved." end
	if have - 1 < step.Copies then
		return false, string.format("You need %d extra %s (you have %d extra).", step.Copies, unitName, have - 1)
	end
	if profile.Gold < step.Gold then
		return false, string.format("You need %d Gold to evolve.", step.Gold)
	end

	profile.Gold -= step.Gold
	profile.Deleted[unitName] = (profile.Deleted[unitName] or 0) + step.Copies
	profile.Units[unitName] = have - step.Copies
	profile.Stars[unitName] = stars + 1

	PlayerData.Refresh(player)
	return true
end

-- Sets a unit's trait directly (tester command). nil removes it.
function PlayerData.SetTrait(player, unitName, traitName)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	if not profile.Units[unitName] then return false, "You don't have that unit." end
	if traitName ~= nil and not TraitData.Get(traitName) then return false, "Unknown trait." end
	profile.Traits[unitName] = traitName
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
