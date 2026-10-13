-- PLACE IN: ServerScriptService
-- TYPE: ModuleScript
-- NAME: PlayerData
-- (replaces the earlier version: every unit is now its own entry with its own trait, level,
--  stars and lock, and the inventory has slots (100 to start, more from game passes).
--  Old saves are converted automatically: a stack of 3 becomes 3 separate units.
--  Units can be put into a chosen team slot, see PlayerData.EquipToSlot. Each player's screen
--  layout (where the team bar, Inventory button and currency counter sit) is saved too.)
--
-- Single source of truth for each player's gems, gold, trait shards, pity, units, locks,
-- team and settings.
-- Saving needs a published place (File > Publish to Roblox). To test in Studio, also enable
--   Game Settings > Security > "Enable Studio Access to API Services".
-- If loading fails, the player still plays but that session will NOT save,
-- so a DataStore outage can never overwrite real progress with a blank profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local ProgressData = require(ReplicatedStorage:WaitForChild("ProgressData"))

local STORE_NAME = "AnimeTD_PlayerData_v1" -- bump the version to wipe everyone's data
local SAVE_VERSION = 2 -- 1 = units stacked by name, 2 = one entry per unit
local AUTOSAVE_INTERVAL = 120
local SAVE_DELAY = 5 -- seconds after a change before it is written
local STARTING_GEMS = 1000
local STARTING_GOLD = 0
local STARTING_SHARDS = 3 -- enough for a few trait summons in the Traits Cave

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

-- The screen elements players can move in the Screen Layout panel, and how far they can go
PlayerData.LayoutElements = { TeamBar = true, InventoryButton = true, Currency = true }
local LAYOUT_MOVE_LIMIT = 0.5          -- up to half a screen in any direction
local LAYOUT_SIZE_MIN, LAYOUT_SIZE_MAX = 0.6, 1.6

local function cleanLayout(t)
	local out = {}
	if type(t) ~= "table" then return out end
	for key, v in pairs(t) do
		if PlayerData.LayoutElements[key] and type(v) == "table" then
			local x, y, s = tonumber(v.X), tonumber(v.Y), tonumber(v.S)
			if x and y and s then
				out[key] = {
					X = math.clamp(x, -LAYOUT_MOVE_LIMIT, LAYOUT_MOVE_LIMIT),
					Y = math.clamp(y, -LAYOUT_MOVE_LIMIT, LAYOUT_MOVE_LIMIT),
					S = math.clamp(s, LAYOUT_SIZE_MIN, LAYOUT_SIZE_MAX),
				}
			end
		end
	end
	return out
end

-- Profile layout:
--   Units      [id] = { Id, Name, Trait, XP, Stars, Locked }   one entry per unit you own
--   NextId     the id the next new unit gets
--   Equipped   = ordered list of unit ids on your team (max UnitData.TeamSize, one per name)
--   AutoEquip  = true: the team is always your best units by damage per second
--   AutoDelete [rarityName] = true: newly summoned units of that rarity are deleted on arrival
--   Cleared    [levelId] = true: levels this player has beaten (see LevelData)
--   BonusSlots extra inventory slots from rewards (saved; game pass slots are checked on join)
--   PassSlots  slots from owned game passes (not saved, see UnitData.SlotPasses)
--   UILayout   [element] = { X, Y, S }: how far each screen element is moved (fractions of
--              the screen) and its size, set in the Screen Layout panel (see LayoutUI)

-- ===== Units =====
local function newUnit(profile, unitName)
	local id = profile.NextId
	profile.NextId += 1
	local unit = { Id = id, Name = unitName, Trait = nil, XP = 0, Stars = 0, Locked = false }
	profile.Units[id] = unit
	return unit
end

function PlayerData.UnitCount(profile)
	local n = 0
	for _ in pairs(profile.Units) do
		n += 1
	end
	return n
end

function PlayerData.MaxSlots(profile)
	return UnitData.BaseSlots + (profile.BonusSlots or 0) + (profile.PassSlots or 0)
end

function PlayerData.FreeSlots(profile)
	return PlayerData.MaxSlots(profile) - PlayerData.UnitCount(profile)
end

