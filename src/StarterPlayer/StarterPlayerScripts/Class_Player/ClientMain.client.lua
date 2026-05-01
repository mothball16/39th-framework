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
	FactionConfigs = state.FactionConfigs,
	PlayerAssignments = state.PlayerAssignments,
}, Events)
local selectorUI = ClassSelectorUI.new(state.FactionConfigs, state.PlayerAssignments)
maid:GiveTask(selectorUI)
maid:GiveTask(mirror)

script.Destroying:Connect(function()
	maid:DoCleaning()
end)