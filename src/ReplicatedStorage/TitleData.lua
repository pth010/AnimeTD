-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: TitleData
-- (replaces the earlier version: adds the seven achievement titles (Demon Slayer, Boss Hunter,
--  Nightmare Conqueror, Lucky Star, Master Fuser, Tower Climber, Sky Legend), unlocked by
--  earning their achievement (AchievementData))
-- A title shows over the player's head, above their name (TitleService), and is picked in the
-- TITLES window (TitleUI). Everyone owns "Player" and starts with it equipped. The equipped
-- title is saved (PlayerData).
--
-- ADDING A TITLE: add a line to TitleData.Titles below. Each one has:
--   Name         what it says (also its id, so don't rename one people already have)
--   Color        its text color
--   Glow         (optional) a second color: the title shimmers from Color to Glow
--   Description  how you get it, shown in the TITLES window
--   Rule         who owns it:
--                  "Everyone"  every player
--                  "Owner"     the game's owner (see PlaceConfig.IsOwner)
--                  "Admin"     admins (PlaceConfig.Admins) and the owner
--                  "Group"     members of the game's Roblox group (PlaceConfig.GroupId);
--                              add MinRank = 200 to only count ranks from 200 up
--                  "Earned"    only players it's been given to, with PlayerData.GrantTitle
--                              (or the "!title" admin command). Saved forever once given.
--   Hidden       (optional) true: the TITLES window only lists it once you own it
-- The list's order is the order in the TITLES window.

local PlaceConfig = require(script.Parent:WaitForChild("PlaceConfig"))

local TitleData = {}

local rgb = Color3.fromRGB

TitleData.Default = "Player" -- what everyone starts with equipped

TitleData.Titles = {
	{ Name = "Owner",  Color = rgb(255, 205, 60),  Glow = rgb(255, 120, 40), Rule = "Owner",
		Description = "The creator of the game." },
	{ Name = "Admin",  Color = rgb(255, 90, 90),   Glow = rgb(255, 170, 120), Rule = "Admin",
		Description = "Keeps the game running." },
	{ Name = "Member", Color = rgb(110, 190, 255), Rule = "Group",
		Description = "Join the game's Roblox group." },
	{ Name = "Player", Color = rgb(215, 215, 230), Rule = "Everyone",
		Description = "Everyone has this one." },

	-- Achievement titles: earning the achievement gives them (AchievementData)
	{ Name = "Sky Legend", Color = rgb(255, 150, 70), Glow = rgb(255, 230, 120), Rule = "Earned",
		Description = "Achievement: clear wave 100 in the Sky Tower." },
	{ Name = "Nightmare Conqueror", Color = rgb(235, 60, 80), Glow = rgb(150, 20, 60), Rule = "Earned",
		Description = "Achievement: beat every map on Nightmare." },
	{ Name = "Demon Slayer", Color = rgb(255, 80, 80), Rule = "Earned",
		Description = "Achievement: defeat 10,000 enemies." },
	{ Name = "Boss Hunter", Color = rgb(255, 170, 60), Rule = "Earned",
		Description = "Achievement: defeat 100 bosses." },
	{ Name = "Tower Climber", Color = rgb(255, 120, 60), Rule = "Earned",
		Description = "Achievement: clear wave 50 in the Sky Tower." },
	{ Name = "Master Fuser", Color = rgb(110, 200, 255), Rule = "Earned",
		Description = "Achievement: get a unit to level 100." },
	{ Name = "Lucky Star", Color = rgb(255, 225, 90), Glow = rgb(255, 160, 220), Rule = "Earned",
		Description = "Achievement: summon 1,000 units." },

	-- More titles go here, for example one to hand out by hand:
	-- { Name = "Tester", Color = rgb(150, 255, 160), Rule = "Earned", Hidden = true,
	--	Description = "Helped test the game." },
}

local byName = {}
for i, t in ipairs(TitleData.Titles) do
	t.Order = i
	byName[t.Name] = t
end

function TitleData.Get(name)
	return byName[name]
end

-- Does `player` own `title` by its rule? (Server only: the group check waits on Roblox.)
-- `earned` is the set of titles the player has been given ([name] = true).
function TitleData.Qualifies(player, title, earned)
	local rule = title.Rule
	if rule == "Everyone" then
		return true
	elseif rule == "Owner" then
		return PlaceConfig.IsOwner(player)
	elseif rule == "Admin" then
		return PlaceConfig.IsAdmin(player) or PlaceConfig.IsOwner(player)
	elseif rule == "Group" then
		local groupId = PlaceConfig.GetGroupId()
		if groupId == 0 then return false end
		local ok, rank = pcall(function()
			return player:GetRankInGroup(groupId)
		end)
		return ok and rank >= math.max(1, title.MinRank or 1)
	elseif rule == "Earned" then
		return earned ~= nil and earned[title.Name] == true
	end
	return false
end

-- "Owner,Player" (the OwnedTitles player attribute) -> { Owner = true, Player = true }
function TitleData.ParseOwned(text)
	local owned = {}
	for name in string.gmatch(text or "", "[^,]+") do
		owned[name] = true
	end
	return owned
end

return TitleData
