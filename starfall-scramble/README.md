# Starfall Scramble

A Roblox game. Stars rain down on a floating island in the night sky. Run around grabbing them until your bag is full, then bank them at the glowing Star Well for Stardust. Meteors keep crashing down: a hit flings you across the island and spills half your bag for anyone to grab, and getting knocked off the edge loses everything you're carrying. Bank now and stay safe, or get greedy for one more Golden star?

## The loop

1. **Grab** falling stars: Spark (1), Azure (5), Golden (25) and the rare rainbow Prism (150).
2. **Bank** them at the Star Well in the middle. Meteors never land there.
3. **Upgrade** with Stardust: Star Bag (capacity), Moon Boots (speed), Star Magnet (grab range) and Lucky Clover (chance a star counts double).
4. **Go Supernova** when you can afford it. Your Stardust and upgrades reset, and everything you bank afterwards is worth +50% more, permanently and stacking.
5. **Climb the board**: the Brightest Star Catchers board ranks lifetime Stardust across all servers.

Timed server events take turns every few minutes. **Meteor Shower** brings far more stars, more Golden ones, and a lot more meteors. **Prism Rain** brings a flood of rainbow Prism stars.

## Setup

The map, lighting and UI are all built by the scripts, so start from an empty **Baseplate** place. The island builder deletes the Baseplate so players can fall into the void.

**With Rojo:** run `rojo serve` from this folder (it uses `default.project.json`) and connect from the Rojo plugin in Studio.

**By hand:** create each script in Studio where its header says (`PLACE IN`, `TYPE`, `NAME`) and paste in the file's contents:

| File | Where | Type |
| --- | --- | --- |
| `src/ReplicatedStorage/StarConfig.lua` | ReplicatedStorage | ModuleScript |
| `src/ServerScriptService/StarData.lua` | ServerScriptService | ModuleScript |
| `src/ServerScriptService/IslandBuilder.server.lua` | ServerScriptService | Script |
| `src/ServerScriptService/StarService.server.lua` | ServerScriptService | Script |
| `src/ServerScriptService/StarBoard.server.lua` | ServerScriptService | Script |
| `src/StarterPlayerScripts/StarHUD.client.lua` | StarterPlayer > StarterPlayerScripts | LocalScript |

Saving and the global leaderboard need a published place. To test saving in Studio, also turn on Game Settings > Security > "Enable Studio Access to API Services". Without that the game still runs, but nothing saves.

## Tuning

Every number lives in `StarConfig.lua`: star values and spawn weights, how often stars and meteors fall, the meteor blast radius and how much of your bag a hit spills, event timing, upgrade prices and effects, and the Supernova cost and multiplier.
