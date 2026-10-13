-- PLACE IN: ReplicatedStorage
-- TYPE: ModuleScript
-- NAME: PlaceConfig
-- (replaces the earlier version: new script. The game is now two places: the LOBBY (the city)
--  and the MATCH place (one battle arena). The pads in the lobby send each team to its own
--  private match server, and when the match is over everyone is sent back to the lobby.)
--
-- Put the SAME scripts in both places (all of ReplicatedStorage, ServerScriptService and
-- StarterPlayerScripts). Each script checks this module to know which place it's in and
-- only does its own part: the lobby builds the city, the match place builds one arena.
--
-- Setup:
--   1. In Studio: View > Asset Manager > Places > right-click > Add New Place. That's the
--      match place. Copy every script into it too.
--   2. Find both place IDs (Creator Dashboard > your experience > Places, or game.PlaceId
--      in each place) and paste them below. Do this in BOTH places' copy of this module.
--   3. Publish both places.
-- While MatchPlaceId is 0, or while testing the lobby in Studio (teleports don't work in
-- Studio), matches run inside the lobby server like before, in the sky arenas.
-- Pressing Play in the match place in Studio plays StudioTestLevel on your own.

local RunService = game:GetService("RunService")

local PlaceConfig = {}

PlaceConfig.LobbyPlaceId = 0 -- the start place (the city)
PlaceConfig.MatchPlaceId = 0 -- the place with the battle arena

PlaceConfig.StudioTestLevel = 1 -- the level you play when you press Play in the match place

-- True on a server (or client) of the match place
function PlaceConfig.IsMatchPlace()
	return PlaceConfig.MatchPlaceId ~= 0 and game.PlaceId == PlaceConfig.MatchPlaceId
end

-- True in a live lobby server: its pads send teams to match servers.
-- False in Studio and while MatchPlaceId is 0: matches then run in this server's sky arenas.
function PlaceConfig.UsesMatchServers()
	return PlaceConfig.MatchPlaceId ~= 0 and not PlaceConfig.IsMatchPlace() and not RunService:IsStudio()
end

return PlaceConfig
