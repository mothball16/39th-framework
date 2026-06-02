local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local useAtom = VideCharm.useAtom

local SelectorUI = require("../Roots/SelectorUI")
local Mocks = require("@game/ReplicatedStorage/Class_Framework/Core/Mocks")
local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")
local StateActions = require("@game/ReplicatedStorage/Class_Framework/Logic/StateActions")
local Enums = require("@game/ReplicatedStorage/Class_Framework/Core/Enums")

return function(target: Instance)
	local playerKey = "0"

	local factionId = "MarineCorps"
	local state = State.new()
	StateActions.CreateFaction(state, Mocks.FactionConfig(factionId))
	StateActions.SetPlayerFaction(state, playerKey, factionId)
	local selectorOpen = Charm.atom(true)

	return Vide.mount(function()
		return SelectorUI({
			isOpen = useAtom(selectorOpen),
			manualButton = true,
			playerKey = playerKey,
			state = state,
			setSelectorOpen = function(open: boolean)
				print("Story setSelectorOpen", open)
				selectorOpen(open)
			end,
			requestGroupClass = function(group, class)
				StateActions.SetPlayerGroupClass(state, playerKey, group, class)
				print("Story request (change group/class):", group, class)
			end,
			requestClassApply = function(enable)
				print("Story request (apply class):", enable)
			end,
			applyClassMode = Enums.ApplyClassMode.AfterInteraction,
		})
	end, target)
end
