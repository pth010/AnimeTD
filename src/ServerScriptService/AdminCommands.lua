-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: AdminCommands
-- Tester chat commands. Type these in the in-game chat box (not the Studio command bar):
--   !gems 5000              add 5000 gems (summon currency, saved)
--   !setgems 5000           set your gems to exactly 5000
--   !cash 5000              add 5000 in-match cash (only matters during a match)
--   !setcash 5000           set your in-match cash to exactly 5000
--   !gold 5000              add 5000 gold (main-game currency, saved)
--   !setgold 5000           set your gold to exactly 5000
--   !resetpity              set your summon pity back to 0
--   !unit Starfall Kitsune  give yourself one copy of a unit
--   !unit frost mage 3      give yourself 3 copies (names aren't case-sensitive,
--                           and the start of a name is enough: "!unit starfall")
--   !trait blade novice lord  put a trait on a unit you own ("!trait blade novice none" removes it)
--   !xp frost mage 5000     give a unit you own fusion XP (levels it up)
--   !stars frost mage 3     set a unit's evolution stars (0-3)
-- Negative numbers work for gems, gold and cash (e.g. "!gems -500").
-- Results and mistakes are printed in the Output window.
--
-- Who can use them: everyone while testing in Studio, and in the live game only the
-- UserIds listed in ADMINS below. Find your UserId in the URL of your Roblox profile page.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local TraitData = require(ReplicatedStorage:WaitForChild("TraitData"))
local ProgressData = require(ReplicatedStorage:WaitForChild("ProgressData"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local ADMINS = {
	[554749540] = true,
}

local MAX_UNIT_COPIES = 100 -- most copies one !unit command can give

local function isAdmin(player)
	return RunService:IsStudio() or ADMINS[player.UserId] == true
end

-- Finds a unit by name: an exact match first (any capitalisation), then a name that
-- starts with what was typed. Returns the unit name, or nil and a reason.
local function findUnit(typed)
	typed = string.lower(typed)
	if typed == "" then
		return nil, "type a unit name"
	end

	local matches = {}
	for unitName in pairs(UnitData.UnitRarity) do
		local lower = string.lower(unitName)
		if lower == typed then
			return unitName
		end
		if string.sub(lower, 1, #typed) == typed then
			table.insert(matches, unitName)
		end
	end

	if #matches == 1 then
		return matches[1]
	elseif #matches > 1 then
		table.sort(matches)
		return nil, "more than one unit matches: " .. table.concat(matches, ", ")
	end
	return nil, "no unit called '" .. typed .. "'"
end

local function readNumber(args)
	local n = tonumber(args)
	return n and math.floor(n)
end

-- Each command gets the player and everything typed after the command name.
-- It returns nil on success, or a message explaining what went wrong.
local commands = {}

function commands.gems(player, args)
	local amount = readNumber(args)
	if not amount then return "usage: !gems <number>" end
	PlayerData.AddGems(player, amount)
end

function commands.setgems(player, args)
	local amount = readNumber(args)
	if not amount then return "usage: !setgems <number>" end
	local profile = PlayerData.Get(player)
	if not profile then return "your data is still loading" end
	PlayerData.AddGems(player, amount - profile.Gems)
end

function commands.gold(player, args)
	local amount = readNumber(args)
	if not amount then return "usage: !gold <number>" end
	PlayerData.AddGold(player, amount)
end

function commands.setgold(player, args)
	local amount = readNumber(args)
	if not amount then return "usage: !setgold <number>" end
	local profile = PlayerData.Get(player)
	if not profile then return "your data is still loading" end
	PlayerData.AddGold(player, amount - profile.Gold)
end

function commands.cash(player, args)
	local amount = readNumber(args)
	if not amount then return "usage: !cash <number>" end
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + amount)
end

function commands.setcash(player, args)
	local amount = readNumber(args)
	if not amount then return "usage: !setcash <number>" end
	player:SetAttribute("Cash", amount)
end

function commands.resetpity(player)
	local profile = PlayerData.Get(player)
	if not profile then return "your data is still loading" end
	profile.Pity = 0
	PlayerData.Refresh(player)
end

function commands.unit(player, args)
	-- A number at the end is how many copies: "!unit frost mage 3"
	local namePart, countPart = string.match(args, "^(.-)%s+(%d+)$")
	local count = 1
	if namePart then
		count = math.clamp(tonumber(countPart), 1, MAX_UNIT_COPIES)
	else
		namePart = args
	end

	local unitName, problem = findUnit(namePart)
	if not unitName then return problem end
	local profile = PlayerData.Get(player)
	if not profile then return "your data is still loading" end

	-- Added directly (not through PlayerData.AddUnit) so auto-delete can't eat it
	profile.Obtained[unitName] = (profile.Obtained[unitName] or 0) + count
	profile.Units[unitName] = (profile.Units[unitName] or 0) + count
	PlayerData.Refresh(player)
	print(string.format("[AdminCommands] gave %s %d x %s", player.Name, count, unitName))
end

function commands.trait(player, args)
	-- The trait is the last word(s): try the longest trait name that fits the end
	local lowerArgs = string.lower(args)
	local unitPart, traitName
	if string.sub(lowerArgs, -5) == " none" then
		unitPart = string.sub(args, 1, -6)
	else
		for _, trait in ipairs(TraitData.Traits) do
			local tail = " " .. string.lower(trait.Name)
			if string.sub(lowerArgs, -#tail) == tail and (not traitName or #trait.Name > #traitName) then
				traitName = trait.Name
				unitPart = string.sub(args, 1, #args - #tail)
			end
		end
		if not traitName then
			return "usage: !trait <unit> <trait>   (traits: Lord, Celestial, Midas, Sharp, ...)"
		end
	end

	local unitName, problem = findUnit(unitPart)
	if not unitName then return problem end
	local ok, err = PlayerData.SetTrait(player, unitName, traitName)
	if not ok then return err end
	print(string.format("[AdminCommands] %s's %s now has trait %s", player.Name, unitName, traitName or "none"))
end

-- "frost mage 5000" -> unit name, number
local function unitAndNumber(args)
	local namePart, numberPart = string.match(args, "^(.-)%s+(%d+)$")
	if not namePart then return nil, nil, "put a number at the end" end
	local unitName, problem = findUnit(namePart)
	return unitName, tonumber(numberPart), problem
end

function commands.xp(player, args)
	local unitName, amount, problem = unitAndNumber(args)
	if not unitName then return problem or "usage: !xp <unit> <amount>" end
	local profile = PlayerData.Get(player)
	if not profile then return "your data is still loading" end
	if not profile.Units[unitName] then return "you don't own " .. unitName end
	profile.XP[unitName] = math.min((profile.XP[unitName] or 0) + amount, ProgressData.MaxXP())
	PlayerData.Refresh(player)
end

function commands.stars(player, args)
	local unitName, stars, problem = unitAndNumber(args)
	if not unitName then return problem or "usage: !stars <unit> <0-3>" end
	local profile = PlayerData.Get(player)
	if not profile then return "your data is still loading" end
	if not profile.Units[unitName] then return "you don't own " .. unitName end
	profile.Stars[unitName] = math.clamp(stars, 0, ProgressData.MaxStars)
	PlayerData.Refresh(player)
end

local function onChatted(player, message)
	local name, args = string.match(message, "^!(%a+)%s*(.-)%s*$")
	local command = name and commands[string.lower(name)]
	if not command or not isAdmin(player) then return end

	local problem = command(player, args)
	if problem then
		warn(string.format("[AdminCommands] !%s: %s", name, problem))
	else
		print(string.format("[AdminCommands] %s ran !%s %s", player.Name, name, args))
	end
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
