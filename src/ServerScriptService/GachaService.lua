-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: GachaService
-- (replaces the earlier version: now uses the shared PlayerData module)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local UnitData = require(ReplicatedStorage:WaitForChild("UnitData"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local SINGLE_COST = 100
local TEN_COST = 900
local PITY_THRESHOLD = 50 -- guaranteed Legendary+ on the 50th summon without one

local summonRemote = Instance.new("RemoteFunction")
summonRemote.Name = "SummonRemote"
summonRemote.Parent = ReplicatedStorage

local rng = Random.new()

local function rollRarity(forceHigh)
	local total = 0
	for _, r in ipairs(UnitData.Rarities) do
		if not forceHigh or r.High then
			total += r.Weight
		end
	end

	local roll = rng:NextNumber() * total
	local last
	for _, r in ipairs(UnitData.Rarities) do
		if not forceHigh or r.High then
			last = r
			roll -= r.Weight
			if roll <= 0 then
				return r
			end
		end
	end
	return last
end

local function rollOnce(profile)
	profile.Pity += 1
	local rarity = rollRarity(profile.Pity >= PITY_THRESHOLD)
	if rarity.High then
		profile.Pity = 0
	end

	local pool = UnitData.Units[rarity.Name]
	local unitName = pool[rng:NextInteger(1, #pool)]
	local autoDeleted = PlayerData.AddUnit(profile, unitName)

	return { Name = unitName, Rarity = rarity.Name, AutoDeleted = autoDeleted }
end

summonRemote.OnServerInvoke = function(player, count)
	local profile = PlayerData.Get(player)
	if not profile or profile.Busy then
		return { Success = false, Error = "Please wait." }
	end
	if count ~= 1 and count ~= 10 then
		return { Success = false, Error = "Invalid summon." }
	end

	local cost = (count == 10) and TEN_COST or SINGLE_COST
	if profile.Gems < cost then
		return { Success = false, Error = "Not enough gems." }
	end

	profile.Busy = true
	profile.Gems -= cost

	local results = {}
	for _ = 1, count do
		table.insert(results, rollOnce(profile))
	end

	profile.Busy = false
	PlayerData.Refresh(player)

	return { Success = true, Gems = profile.Gems, Pity = profile.Pity, Results = results }
end
