local UILabs = require("@game/ReplicatedStorage/DevPackages/ui-labs")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local useAtom = VideCharm.useAtom
local create = Vide.create

local SelectorUI = require("../Roots/SelectorUI")
local Mocks = require("@game/ReplicatedStorage/Faction_Framework/Core/Mocks")
local State = require("@game/ReplicatedStorage/Faction_Framework/Core/State")
local StateActions = require("@game/ReplicatedStorage/Faction_Framework/Logic/StateActions")
local Enums = require("@game/ReplicatedStorage/Faction_Framework/Core/Enums")

local controls = {}

local story = UILabs.CreateVideStory({
	vide = Vide,
	controls = controls,
}, function(props)
	local playerKey = "0"
	local factionId = "MarineCorps"
	local state = State.new()
	StateActions.CreateFaction(state, Mocks.FactionConfig(factionId))
	StateActions.SetPlayerFaction(state, playerKey, factionId)
	local selectorOpen = Charm.atom(true)

	return create "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		SelectorUI({
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
			applyClassMode = Enums.ApplyClassMode.Explicit,
		}),
	}
end)

return story
