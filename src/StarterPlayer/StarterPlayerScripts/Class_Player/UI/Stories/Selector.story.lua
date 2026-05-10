local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local source = Vide.source

local Roots = script.Parent.Parent.Roots
local SelectorUI = require(Roots.SelectorUI)
local Mocks = require(ReplicatedStorage.Class_Framework.Core.Mocks)
return function(target: Instance)
	local localPlayer = Players.LocalPlayer
	local playerKey = if localPlayer then tostring(localPlayer.UserId) else "0"

	local factionId = "MarineCorps"
	local factionConfigs = source(Mocks.FactionConfig(factionId))

	return Vide.mount(function()
		return SelectorUI({
			startOpen = true,
			factionConfigs = factionConfigs,
			playerByFactionId = source({
				[playerKey] = factionId,
			}),
			playerByClassKey = source({
				[playerKey] = "Rifleman",
			}),
			playerByClassId = source({
				[playerKey] = "RiflemanA",
			}),
			classCountByFaction = source({
				[factionId] = {
					Rifleman = 4,
					Engineer = 1,
					Marksman = 1,
				},
			}),
			requestClass = function(classKey, classId)
				print("Story request:", classKey, classId)
			end,
		})
	end, target)
end