-- The unit with this id, if the player owns it (ids arrive from clients as numbers)
function PlayerData.FindUnit(profile, id)
	return typeof(id) == "number" and profile.Units[id] or nil
end

-- The copy of `unitName` on the player's team (what gets placed in a match)
function PlayerData.EquippedUnit(profile, unitName)
	for _, id in ipairs(profile.Equipped) do
		local u = profile.Units[id]
		if u and u.Name == unitName then
			return u
		end
	end
	return nil
end

-- The player's strongest copy of a unit: the equipped one, else the highest level (tester commands)
function PlayerData.BestCopy(profile, unitName)
	local best = PlayerData.EquippedUnit(profile, unitName)
	if best then return best end
	for _, u in pairs(profile.Units) do
		if u.Name == unitName and (not best or u.XP + u.Stars * 1e6 > best.XP + best.Stars * 1e6) then
			best = u
		end
	end
	return best
end

-- ===== Team helpers =====
-- How auto-equip ranks units: cash units first (they never attack, so damage can't
-- rank them), then everything else by damage per second
local function dps(unit)
	if UnitData.IsFarm(unit.Name) then
		return math.huge
	end
	local s = ProgressData.Apply(TraitData.StatsFor(unit.Name, unit.Trait), unit.XP, unit.Stars)
	return s.Damage / s.Cooldown
end

local function autoEquipBest(profile)
	local units = {}
	for _, u in pairs(profile.Units) do
		table.insert(units, { Unit = u, Score = dps(u) })
	end
	table.sort(units, function(a, b)
		if a.Score ~= b.Score then return a.Score > b.Score end
		if a.Unit.Name ~= b.Unit.Name then return a.Unit.Name < b.Unit.Name end
		return a.Unit.Id < b.Unit.Id
	end)

	-- the best copy of each different unit, until the team is full
	profile.Equipped = {}
	local names = {}
	for _, entry in ipairs(units) do
		if #profile.Equipped >= UnitData.TeamSize then break end
		if not names[entry.Unit.Name] then
			names[entry.Unit.Name] = true
			table.insert(profile.Equipped, entry.Unit.Id)
		end
	end
end

local function pruneEquipped(profile)
	local kept, names = {}, {}
	for _, id in ipairs(profile.Equipped) do
		local u = profile.Units[id]
		if u and not names[u.Name] and #kept < UnitData.TeamSize then
			table.insert(kept, id)
			names[u.Name] = true
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
	player:SetAttribute("Shards", profile.Shards)
	player:SetAttribute("Pity", profile.Pity)
	player:SetAttribute("MaxSlots", PlayerData.MaxSlots(profile))

	-- every unit: "id|name|trait|xp|stars|locked" (read with UnitData.ParseUnits)
	local ids = {}
	for id in pairs(profile.Units) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local entries = {}
	for _, id in ipairs(ids) do
		local u = profile.Units[id]
		table.insert(entries, string.format("%d|%s|%s|%d|%d|%d", u.Id, u.Name, u.Trait or "", u.XP, u.Stars, u.Locked and 1 or 0))
	end
	player:SetAttribute("Units", table.concat(entries, ";"))

	-- the team, as ids (Inventory) and as names (match hotbar), plus the team's traits and
	-- progress by name, which is what the match hotbar shows
	local teamIds, teamNames, teamTraits, teamProgress = {}, {}, {}, {}
	for _, id in ipairs(profile.Equipped) do
		local u = profile.Units[id]
		if u then
			table.insert(teamIds, tostring(id))
			table.insert(teamNames, u.Name)
			if u.Trait then
				table.insert(teamTraits, u.Name .. "=" .. u.Trait)
			end
			table.insert(teamProgress, string.format("%s=%d:%d", u.Name, u.XP, u.Stars))
		end
	end
	player:SetAttribute("EquippedIds", table.concat(teamIds, ","))       -- "12,4,31"
	player:SetAttribute("Equipped", table.concat(teamNames, ","))       -- "Frost Mage,Blade Novice"
	player:SetAttribute("UnitTraits", table.concat(teamTraits, ";"))    -- "Frost Mage=Swift"
	player:SetAttribute("UnitProgress", table.concat(teamProgress, ";")) -- "Frost Mage=1200:2"
	player:SetAttribute("AutoEquip", profile.AutoEquip)

	local autoDelete = {}
	for rarityName in pairs(profile.AutoDelete) do
		table.insert(autoDelete, rarityName)
	end
	table.sort(autoDelete)
	player:SetAttribute("AutoDelete", table.concat(autoDelete, ",")) -- "Common,Rare"

	local cleared = {}
	for id in pairs(profile.Cleared) do
		table.insert(cleared, id)
	end
	table.sort(cleared)
	player:SetAttribute("ClearedLevels", table.concat(cleared, ",")) -- "1,2"

	local layout = {}
	for key, v in pairs(profile.UILayout) do
		table.insert(layout, string.format("%s=%.4f:%.4f:%.4f", key, v.X, v.Y, v.S))
	end
	table.sort(layout)
	player:SetAttribute("UILayout", table.concat(layout, ";")) -- "TeamBar=0.1000:-0.0500:1.2000"
