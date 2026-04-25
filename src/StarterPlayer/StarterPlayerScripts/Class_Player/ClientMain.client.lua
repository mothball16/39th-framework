local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local Charm = require(Access.Packages.Charm)
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local State = require(Access.Framework.Core:WaitForChild("State"))

local ClientMirror = require(script.Parent.ClientMirror)
local ClientMirrorUI = require(script.Parent.ClientMirrorUI)
local ClientUIConfig = require(script.Parent.ClientUIConfig)

local maid = Maid.new()
local state = State.new()
local mirror = ClientMirror.new({
	FactionConfigs = state.FactionConfigs,
	MembershipByUserId = state.MembershipByUserId,
	ClassCountsByFaction = state.ClassCountsByFaction,
}, Events)
local mirrorUI = ClientMirrorUI.new(mirror.atoms, Events)

Charm.observe(state.Players, function(value, key)
	warn(value, key)
end)


maid:GiveTask(mirror)
maid:GiveTask(mirrorUI)
maid:GiveTask(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if input.KeyCode == ClientUIConfig.ToggleKeyCode then
		mirrorUI:Toggle()
		return
	end

	if not mirrorUI:IsVisible() then
		return
	end

	if input.KeyCode == Enum.KeyCode.Up then
		mirrorUI:MoveSelection(-1)
		return
	end
	if input.KeyCode == Enum.KeyCode.Down then
		mirrorUI:MoveSelection(1)
		return
	end
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
		mirrorUI:RequestSelectedClass()
	end
end))

script.Destroying:Connect(function()
	maid:DoCleaning()
end)