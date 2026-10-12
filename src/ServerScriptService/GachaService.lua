-- PLACE IN: ServerScriptService
-- TYPE: Script
-- NAME: GachaService
-- (replaces the earlier version: adds the limited event banner with a rate-up featured unit)

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

	-- The event's featured unit is never in the normal pool: it only comes from the rate-up
	local event = UnitData.Event
	local featured = event and event.Featured
	local pool = {}
	for _, name in ipairs(UnitData.Units[rarity.Name]) do
		if name ~= featured then
			table.insert(pool, name)
		end
	end

	local unitName
	local isFeatured = false
	if UnitData.IsEventActive() and UnitData.UnitRarity[featured] == rarity.Name
		and (#pool == 0 or rng:NextNumber() < event.RateUp) then
		unitName = featured
		isFeatured = true
	else
		unitName = pool[rng:NextInteger(1, #pool)]
	end
	local autoDeleted = PlayerData.AddUnit(profile, unitName)

	return { Name = unitName, Rarity = rarity.Name, AutoDeleted = autoDeleted, Featured = isFeatured }
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
	local ok, err = pcall(function()
		for _ = 1, count do
			table.insert(results, rollOnce(profile))
		end
	end)
	profile.Busy = false -- always cleared, so an error can't lock summoning until rejoin
	if not ok then
		warn("[GachaService] summon failed:", err)
		profile.Gems += cost * (count - #results) / count -- refund the pulls that didn't happen
		PlayerData.Refresh(player)
		return { Success = false, Error = "Summon failed, gems refunded." }
	end

	PlayerData.Refresh(player)

	return { Success = true, Gems = profile.Gems, Pity = profile.Pity, Results = results }
end