end

-- ===== Loading =====
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

local function cleanNumber(v, min, max)
	v = tonumber(v)
	if not v then return nil end
	return math.clamp(math.floor(v), min, max)
end

-- Version 2 saves: Units = { { I = id, N = name, T = trait, X = xp, S = stars, L = locked }, ... }
local function loadUnitsV2(profile, saved)
	local maxId = 0
	for _, e in ipairs(saved.Units) do
		local id = type(e) == "table" and cleanNumber(e.I, 1, 1e12)
		if id and UnitData.UnitRarity[e.N] and not profile.Units[id] then
			profile.Units[id] = {
				Id = id,
				Name = e.N,
				Trait = TraitData.Get(e.T) and e.T or nil,
				XP = cleanNumber(e.X, 0, ProgressData.MaxXP()) or 0,
				Stars = cleanNumber(e.S, 0, ProgressData.MaxStars) or 0,
				Locked = e.L == true,
			}
			maxId = math.max(maxId, id)
		end
	end
	profile.NextId = math.max(cleanNumber(saved.NextId, 1, 1e12) or 1, maxId + 1)
	if type(saved.Equipped) == "table" then
		for _, id in ipairs(saved.Equipped) do
			if profile.Units[tonumber(id)] then
				table.insert(profile.Equipped, tonumber(id))
			end
		end
	end
end

-- Version 1 saves stacked units by name: Units[name] = copies, with one trait / XP / stars
-- per name. Each copy becomes its own unit; the first copy keeps the trait, XP and stars.
local function loadUnitsV1(profile, saved)
	local firstOf = {}
	local names = {}
	for name in pairs(saved.Units) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local copies = cleanNumber(saved.Units[name], 0, 10000)
		if UnitData.UnitRarity[name] and copies and copies > 0 then
			local locked = type(saved.Locked) == "table" and saved.Locked[name] == true
			for i = 1, copies do
				local u = newUnit(profile, name)
				u.Locked = locked
				if i == 1 then
					firstOf[name] = u
					local trait = type(saved.Traits) == "table" and saved.Traits[name]
					u.Trait = TraitData.Get(trait) and trait or nil
					u.XP = type(saved.XP) == "table" and cleanNumber(saved.XP[name], 0, ProgressData.MaxXP()) or 0
					u.Stars = type(saved.Stars) == "table" and cleanNumber(saved.Stars[name], 0, ProgressData.MaxStars) or 0
				end
			end
		end
	end
	if type(saved.Equipped) == "table" then
		for _, name in ipairs(saved.Equipped) do
			local u = firstOf[name]
			if u then
				table.insert(profile.Equipped, u.Id)
			end
		end
	end
end

-- Counts the slots from slot game passes the player owns
local function checkSlotPasses(player, profile)
	local slots = 0
	for _, pass in ipairs(UnitData.SlotPasses) do
		if pass.Id and pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				slots += pass.Slots
			end
		end
	end
	profile.PassSlots = slots
end

