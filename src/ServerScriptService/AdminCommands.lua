-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: AdminCommands
-- Tester chat commands for giving yourself money. Type these in the chat box:
--   !gems 5000      add 5000 gems (summon currency, saved)
--   !setgems 5000   set your gems to exactly 5000
--   !cash 5000      add 5000 in-match cash (only matters during a match)
--   !setcash 5000   set your in-match cash to exactly 5000
--   !resetpity      set your summon pity back to 0
-- Negative numbers work too (e.g. "!gems -500").
--
-- Who can use them: everyone while testing in Studio, and in the live game only the
-- UserIds listed in ADMINS below. Find your UserId in the URL of your Roblox profile page.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local ADMINS = {
	-- [123456789] = true, -- put your UserId here to use the commands in the live game
}

local function isAdmin(player)
	return RunService:IsStudio() or ADMINS[player.UserId] == true
end

local commands = {}

function commands.gems(player, amount)
	PlayerData.AddGems(player, amount)
end

function commands.setgems(player, amount)
	local profile = PlayerData.Get(player)
	if profile then
		PlayerData.AddGems(player, amount - profile.Gems)
	end
end

function commands.cash(player, amount)
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + amount)
end

function commands.setcash(player, amount)
	player:SetAttribute("Cash", amount)
end

function commands.resetpity(player)
	local profile = PlayerData.Get(player)
	if profile then
		profile.Pity = 0
		PlayerData.Refresh(player)
	end
end

local function onChatted(player, message)
	local name, arg = string.match(message, "^!(%a+)%s*(%S*)")
	local command = name and commands[string.lower(name)]
	if not command or not isAdmin(player) then return end

	local amount = tonumber(arg)
	if name:lower() ~= "resetpity" and not amount then
		warn("[AdminCommands] usage: !" .. name .. " <number>")
		return
	end
	command(player, amount and math.floor(amount))
	print(string.format("[AdminCommands] %s ran !%s %s", player.Name, name, arg))
end

local function onPlayerAdded(player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end
