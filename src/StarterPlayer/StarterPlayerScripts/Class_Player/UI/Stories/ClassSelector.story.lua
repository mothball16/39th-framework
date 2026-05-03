local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local source = Vide.source

local Roots = script.Parent.Parent.Roots
local ClassSelectorUI = require(Roots.ClassSelectorUI)

return function(target: Instance)
	local localPlayer = Players.LocalPlayer
	local playerKey = if localPlayer then tostring(localPlayer.UserId) else "0"

	local factionId = "MarineCorps"
	local factionConfigs = source({
		[factionId] = {
			ID = factionId,
			Classes = {
				Rifleman = {
					ClassIDs = {"RiflemanA", "RiflemanB"},
					Limit = 10,
					Default = true,
				},
				Engineer = {
					ClassIDs = {"EngineerA"},
					Limit = 2,
					Default = false,
				},
				Marksman = {
					ClassIDs = {"MarksmanA", "MarksmanB", "MarksmanC"},
					Limit = 1,
					Default = false,
				},
			},
		},
	})

	return Vide.mount(function()
		return ClassSelectorUI({
			factionConfigs = factionConfigs,
			playerFactionIds = source({
				[playerKey] = factionId,
			}),
			playerClassKeys = source({
				[playerKey] = "Rifleman",
			}),
			playerClassIds = source({
				[playerKey] = "RiflemanA",
			}),
			classCountsByFaction = source({
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