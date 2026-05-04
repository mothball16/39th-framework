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
					ClassIDs = {
						{
							Id = "RiflemanA",
							Name = "Rifleman",
							Description = "Rifleman",
						},
						{
							Id = "RiflemanB",
							Name = "Rifleman Alt",
							Description = "Rifleman dos",
						}
					},
					Limit = 10,
					Default = true,
				},
				Engineer = {
					ClassIDs = {
						{
							Id = "EngineerA",
							Name = "Engineer",
							Description = "The only",
						}
					},
					Limit = 2,
					Default = false,
				},
				Marksman = {
					ClassIDs = {
						{
							Id = "MarksmanA",
							Name = "Marksman",
							Description = "The best",
						},
						{
							Id = "MarksmanB",
							Name = "Marksman Alt",
							Description = "The best dos",
						},
					},
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