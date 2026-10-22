-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: InventoryService
-- (replaces the earlier version: nothing can change while you're teleporting to or from a
--  match, since your data has already been saved and handed over to the other server)
-- Handles every button in the inventory and the Traits Cave. The server checks everything,
-- so a locked unit can never be deleted by a hacked client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local remote = Instance.new("RemoteFunction")
remote.Name = "InventoryRemote"
remote.Parent = ReplicatedStorage

-- Unit ids are numbers (see UnitData.ParseUnits). Actions:
--   "Lock",        unitId,     true/false
--   "Delete",      { unitId, ... }
--   "Equip",       unitId,     true/false   (turns auto-equip off)
--   "EquipSlot",   unitId,     slot number  (team bar: put the unit in that slot, turns auto-equip off)
--   "AutoEquip",   true/false
--   "AutoDelete",  rarityName, true/false
--   "SummonTrait", unitId                   (Traits Cave: replaces the unit's trait, costs Trait Shards)
--   "Fuse",        targetId,   { unitId, ... }   (feeds those units in for XP)
--   "Evolve",      unitId                   (uses spare copies + Gold, see ProgressData)
--   "SaveLayout",  { [element] = { X, Y, S } }  (Screen Layout panel, see LayoutUI)
--   "SaveSettings", { [name] = true/false }   (Settings popup, see LayoutUI)
-- SaveLayout and SaveSettings also work during a match; everything else is lobby only.

-- Turns a client-sent list into a clean list of numbers (or nil)
local function idList(value)
	if type(value) ~= "table" then return nil end
	local out = {}
	for i, id in ipairs(value) do
		if typeof(id) ~= "number" or i > 1000 then return nil end
		table.insert(out, id)
	end
	return out
end

remote.OnServerInvoke = function(player, action, a, b)
	if typeof(action) ~= "string" then
		return { Success = false, Error = "Bad request." }
	end
	if player:GetAttribute("Teleporting") then
		return { Success = false, Error = "Teleporting..." }
	end
	-- screen settings can change any time, even mid-match
	if action == "SaveLayout" then
		local ok, err = PlayerData.SaveLayout(player, a)
		return { Success = ok == true, Error = err }
	elseif action == "SaveSettings" then
		local ok, err = PlayerData.SaveSettings(player, a)
		return { Success = ok == true, Error = err }
	end

	if player:GetAttribute("InMatch") then
		return { Success = false, Error = "Not during a match." }
	end

	local ok, err, trait, xp
	if action == "Lock" then
		ok, err = PlayerData.SetLocked(player, a, b == true)
	elseif action == "Delete" then
		local ids = idList(a)
		if not ids then return { Success = false, Error = "Bad request." } end
		ok, err = PlayerData.DeleteUnits(player, ids)
	elseif action == "Equip" then
		ok, err = PlayerData.SetEquipped(player, a, b == true)
	elseif action == "EquipSlot" then
		ok, err = PlayerData.EquipToSlot(player, a, b)
	elseif action == "AutoEquip" then
		ok, err = PlayerData.SetAutoEquip(player, a == true)
	elseif action == "AutoDelete" then
		if typeof(a) ~= "string" then return { Success = false, Error = "Bad request." } end
		ok, err = PlayerData.SetAutoDelete(player, a, b == true)
	elseif action == "SummonTrait" then
		ok, err, trait = PlayerData.SummonTrait(player, a)
	elseif action == "Fuse" then
		local ids = idList(b)
		if not ids then return { Success = false, Error = "Bad request." } end
		ok, err, xp = PlayerData.Fuse(player, a, ids)
	elseif action == "Evolve" then
		ok, err = PlayerData.Evolve(player, a)
	else
		return { Success = false, Error = "Unknown action." }
	end

	return { Success = ok == true, Error = err, Trait = trait, XP = xp }
end
