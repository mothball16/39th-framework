local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local Charm = require(Packages.Charm)
local VideCharm = require(Packages["vide-charm"])
local useAtom = VideCharm.useAtom
local source = Vide.source

local Roots = script.Parent.Parent.Roots
local SelectorUI = require(Roots.SelectorUI)
local Mocks = require(ReplicatedStorage.Class_Framework.Core.Mocks)
local State = require(ReplicatedStorage.Class_Framework.Core.State)

return function(target: Instance)
	local playerKey = "0"

	local factionId = "MarineCorps"
	local configByFactionId = {
		[factionId] = Mocks.FactionConfig(factionId),
	}

	local selectorOpen = Charm.atom(true)


	return Vide.mount(function()
		return SelectorUI({
			isOpen = useAtom(selectorOpen),
			manualButton = true,
			playerKey = playerKey,
			state = {
				configByFactionId = source(configByFactionId),
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
			},
			setSelectorOpen = function(open: boolean)
				print("Story setSelectorOpen", open)
				selectorOpen(open)
			end,
			requestClass = function(classKey, classId)
				print("Story request (change class):", classKey, classId)
			end,
			requestClassApply = function(enable)
				print("Story request (apply class):", enable)
			end,
		})
	end, target)
end
