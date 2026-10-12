-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: InventoryService
-- (replaces the earlier version: adds equip, auto-equip and auto-delete)
-- Handles every button in the inventory. The server checks everything,
-- so a locked unit can never be deleted by a hacked client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local remote = Instance.new("RemoteFunction")
remote.Name = "InventoryRemote"
remote.Parent = ReplicatedStorage

-- Actions (second argument is a unit name, a rarity name, or "" when not needed):
--   "Lock",       unitName,   true/false
--   "Delete",     unitName,   1 or "All"
--   "Equip",      unitName,   true/false   (only while auto-equip is off)
--   "AutoEquip",  "",         true/false
--   "AutoDelete", rarityName, true/false
remote.OnServerInvoke = function(player, action, name, arg)
	if typeof(action) ~= "string" or typeof(name) ~= "string" then
		return { Success = false, Error = "Bad request." }
	end
	if player:GetAttribute("InMatch") then
		return { Success = false, Error = "Not during a match." }
	end

	local ok, err
	if action == "Lock" then
		ok, err = PlayerData.SetLocked(player, name, arg == true)
	elseif action == "Delete" then
		ok, err = PlayerData.DeleteUnit(player, name, arg == "All" and "All" or 1)
	elseif action == "Equip" then
		ok, err = PlayerData.SetEquipped(player, name, arg == true)
	elseif action == "AutoEquip" then
		ok, err = PlayerData.SetAutoEquip(player, arg == true)
	elseif action == "AutoDelete" then
		ok, err = PlayerData.SetAutoDelete(player, name, arg == true)
	else
		return { Success = false, Error = "Unknown action." }
	end

	return { Success = ok == true, Error = err }
end
