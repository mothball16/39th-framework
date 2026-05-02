local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local State = require(Access.Framework.Core:WaitForChild("State"))

local ClientMirror = require(script.Parent.ClientMirror)
local ClassSelectorUI = require(script.Parent.ClassSelectorUI)

local maid = Maid.new()
local state = State.new()
local mirror = ClientMirror.new({
	factionConfigs = state.factionConfigs,
	playerFactionIds = state.playerFactionIds,
	playerClassKeys = state.playerClassKeys,
	playerClassIds = state.playerClassIds,
	classCountsByFaction = state.classCountsByFaction,
}, Events)
local selectorUI = ClassSelectorUI.new(state.factionConfigs, state.playerFactionIds, state.playerClassKeys, state.playerClassIds, state.classCountsByFaction)
maid:GiveTask(selectorUI)
maid:GiveTask(mirror)

script.Destroying:Connect(function()
	maid:DoCleaning()
end)