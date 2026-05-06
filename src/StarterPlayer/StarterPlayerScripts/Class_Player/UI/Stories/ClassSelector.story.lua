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
			Name = "United States Marine Corps",
			Classes = {
				Rifleman = {
					ClassIDs = {
						{
							Id = "RiflemanA",
							Name = "Rifleman",
							Description = "Rifleman uno\n\n\n",
						},
						{
							Id = "RiflemanB",
							Name = "Rifleman Alt",
							Description = "Rifleman dos\n\n\n",
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
							Description = "The only\n\n\n",
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
							Description = "The best\n\n\n",
						},
						{
							Id = "MarksmanB",
							Name = "Marksman Alt",
							Description = "The best dos\n\n\n",
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
			startOpen = true,
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