function PlayerData.Load(player)
	local ok, saved = loadFromStore(player.UserId)
	if not player.Parent then return end -- left while loading

	local profile = {
		Gems = STARTING_GEMS,
		Gold = STARTING_GOLD,
		Shards = STARTING_SHARDS,
		Pity = 0,
		Units = {},
		NextId = 1,
		Equipped = {},
		AutoEquip = true,
		AutoDelete = {},
		Cleared = {},
		BonusSlots = 0,
		PassSlots = 0,
		UILayout = {},
		Busy = false,
		SavePending = false,
		CanSave = ok, -- never save over a profile we failed to load
	}

	if ok and type(saved) == "table" then
		profile.Gems = tonumber(saved.Gems) or STARTING_GEMS
		profile.Gold = tonumber(saved.Gold) or STARTING_GOLD
		profile.Shards = tonumber(saved.Shards) or STARTING_SHARDS
		profile.Pity = tonumber(saved.Pity) or 0
		profile.BonusSlots = cleanNumber(saved.BonusSlots, 0, 100000) or 0
		profile.UILayout = cleanLayout(saved.UILayout)

		if type(saved.Units) == "table" then
			if saved.Version == SAVE_VERSION then
				loadUnitsV2(profile, saved)
			else
				loadUnitsV1(profile, saved)
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
		if type(saved.Cleared) == "table" then
			for _, id in ipairs(saved.Cleared) do
				if tonumber(id) then
					profile.Cleared[tonumber(id)] = true
				end
			end
		end
	elseif ok then
		-- a brand new player
		for name, copies in pairs(STARTING_UNITS) do
			if UnitData.UnitRarity[name] then
				for _ = 1, copies do
					newUnit(profile, name)
				end
			end
		end
	end

	checkSlotPasses(player, profile)
	if not player.Parent then return end
	normalizeEquipment(profile)
	PlayerData.Profiles[player] = profile
	PlayerData.Sync(player)
end

-- ===== Saving =====
function PlayerData.Save(player)
	local profile = PlayerData.Profiles[player]
	if not store or not profile or not profile.CanSave then return end

	local units = {}
	for _, u in pairs(profile.Units) do
		table.insert(units, { I = u.Id, N = u.Name, T = u.Trait, X = u.XP, S = u.Stars, L = u.Locked or nil })
	end
	table.sort(units, function(a, b) return a.I < b.I end)

	local key = "Player_" .. player.UserId
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			-- beaten levels: keep every level either this or another server has seen beaten
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

			return {
				Version = SAVE_VERSION,
				Gems = profile.Gems,
				Gold = profile.Gold,
				Shards = profile.Shards,
				Pity = profile.Pity,
				Units = units,
				NextId = profile.NextId,
				Equipped = table.clone(profile.Equipped),
				AutoEquip = profile.AutoEquip,
				AutoDelete = table.clone(profile.AutoDelete),
				Cleared = clearedList,
				BonusSlots = profile.BonusSlots,
				UILayout = profile.UILayout,
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

-- ===== Currencies =====
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

function PlayerData.AddShards(player, amount)
	local profile = PlayerData.Profiles[player]
	if not profile then return end
	profile.Shards = math.max(0, profile.Shards + amount)
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
end

-- Extra inventory slots that are saved (rewards, tester command)
function PlayerData.AddBonusSlots(player, amount)
	local profile = PlayerData.Profiles[player]
	if not profile then return end
	profile.BonusSlots = math.max(0, profile.BonusSlots + amount)
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
end

-- Saves where the player put their screen elements (from the Screen Layout panel)
function PlayerData.SaveLayout(player, layout)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	profile.UILayout = cleanLayout(layout)
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
	return true
end

-- Records that the player beat a level (unlocks the next one)
function PlayerData.MarkCleared(player, levelId)
	local profile = PlayerData.Profiles[player]
	if not profile or profile.Cleared[levelId] then return end
	profile.Cleared[levelId] = true
	PlayerData.Sync(player)
	PlayerData.RequestSave(player)
end

function PlayerData.HasCleared(player, levelId)
	local profile = PlayerData.Profiles[player]
	return profile ~= nil and profile.Cleared[levelId] == true
end

-- ===== Getting and removing units =====
-- Gives one new unit from a summon. If you've turned on auto-delete for its rarity it is
-- deleted straight away (and takes no slot). Returns true if it was auto-deleted.
-- Summoning checks for free slots first. The caller runs PlayerData.Refresh afterwards.
function PlayerData.AddUnit(profile, unitName)
	local rarityName = UnitData.UnitRarity[unitName]
	if profile.AutoDelete[rarityName] then
		return true
	end
	newUnit(profile, unitName)
	return false
end

-- Gives units directly, ignoring auto-delete and slots (tester command)
function PlayerData.GiveUnits(player, unitName, count)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	for _ = 1, count do
		newUnit(profile, unitName)
	end
	PlayerData.Refresh(player)
	return true
end

local function removeUnit(profile, id)
	profile.Units[id] = nil
	local index = table.find(profile.Equipped, id)
	if index then
		table.remove(profile.Equipped, index)
	end
end

-- ids = a list of unit ids. Locked units are refused. Returns ok, errorMessage
function PlayerData.DeleteUnits(player, ids)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	if type(ids) ~= "table" or #ids == 0 or #ids > 1000 then return false, "Pick units to delete." end
	for _, id in ipairs(ids) do
		local u = PlayerData.FindUnit(profile, id)
		if not u then return false, "You don't have that unit." end
		if u.Locked then return false, u.Name .. " is locked. Unlock it first." end
	end
	for _, id in ipairs(ids) do
		removeUnit(profile, id)
	end
	PlayerData.Refresh(player)
	return true
end

function PlayerData.SetLocked(player, id, locked)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	local u = PlayerData.FindUnit(profile, id)
	if not u then return false, "You don't have that unit." end
	u.Locked = locked == true
	PlayerData.Refresh(player)
	return true
end

-- Manual team editing (turns auto-equip off). Equipping a unit whose name is already on
-- the team swaps it in for that copy.
function PlayerData.SetEquipped(player, id, on)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	profile.AutoEquip = false
	local u = PlayerData.FindUnit(profile, id)
	if not u then return false, "You don't have that unit." end

	local index = table.find(profile.Equipped, id)
	if on then
		if index then return true end
		local same = PlayerData.EquippedUnit(profile, u.Name)
		if same then
			profile.Equipped[table.find(profile.Equipped, same.Id)] = id
		elseif #profile.Equipped >= UnitData.TeamSize then
			return false, string.format("Your team is full (%d).", UnitData.TeamSize)
		else
			table.insert(profile.Equipped, id)
		end
	elseif index then
		table.remove(profile.Equipped, index)
	end

	PlayerData.Refresh(player)
	return true
end

-- Puts a unit into team slot `slot` (1 to UnitData.TeamSize), as picked on the team bar.
--   * the unit is already on the team: it swaps places with whatever is in that slot
--   * another copy of the same unit is on the team: this copy takes its place, then moves
--   * the slot holds a different unit: that unit comes off the team
--   * the slot is empty: the unit goes in the first free slot (slots fill left to right)
-- Choosing slots by hand turns auto-equip off. Returns ok, errorMessage
function PlayerData.EquipToSlot(player, id, slot)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	local u = PlayerData.FindUnit(profile, id)
	if not u then return false, "You don't have that unit." end
	if typeof(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > UnitData.TeamSize then
		return false, "Pick a team slot."
	end

	profile.AutoEquip = false
	local team = profile.Equipped
	local function moveTo(from)
		if slot <= #team then
			team[from], team[slot] = team[slot], team[from]
		else
			table.remove(team, from)
			table.insert(team, id)
		end
	end

	local at = table.find(team, id)
	local same = PlayerData.EquippedUnit(profile, u.Name)
	if at then
		moveTo(at)
	elseif same then
		local from = table.find(team, same.Id)
		team[from] = id
		moveTo(from)
	elseif slot <= #team then
		team[slot] = id
	elseif #team < UnitData.TeamSize then
		table.insert(team, id)
	else
		return false, string.format("Your team is full (%d).", UnitData.TeamSize)
	end

	PlayerData.Refresh(player)
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

-- ===== Traits, fusing, evolving =====
-- Summons a random trait onto a unit in the Traits Cave for TraitData.SummonCost Trait Shards.
-- It replaces the unit's current trait. Returns ok, errorMessage, newTraitName
function PlayerData.SummonTrait(player, id)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	local u = PlayerData.FindUnit(profile, id)
	if not u then return false, "You don't have that unit." end
	if profile.Shards < TraitData.SummonCost then
		return false, "You're out of Trait Shards. Win levels to earn more."
	end

	profile.Shards -= TraitData.SummonCost
	u.Trait = TraitData.Roll()
	PlayerData.Refresh(player) -- the trait can change who auto-equip picks
	return true, nil, u.Trait
end

-- Fuses other units into `targetId` for XP. feedIds = a list of unit ids.
-- Locked units and units on your team can't be fed. Returns ok, errorMessage, xpGained
function PlayerData.Fuse(player, targetId, feedIds)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	local target = PlayerData.FindUnit(profile, targetId)
	if not target then return false, "You don't have that unit." end
	if type(feedIds) ~= "table" or #feedIds == 0 or #feedIds > 1000 then return false, "Pick units to fuse." end

	local maxXP = ProgressData.MaxXP()
	if target.XP >= maxXP then return false, target.Name .. " is already max level." end

	-- check everything first, so a bad entry can't half-finish the fusion
	local seen, gained = {}, 0
	for _, id in ipairs(feedIds) do
		local u = PlayerData.FindUnit(profile, id)
		if not u or seen[id] then return false, "Bad fusion request." end
		if id == targetId then return false, "A unit can't be fused into itself." end
		if u.Locked then return false, u.Name .. " is locked." end
		if table.find(profile.Equipped, id) then return false, u.Name .. " is on your team." end
		seen[id] = true
		gained += ProgressData.FodderXP[UnitData.UnitRarity[u.Name]]
	end

	for _, id in ipairs(feedIds) do
		removeUnit(profile, id)
	end
	local before = target.XP
	target.XP = math.min(before + gained, maxXP)

	PlayerData.Refresh(player)
	return true, nil, target.XP - before
end

-- The spare copies Evolve would use for this unit: same name, not locked, not on the team,
-- no stars. Copies without a trait and with the least XP go first.
function PlayerData.EvolveFodder(profile, unit)
	local spare = {}
	for _, u in pairs(profile.Units) do
		if u.Id ~= unit.Id and u.Name == unit.Name and not u.Locked and u.Stars == 0
			and not table.find(profile.Equipped, u.Id) then
			table.insert(spare, u)
		end
	end
	table.sort(spare, function(a, b)
		if (a.Trait == nil) ~= (b.Trait == nil) then return a.Trait == nil end
		if a.XP ~= b.XP then return a.XP < b.XP end
		return a.Id < b.Id
	end)
	return spare
end

-- Uses spare copies of the same unit (and Gold) to give it one more star. Returns ok, errorMessage
function PlayerData.Evolve(player, id)
	local profile = PlayerData.Profiles[player]
	if not profile then return false, "Still loading." end
	local unit = PlayerData.FindUnit(profile, id)
	if not unit then return false, "You don't have that unit." end

	local step = ProgressData.Evolutions[unit.Stars + 1]
	if not step then return false, unit.Name .. " is fully evolved." end
	local spare = PlayerData.EvolveFodder(profile, unit)
	if #spare < step.Copies then
		return false, string.format("You need %d spare %s (you have %d). Spares can't be locked, on your team or evolved.",
			step.Copies, unit.Name, #spare)
	end
	if profile.Gold < step.Gold then
		return false, string.format("You need %d Gold to evolve.", step.Gold)
	end

	profile.Gold -= step.Gold
	for i = 1, step.Copies do
		removeUnit(profile, spare[i].Id)
	end
	unit.Stars += 1

	PlayerData.Refresh(player)
	return true
end

-- Sets a unit's trait directly (tester command). nil removes it.
function PlayerData.SetTrait(player, unit, traitName)
	if traitName ~= nil and not TraitData.Get(traitName) then return false, "Unknown trait." end
	unit.Trait = traitName
	PlayerData.Refresh(player)
	return true
end

-- ===== Slot game passes =====
-- Buying a slot pass in-game adds its slots straight away
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end
	local profile = PlayerData.Profiles[player]
	if not profile then return end
	for _, pass in ipairs(UnitData.SlotPasses) do
		if pass.Id == passId and pass.Id ~= 0 then
			checkSlotPasses(player, profile)
			PlayerData.Sync(player)
			return
		end
	end
end)

-- ===== Lifecycle =====
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
